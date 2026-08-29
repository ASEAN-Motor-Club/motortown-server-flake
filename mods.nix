{
  pkgs,
  lib,
  modVersion ? "v0.31.0",
  enableExternalMods ? {},
  engineIni ? "",
  maxFps ? 120,
  keepUe4ssLogBackups ? 7,
}: let
  ue4ssAddons = ./ue4ss;

  # Local path on the host (bind-mounted read-only into containers)
  modLocalPath = "/var/lib/mod-releases/MotorTownMods_${modVersion}.zip";

  modBaseUrl = "https://www.aseanmotorclub.com/releases";
  modPakUrl = "${modBaseUrl}/mods";

  externalModsScripts =
    lib.attrsets.mapAttrsToList
    (name: enable:
      if enable
      then ''
        MOD_PAK_CACHE="$STATE_DIRECTORY/.mod-cache/paks/${name}.pak"
        mkdir -p "$STATE_DIRECTORY/.mod-cache/paks"
        if [ ! -f "$MOD_PAK_CACHE" ]; then
          echo "Downloading external mod: ${name}"
          ${pkgs.curl}/bin/curl -fSL -o "$MOD_PAK_CACHE" "${modPakUrl}/${name}.pak"
        fi
        rm -f "$STATE_DIRECTORY/MotorTown/Content/Paks/${name}.pak"
        cp --no-preserve=mode,ownership "$MOD_PAK_CACHE" "$STATE_DIRECTORY/MotorTown/Content/Paks/${name}.pak"
      ''
      else "")
    enableExternalMods;

  engineIniFile = pkgs.writeText "engine.ini" ''
    [/Script/OnlineSubsystemUtils.IpNetDriver]
    ConnectionTimeout=6000.0
    InitialConnectTimeout=6000.0

    [SystemSettings]
    t.MaxFPS=${toString maxFps}

    [ConsoleVariables]
    ${engineIni}'';

  installModsScriptBin = pkgs.writeScriptBin "install-mt-mods" ''
    set -xeu

    WIN64_DIR="$STATE_DIRECTORY/MotorTown/Binaries/Win64"
    LOG_FILE="$WIN64_DIR/ue4ss/UE4SS.log"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_LOG="$WIN64_DIR/UE4SS.$TIMESTAMP.log"

    # Prune old UE4SS.log backups BEFORE taking the new one. This runs on every
    # start and used to grow unbounded — the pile reached 64G and filled the
    # root disk, at which point the backup cp below fails (No space left) and
    # the whole preStart aborts, stranding the unit in a failed state past its
    # start-rate limit. Keeping the N newest (including the one taken just
    # after this) bounds the pile; pruning first lets a full disk self-heal.
    ue4ss_keep=${toString keepUe4ssLogBackups}
    ls -t "$WIN64_DIR"/UE4SS.*.log 2>/dev/null | tail -n +$((ue4ss_keep + 1)) | while read -r f; do
      rm -f "$f"
    done

    if [ -f "$LOG_FILE" ]; then
        cp --no-preserve=mode,ownership "$LOG_FILE" "$BACKUP_LOG"
    fi

    ${
      if modVersion == "dev"
      then ''
        # Dev mode: use bind mount
        rm -f "$WIN64_DIR/version.dll"
        cp --no-preserve=mode,ownership "${./UE4SS_v5}/version.dll" "$WIN64_DIR/"
        rm -rf "$WIN64_DIR/ue4ss"
        cp -r /var/lib/mtdedimod-dev/ue4ss "$WIN64_DIR/ue4ss"
      ''
      else ''
        # Install mod from local releases directory
        MOD_VERSION="${modVersion}"
        MOD_FILE="${modLocalPath}"
        EXTRACT_DIR="$STATE_DIRECTORY/.mod-cache/extracted-$MOD_VERSION"

        if [ ! -f "$MOD_FILE" ]; then
          MOD_DOWNLOAD_URL="${modBaseUrl}/MotorTownMods_${modVersion}.zip"
          echo "Mod file not in local cache, downloading from $MOD_DOWNLOAD_URL ..."
          if ! ${pkgs.curl}/bin/curl -fSL -o "$MOD_FILE" "$MOD_DOWNLOAD_URL"; then
            echo ""
            echo "ERROR: Mod zip not found on release server."
            echo "  Version: ${modVersion}"
            echo "  URL:     $MOD_DOWNLOAD_URL"
            echo ""
            echo "To fix:"
            echo "  1. Upload the zip:"
            echo "     scp MotorTownMods-package.zip root@amc-peripheral:/var/lib/mod-releases/MotorTownMods_${modVersion}.zip"
            echo "  2. Restart: systemctl restart motortown-server"
            echo ""
            echo "Or update modVersion in flake.nix and redeploy."
            exit 1
          fi
        fi

        # Extract if not already extracted (or version changed)
        if [ ! -d "$EXTRACT_DIR" ]; then
          rm -rf "$STATE_DIRECTORY/.mod-cache"/extracted-*  # Clean old extractions
          mkdir -p "$EXTRACT_DIR"
          ${pkgs.unzip}/bin/unzip -o "$MOD_FILE" -d "$EXTRACT_DIR"
        fi

        # Validate extraction produced the expected files
        if [ ! -d "$EXTRACT_DIR/ue4ss" ]; then
          echo "ERROR: Extracted mod zip does not contain ue4ss/ directory."
          echo "  Zip:     $MOD_FILE"
          echo "  Extract: $EXTRACT_DIR"
          echo "The zip may be corrupted. Re-upload and restart."
          exit 1
        fi
        if [ ! -f "$EXTRACT_DIR/version.dll" ]; then
          echo "ERROR: Extracted mod zip does not contain version.dll."
          echo "  Zip:     $MOD_FILE"
          echo "  Extract: $EXTRACT_DIR"
          echo "The zip may be corrupted. Re-upload and restart."
          exit 1
        fi

        # Only install UE4SS files if version changed or ue4ss/ missing
        UE4SS_DIR="$WIN64_DIR/ue4ss"
        VERSION_MARKER="$UE4SS_DIR/.installed-mod-version"
        if [ ! -f "$VERSION_MARKER" ] || [ "$(cat "$VERSION_MARKER")" != "${modVersion}" ]; then
          # Remove old files before copying. This prevents "Permission denied" when
          # stale files are owned by root:root (from hot-reload scp or manual install).
          # cp --no-preserve only sets metadata on the NEW file; it cannot bypass the
          # write-permission check on the EXISTING file being overwritten.
          rm -rf "$UE4SS_DIR"
          rm -f "$WIN64_DIR/version.dll"

          cp --no-preserve=mode,ownership -r "$EXTRACT_DIR/ue4ss" "$WIN64_DIR"
          cp --no-preserve=mode,ownership "$EXTRACT_DIR/version.dll" "$WIN64_DIR/"
          cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$UE4SS_DIR"
          echo "${modVersion}" > "$VERSION_MARKER"
        else
          echo "UE4SS mod ${modVersion} already installed, skipping"
        fi
      ''
    }

    # Paks — tolerate errors from root-owned files left by manual installs
    find "$STATE_DIRECTORY/MotorTown/Content/Paks/" -maxdepth 1 \
      -type f -name "*.pak" -not -name "MotorTown-WindowsServer.pak" \
      -delete 2>/dev/null || true
    ${lib.strings.concatStringsSep "\n" externalModsScripts}
    mkdir -p "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer"
    rm -f "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
    cp --no-preserve=mode,ownership ${engineIniFile} \
      "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
  '';
in {
  inherit installModsScriptBin;
}
