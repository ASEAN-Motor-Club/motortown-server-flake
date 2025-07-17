{ pkgs, lib, enableExternalMods }:
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

  motorTownMods = {
    mod = pkgs.fetchzip {
      url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.7/MotorTownMods_v0.7.2.zip";
      hash = "sha256-Imk5M4y934aUTheLXOhMPJT3toMa/DMEHS5CgEhz4Eo=";
    };
    shared = pkgs.fetchzip {
      url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.7/shared.zip";
      hash = "sha256-uxx535IN6526iz5EEYHMeoBLurE2nVx5H94s18/xPB4=";
    };
  };

  externalModsScripts = lib.attrsets.mapAttrsToList
    (name: enable: "cp --no-preserve=mode,ownership -r ${./mods}/${name}.pak $STATE_DIRECTORY/MotorTown/Content/Paks/${name}.pak")
    enableExternalMods;

  installModsScriptBin = pkgs.writeScriptBin "install-mt-mods" ''
    set -xeu
    cp --no-preserve=mode,ownership -r ${ue4ss}/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/version.dll "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS-settings.ini "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    cp --no-preserve=mode,ownership -r ${motorTownMods.mod} "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods"
    cp --no-preserve=mode,ownership -r ${motorTownMods.shared}/* "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/shared"

    # Paks
    ${lib.strings.concatStringsSep "\n" externalModsScripts}
    mkdir -p "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer"
    cp --no-preserve=mode,ownership -r ${./mods/Engine.ini} "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
  '';
in {
  inherit installModsScriptBin;
}
