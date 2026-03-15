{ pkgs, lib, modVersion ? "v0.31.0-rc4", enableExternalMods ? {}, engineIni ? "" }:
let
  # Prefetch with:
  # nix hash to-sri --type sha256 $(nix-prefetch-url --unpack <URL>)

  ue4ssAddons = ./ue4ss;



  motorTownModsVersions = {
    "dev" = {
      ue4ss = ./UE4SS_v5;
      mod = null;
      shared = null;
      useBindMount = true;
    };
    "v0.20.0" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.0/MotorTownMods_v0.20.0.zip";
        hash = "sha256-/SVDl3HCOxl4bT92I7kdQBAaXavwz/Hp9/bvYvMhm1E=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    # Working, do not change
    "v0.20.1" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.1/MotorTownMods_v0.20.1.zip";
        # hash = "sha256-0UxNMQlzYeF8VvkLmANppwIBfSOnNi9JTSLsumErE4c=";
        hash = "sha256-IrNKxQrFHICzrNcYKNjQQ7mvLXKF41CzwDWfUswhS0o=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.2" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.2/MotorTownMods_v0.20.2.zip";
        hash = "sha256-AMRYrod/wuwP9lYc3hY0bVfm/I3pG8wncspVaxQ/nYQ=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.4" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.4/MotorTownMods_v0.20.4.zip";
        hash = "sha256-AmeNTTaGqtTrqGSIp4Okf8LOLiksVOim+zolOsg9jsk=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.5" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.5/MotorTownMods_v0.20.5.zip";
        hash = "sha256-Xee84ZDu7P6xpqVzdeWKOX/0I4qcafe1b+AgdeZS/HU=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.6" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.6/MotorTownMods_v0.20.6.zip";
        hash = "sha256-5zdMAoyAviSnLLnR7cLKoUyXUkwBNuMTsy5W5Gby52Q=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.7" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.7/MotorTownMods_v0.20.7.zip";
        hash = "sha256-DBLJauIEpDHdYHKviySQ3dVIxD7kD+w03o/qrUBJ/hg=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.8" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.8/MotorTownMods_v0.20.8.zip";
        hash = "sha256-YCYStJ/T5QYo23dpq5pDl4VA+9hUqkDFbeXGtscGBTU=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.20.9" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.20.9/MotorTownMods_v0.20.9.zip";
        hash = "sha256-cTx08+XnPTYg+6Ol0gCwo53SY/mKvY/2gGqp781KBJ4=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.30.0" = let
      release = pkgs.fetchzip {
        url = "https://github.com/ASEAN-Motor-Club/MTDediMod/releases/download/v0.30.0/MotorTownMods_v0.30.0.zip";
        hash = "sha256-YEQMtij/WoSEAVVVYgdA4kP5zkzhkHc2gTc3hKbyHCQ=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.31.0-rc1" = let
      release = pkgs.fetchzip {
        url = "https://www.aseanmotorclub.com/releases/MotorTownMods_v0.31.0-rc1.zip";
        hash = "sha256-Hue4cnpxf9YfbIBWPqYqyypsDcPgt9cXKUfKuOmEzIQ=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
    "v0.31.0-rc4" = let
      release = pkgs.fetchzip {
        url = "https://www.aseanmotorclub.com/releases/MotorTownMods_v0.31.0-rc4.zip";
        hash = "sha256-M6ygTbvKnOR9BXLnJAlzmabRB8Z/GQZ7QRKPz8IXbF4=";
        stripRoot = false;
      };
    in {
      ue4ss = release;
      mod = "${release}/ue4ss/Mods/MotorTownMods";
      shared = "${release}/ue4ss/Mods/shared";
    };
  };

  motorTownMods = { useBindMount = false; } // motorTownModsVersions.${modVersion};

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

    ${if motorTownMods.useBindMount then ''
      cp --no-preserve=mode,ownership "${motorTownMods.ue4ss}/version.dll" "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
      cp -r /var/lib/mtdedimod-dev/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    '' else ''
      rm -rf "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
      cp --no-preserve=mode,ownership -r ${motorTownMods.ue4ss}/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64"
      cp --no-preserve=mode,ownership -r ${motorTownMods.ue4ss}/version.dll "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
    ''}

    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"

    # Paks
    find $STATE_DIRECTORY/MotorTown/Content/Paks/ -maxdepth 1 -type f -name "*.pak" -not -name "MotorTown-WindowsServer.pak" -delete
    ${lib.strings.concatStringsSep "\n" externalModsScripts}
    mkdir -p "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer"
    cp --no-preserve=mode,ownership -r ${engineIniFile} "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
  '';
in {
  inherit installModsScriptBin motorTownMods;
}
