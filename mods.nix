{ pkgs, lib, modVersion ? "v0.8.9-amc", enableExternalMods ? {}, engineIni ? "" }:
let
  # Prefetch with:
  # nix hash to-sri --type sha256 $(nix-prefetch-url --unpack <URL>)

  ue4ssAddons = ./ue4ss;

  # Map mod versions to their UE4SS version
  ue4ssVersionMap = {
    "v10" = "v4"; "v11" = "v4"; "v12" = "v4"; "v13" = "v4";
    "v14" = "v4"; "v15" = "v4"; "v16" = "v4"; "v17" = "v4"; "v18" = "v4";
    "v19" = "v5";
  };

  mkModFromBranch = version: {
    ue4ss = ./${if ue4ssVersionMap.${version} == "v4" then "UE4SS_v4" else "UE4SS_v5"};
    mod = pkgs.applyPatches {
      src = builtins.fetchGit {
        url = "git+ssh://git@github.com/ASEAN-Motor-Club/MTDediMod.git";
        ref = "refs/heads/release/${version}";
      };
      patches = [];
      prePatch = ''
        find ./Scripts -type f -exec sed -i 's/\r$//' {} +;
      '';
      postPatch = ''
        find ./Scripts -type f -exec sed -i 's/$/\r/' {} +;
      '';
    };
    shared = ./shared;
  };

  motorTownModsVersions = {
    "v0.8.9-amc" = {
      ue4ss = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/RE-UE4SS/releases/download/experimental/zDEV-UE4SS_v3.0.1-431-gb9c82d4.zip";
        hash = "sha256-X3lkcAgiuHbeKEMeKbXnHw/ZfDnYgntH0oO3HRJPkJE=";
        stripRoot = false;
      };
      mod = pkgs.applyPatches {
        src = pkgs.fetchzip {
          url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.8/MotorTownMods_v0.8.9.zip";
          hash = "sha256-K9kzWGa5GUDVxJeHPUeN/hGfYBs8C+21rzzEqvIDj6c=";
        };
        patches = [
          ./patches/event_owner.patch
          ./patches/sign_contract_webhook.patch
          ./patches/batch_webhook.patch
          ./patches/money_transfer.patch
          ./patches/passenger_arrived_webhook.patch
          ./patches/contract_arrived_webhook.patch
          ./patches/cargo_dumped_webhook.patch
          ./patches/fix_teleport_player.patch
          ./patches/set_money_webhook.patch
          ./patches/tow_request_arrived_webhook.patch
          ./patches/join_leave_event.patch
          ./patches/player_send_chat.patch
          ./patches/fix_vehicle_serialization.patch
          ./patches/pull_webhook.patch
          ./patches/safe_hooks.patch
          ./patches/guard_transfer_money.patch
          ./patches/tp_no_vehicles.patch
        ];
        prePatch = ''
          find ./Scripts -type f -exec sed -i 's/\r$//' {} +;
        '';
        postPatch = ''
          find ./Scripts -type f -exec sed -i 's/$/\r/' {} +;
        '';
      };
      shared = pkgs.fetchzip {
        url = "https://github.com/drpsyko101/MotorTownMods/releases/download/v0.9/shared.zip";
        hash = "sha256-vHMj89ohLveSnVjo02dwRoVPKHcwhJxjhzfU041mkc0=";
      };
    };
  } // lib.genAttrs (lib.attrNames ue4ssVersionMap) mkModFromBranch;

  motorTownMods = motorTownModsVersions.${modVersion};

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
    cp --no-preserve=mode,ownership "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/UE4SS.log" "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/UE4SS.backup.log" 2>/dev/null
    cp --no-preserve=mode,ownership -r ${motorTownMods.ue4ss}/ue4ss "$STATE_DIRECTORY/MotorTown/Binaries/Win64"
    cp --no-preserve=mode,ownership -r ${motorTownMods.ue4ss}/version.dll "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS-settings.ini "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS_Signatures "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss"
    rm -rf "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods"
    cp --no-preserve=mode,ownership -r ${motorTownMods.mod} "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods"
    # cp --no-preserve=mode,ownership -r ${./MotorTownMods/Scripts}/*.lua "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods/Scripts"
    cp --no-preserve=mode,ownership -r ${motorTownMods.shared}/* "$STATE_DIRECTORY/MotorTown/Binaries/Win64/ue4ss/Mods/shared"

    # Paks
    find $STATE_DIRECTORY/MotorTown/Content/Paks/ -maxdepth 1 -type f -name "*.pak" -not -name "MotorTown-WindowsServer.pak" -delete
    ${lib.strings.concatStringsSep "\n" externalModsScripts}
    mkdir -p "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer"
    cp --no-preserve=mode,ownership -r ${engineIniFile} "$STATE_DIRECTORY/MotorTown/Saved/Config/WindowsServer/Engine.ini"
  '';
in {
  inherit installModsScriptBin motorTownMods;
}
