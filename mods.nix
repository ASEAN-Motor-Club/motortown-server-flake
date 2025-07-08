{ pkgs }: let
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
      url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.6/MotorTownMods_v0.6.2.zip";
      hash = "sha256-DMjQbTuoUkNpSXiPvecRTwRP2DuB3FLabM8u2VefOEs=";
    };
    shared = pkgs.fetchzip {
      url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.6/shared.zip";
      hash = "sha256-AbTfQp5uIi19s6Mn342XIhwOGZmJjbigyMDcDVyMcWQ=";
    };
  };

  installModsScriptBin = pkgs.writeScriptBin "install-mt-mods" ''
    set -xeu
    cp --no-preserve=mode,ownership -r ${ue4ss}/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/version.dll "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS-settings.ini "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    cp --no-preserve=mode,ownership -r ${motorTownMods.mod} "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods"
    cp --no-preserve=mode,ownership -r ${motorTownMods.shared}/* "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/shared"
  '';
in {
  inherit installModsScriptBin;
}
