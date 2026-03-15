{ pkgs, lib, modVersion ? "v0.31.0-rc8", enableExternalMods ? {}, engineIni ? "" }:
let
  ue4ssAddons = ./ue4ss;

  # URL resolution: v0.2* releases are on GitHub, everything else on aseanmotorclub.com
  modUrl =
    if lib.hasPrefix "v0.2" modVersion
    then "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/${modVersion}/MotorTownMods_${modVersion}.zip"
    else "https://www.aseanmotorclub.com/releases/MotorTownMods_${modVersion}.zip";

  externalModsScripts = lib.attrsets.mapAttrsToList
    (name: enable: if enable
      then "cp --no-preserve=mode,ownership -r ${./mods}/${name}.pak $STATE_DIRECTORY/MotorTown/Content/Paks/${name}.pak"
      else "")
    enableExternalMods;

  engineIniFile = pkgs.writeText "engine.ini" ''
[/Script/OnlineSubsystemUtils.IpNetDriver]
ConnectionTimeout=6000.0
InitialConnectTimeout=6000.0

[SystemSettings]
t.MaxFPS=120

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
      # Runtime download mode
      MOD_VERSION="${modVersion}"
      MOD_URL="${modUrl}"
      CACHE_DIR="$STATE_DIRECTORY/.mod-cache"
      CACHE_FILE="$CACHE_DIR/MotorTownMods_$MOD_VERSION.zip"
      EXTRACT_DIR="$CACHE_DIR/extracted-$MOD_VERSION"

      mkdir -p "$CACHE_DIR"

      # Download if not cached
      if [ ! -f "$CACHE_FILE" ]; then
        echo "Downloading mod $MOD_VERSION from $MOD_URL..."
        ${pkgs.curl}/bin/curl -fSL -o "$CACHE_FILE.tmp" "$MOD_URL"
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
      else
        echo "Using cached mod: $CACHE_FILE"
      fi

      # Extract if not already extracted (or version changed)
      if [ ! -d "$EXTRACT_DIR" ]; then
        rm -rf "$CACHE_DIR"/extracted-*  # Clean old extractions
        mkdir -p "$EXTRACT_DIR"
        ${pkgs.unzip}/bin/unzip -o "$CACHE_FILE" -d "$EXTRACT_DIR"
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
