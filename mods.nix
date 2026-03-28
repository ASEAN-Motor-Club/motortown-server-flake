{ pkgs, lib, modVersion ? "v0.31.0", enableExternalMods ? {}, engineIni ? "", maxFps ? 120 }:
let
  ue4ssAddons = ./ue4ss;

  # Local path on the host (bind-mounted read-only into containers)
  modLocalPath = "/var/lib/mod-releases/MotorTownMods_${modVersion}.zip";

  modBaseUrl = "https://www.aseanmotorclub.com/releases/mods";

  externalModsScripts = lib.attrsets.mapAttrsToList
    (name: enable: if enable
      then ''
        MOD_PAK_CACHE="$STATE_DIRECTORY/.mod-cache/paks/${name}.pak"
        mkdir -p "$STATE_DIRECTORY/.mod-cache/paks"
        if [ ! -f "$MOD_PAK_CACHE" ]; then
          echo "Downloading external mod: ${name}"
          ${pkgs.curl}/bin/curl -fSL -o "$MOD_PAK_CACHE" "${modBaseUrl}/${name}.pak"
        fi
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
    LOG_FILE="$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/UE4SS.log"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_LOG="$STATE_DIRECTORY/MotorTown/Binaries/Win64/UE4SS.$TIMESTAMP.log"

    if [ -f "$LOG_FILE" ]; then
        cp --no-preserve=mode,ownership "$LOG_FILE" "$BACKUP_LOG"
    fi

    ${if modVersion == "dev" then ''
      # Dev mode: use bind mount
      cp --no-preserve=mode,ownership "${./UE4SS_v5}/version.dll" "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
      cp -r /var/lib/mtdedimod-dev/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    '' else ''
      # Install mod from local releases directory
      MOD_VERSION="${modVersion}"
      MOD_FILE="${modLocalPath}"
      EXTRACT_DIR="$STATE_DIRECTORY/.mod-cache/extracted-$MOD_VERSION"

      if [ ! -f "$MOD_FILE" ]; then
        echo "ERROR: Mod file not found: $MOD_FILE"
        exit 1
      fi

      # Extract if not already extracted (or version changed)
      if [ ! -d "$EXTRACT_DIR" ]; then
        rm -rf "$STATE_DIRECTORY/.mod-cache"/extracted-*  # Clean old extractions
        mkdir -p "$EXTRACT_DIR"
        ${pkgs.unzip}/bin/unzip -o "$MOD_FILE" -d "$EXTRACT_DIR"
      fi

      # Install
      rm -rf "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
      cp --no-preserve=mode,ownership -r "$EXTRACT_DIR/ue4ss" "$STATE_DIRECTORY/MotorTown/Binaries/Win64"
      cp --no-preserve=mode,ownership -r "$EXTRACT_DIR/version.dll" "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
    ''}

    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"

    # Paks
    find $STATE_DIRECTORY/MotorTown/Content/Paks/ -maxdepth 1 -type f -name "*.pak" -not -name "MotorTown-WindowsServer.pak" -delete
    ${lib.strings.concatStringsSep "\n" externalModsScripts}
    mkdir -p "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer"
    cp --no-preserve=mode,ownership -r ${engineIniFile} "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
  '';
in {
  inherit installModsScriptBin;
}
