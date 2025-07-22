{ pkgs, lib, modVersion ? "v0.7.5", enableExternalMods, engineIni ? "" }:
let
  # Prefetch with:
  # nix hash to-sri --type sha256 $(nix-prefetch-url --unpack <URL>)

  ue4ssAddons = ./ue4ss;

  # UE4SS Mod
  ue4ss = pkgs.fetchzip {
    url = "https://github.com/drpsyko101/RE-UE4SS/releases/download/experimental/zDEV-UE4SS_v3.0.1-431-gb9c82d4.zip";
    hash = "sha256-X3lkcAgiuHbeKEMeKbXnHw/ZfDnYgntH0oO3HRJPkJE=";
    stripRoot = false;
  };

  motorTownModsVersions = {
    "v0.7.5" = {
      mod = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.7/MotorTownMods_v0.7.5.zip";
        hash = "sha256-cqPD5IKI/SrDOZll+zG8Kh84FdK0M7Cc9IMeaItdfws=";
      };
      shared = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.7/shared.zip";
        hash = "sha256-uxx535IN6526iz5EEYHMeoBLurE2nVx5H94s18/xPB4=";
      };
    };
    "v0.8.0" = {
      mod = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.8/MotorTownMods_v0.8.0.zip";
        hash = "sha256-/mqDnrqlttluWbjAToxbyDohQB31JGErzvF/LVu1PoE=";
      };
      shared = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.8/shared.zip";
        hash = "sha256-vHMj89ohLveSnVjo02dwRoVPKHcwhJxjhzfU041mkc0=";
      };
    };
    "v0.8.3" = {
      mod = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.8/MotorTownMods_v0.8.3.zip";
        hash = "sha256-b0PagHs6jIgmi/Ba7MD9s9J9g2y1Qgx9xwxkNbxquVE=";
      };
      shared = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.8/shared.zip";
        hash = "sha256-vHMj89ohLveSnVjo02dwRoVPKHcwhJxjhzfU041mkc0=";
      };
    };
  };
  motorTownMods = motorTownModsVersions.${modVersion};

  externalModsScripts = lib.attrsets.mapAttrsToList
    (name: enable: if enable
      then "cp --no-preserve=mode,ownership -r ${./mods}/${name}.pak $STATE_DIRECTORY/MotorTown/Content/Paks/${name}.pak"
      else "")
    enableExternalMods;

  engineIniFile = pkgs.writeText "engine.ini" ''
[ConsoleVariables]
${engineIni}'';

  installModsScriptBin = pkgs.writeScriptBin "install-mt-mods" ''
    set -xeu
    cp --no-preserve=mode,ownership -r ${ue4ss}/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/version.dll "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS-settings.ini "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    rm -rf "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods"
    cp --no-preserve=mode,ownership -r ${motorTownMods.mod} "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods"
    cp --no-preserve=mode,ownership -r ${motorTownMods.shared}/* "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/shared"

    # Paks
    find $STATE_DIRECTORY/MotorTown/Content/Paks/ -maxdepth 1 -type f -name "*.pak" -not -name "MotorTown-WindowsServer.pak" -delete
    ${lib.strings.concatStringsSep "\n" externalModsScripts}
    mkdir -p "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer"
    cp --no-preserve=mode,ownership -r ${engineIniFile} "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
  '';
in {
  inherit installModsScriptBin;
}
