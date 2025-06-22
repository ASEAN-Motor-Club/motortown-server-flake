{ lib, pkgs, config, ...}:
with lib;
let
  cfg = config.services.motortown-server;

  # Paths
  steamPath = "/home/${cfg.user}/.steam/steam";
  gamePath = "${steamPath}/${cfg.steamappsDir}/common/Motor Town Behind The Wheel - Dedicated Server";
  ue4ssAddons = ../ue4ss;

  # Game Settings
  gameAppId = "2223650"; # Steam App ID
  serverConfigType = types.submodule {
    options = {
      ServerName = mkOption {
        type = types.str;
        default = "MyServer";
      };
      ServerMessage = mkOption {
        type = types.str;
        default = "Welcome!\nHave fun!";
      };
      Password = mkOption {
        type = types.str;
        default = "";
      };
      MaxPlayers = mkOption {
        type = types.ints.positive;
        default = 10;
      };
      MaxVehiclePerPlayer = mkOption {
        type = types.ints.positive;
        default = 5;
      };
      bAllowPlayerToJoinWithCompanyVehicles = mkOption {
        type = types.bool;
        default = true;
      };
      bAllowCompanyAIDriver = mkOption {
        type = types.bool;
        default = true;
      };
      MaxHousingPlotRentalPerPlayer = mkOption {
        type = types.ints.unsigned;
        default = 1;
      };
      MaxHousingPlotRentalDays = mkOption {
        type = types.ints.positive;
        default = 7;
      };
      HousingPlotRentalPriceRatio = mkOption {
        type = types.numbers.nonnegative;
        default = 0.1;
      };
      bAllowModdedVehicle = mkOption {
        type = types.bool;
        default = false;
        description = "Set this to 'false' to despawn vehicles altered by an external program";
      };
      NPCVehicleDensity = mkOption {
        type = types.numbers.nonnegative;
        default = 0.5;
      };
      NPCPoliceDensity = mkOption {
        type = types.numbers.nonnegative;
        default = 0.0;
      };
      bEnableHostWebAPIServer = mkOption {
        type = types.bool;
        default = true;
      };
      HostWebAPIServerPassword = mkOption {
        type = types.str;
        default = "hackme";
      };
      HostWebAPIServerPort = mkOption {
        type = types.port;
        default = 8080;
      };
      Admins = mkOption {
        type = types.listOf (types.submodule {
          options = {
            UniqueNetId = mkOption {
              type = types.str;
              description = "The steam id of the player";
            };
            Nickname = mkOption {
              type = types.str;
              description = "The in-game nickname of the player";
            };
          };
        });
        default = [];
      };
    };
  };
  dedicatedServerConfigFile = pkgs.writeText "DedicatedServerConfig.json" (builtins.toJSON cfg.dedicatedServerConfig);
  apiPassword = cfg.dedicatedServerConfig.HostWebAPIServerPassword;
  apiPort = cfg.dedicatedServerConfig.HostWebAPIServerPort;

  # Restore $ sign for variable
  serverRestartMessageParam = builtins.replaceStrings
    [ "%24" ]
    [ "$" ]
    (lib.strings.escapeURL cfg.serverRestartMessage);

  # UE4SS Mod
  ue4ss = pkgs.fetchzip {
    url = "https://github.com/UE4SS-RE/RE-UE4SS/releases/download/experimental/zDEV-UE4SS_v3.0.1-428-g65beeb1.zip";
    hash = "sha256-xFax9HIaSspJLfsJ/glAf25/x4jID1+xMIlmpbBcMMc=";
    stripRoot = false;
  };

  motorTownMods = pkgs.fetchFromGithub {
    owner = "drpsyko101";
    repo = "MotorTownMods";
    rev = "main";
    hash = lib.fakeHash;
  };
in
{
  options.services.motortown-server = {
    enable = lib.mkEnableOption "Enable Module";
    enableMods = mkOption {
      type = types.bool;
      default = false;
    };
    user = mkOption {
      type = types.str;
      default = "steam";
    };
    steamuser = mkOption {
      type = types.str;
      default = "user";
    };
    steampassword = mkOption {
      type = types.str;
      default = "password";
    };
    betaBranch = mkOption {
      type = types.str;
      default = "test";
    };
    betaBranchPassword = mkOption {
      type = types.str;
      default = "motortowndedi";
    };
    steamappsDir = mkOption {
      type = types.str;
      default = "Steamapps";
    };
    serverRestartMessage = mkOption {
      type = types.str;
      default = "The server will restart in $minutes minutes. You can rejoin 5 minutes after that";
    };
    dedicatedServerConfig = mkOption {
      type = serverConfigType;
      description = "DedicatedServerConfig.json. See the README in the dedi files.";
      default = null;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.motortown-server = {
      wantedBy = [ "multi-user.target" ]; 
      after = [ "network.target" ];
      description = "Motortown Dedicated Server";
      environment = {
        STEAM_COMPAT_CLIENT_INSTALL_PATH=steamPath;
        STEAM_COMPAT_DATA_PATH="${steamPath}/${cfg.steamappsDir}/compatdata/${gameAppId}";
        WINEDLLOVERRIDES="version=n,b";
      };
      restartIfChanged = false;
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Restart = "always";
        EnvironmentFile = config.system.build.setEnvironment;
        KillSignal = "SIGKILL";
      };
      script = ''
        cp --no-preserve=mode,owner ${dedicatedServerConfigFile} "${gamePath}/DedicatedServerConfig.json"
        ${pkgs.steam-run}/bin/steam-run ${pkgs.proton-ge-bin.steamcompattool}/proton run "${gamePath}/MotorTown/Binaries/Win64/MotorTownServer-Win64-Shipping.exe" Jeju_World?listen? -server -log -useperfthreads -Port=7777 -QueryPort=27015
      '';
    };

    systemd.services.motortown-server-restart-announcement = {
      description = "Motortown Dedicated Server Restart Announcement";
      environment = {
      };
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        EnvironmentFile = config.system.build.setEnvironment;
        KillSignal = "SIGKILL";
      };
      script = ''
        source ${config.system.build.setEnvironment}
        minutes_to_time() {
            local target_time="$1"
            
            # Check if the target time is provided
            if [ -z "$target_time" ]; then
                echo "Usage: minutes_to_time HH:MM" >&2
                return 1
            fi

            # Get the current time in seconds since the epoch
            local current_epoch
            current_epoch=$(date +%s)

            # Convert the target time to epoch seconds (today's date with the provided time)
            local target_epoch
            target_epoch=$(date -d "$(date +%Y-%m-%d) $target_time" +%s 2>/dev/null)

            # Check if the time conversion was successful
            if [ $? -ne 0 ]; then
                echo "Invalid time format. Please use HH:MM (e.g., 15:30)." >&2
                return 1
            fi

            # If the target time has already passed today, set it for tomorrow
            if [ "$target_epoch" -le "$current_epoch" ]; then
                target_epoch=$(date -d "tomorrow $target_time" +%s)
            fi

            # Calculate the difference in minutes
            local minutes_left=$(( (target_epoch - current_epoch) / 60 ))
            
            echo "$minutes_left"
        }
        minutes=$(minutes_to_time "01:30")
        curl -X POST "http://localhost:${builtins.toString apiPort}/chat?password=${apiPassword}&message=${serverRestartMessageParam}" -d ""
      '';
    };

    systemd.services.motortown-server-restart = {
      description = "Motortown Dedicated Server Restart";
      environment = {
      };
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        EnvironmentFile = config.system.build.setEnvironment;
        KillSignal = "SIGKILL";
      };
      script = ''
        source ${config.system.build.setEnvironment}
        systemctl reboot
      '';
    };

    systemd.timers.motortown-server-restart = {
      description = "Timer to restart the server";
      timerConfig = {
        OnCalendar = "Mon,Sat *-*-* 01:30:00";
        AccuracySec = "1min";
        Unit = "motortown-server-restart.service";
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.timers.motortown-server-restart-announcement = {
      description = "Timer to restart the server";
      timerConfig = {
        OnCalendar = "Mon,Sat *-*-* 01:15,25,29";
        AccuracySec = "1min";
        Unit = "motortown-server-restart-announcement.service";
      };
      wantedBy = [ "timers.target" ];
    };

    environment.systemPackages = let
      installModsScript = ''
        cp --no-preserve=mode,ownership -r ${ue4ss}/ue4ss "${gamePath}/MotorTown/Binaries/Win64/"
        cp --no-preserve=mode,ownership -r ${ue4ssAddons}/version.dll "${gamePath}/MotorTown/Binaries/Win64/"
        cp --no-preserve=mode,ownership -r ${ue4ssAddons}/UE4SS-settings.ini "${gamePath}/MotorTown/Binaries/Win64/ue4ss"
        cp --no-preserve=mode,ownership -r ${motorTownMods} "${gamePath}/MotorTown/Binaries/Win64/ue4ss/Mods"
      '';
      serverUpdateScript = pkgs.writeScriptBin "motortown_update" ''
        set -xeu

        steamcmd +@sSteamCmdForcePlatformType windows +login ${cfg.steamuser} ${cfg.steampassword} +app_update 1007 validate +app_update ${gameAppId} -beta test -betapassword motortowndedi validate +quit
        cp ${steamPath}/${cfg.steamappsDir}/common/Steamworks\ SDK\ Redist/*.dll "${gamePath}/MotorTown/Binaries/Win64/"
        mkdir -p "${steamPath}/${cfg.steamappsDir}/compatdata/${gameAppId}"

        ${if cfg.enableMods then installModsScript else ""}
      '';
    in [
      serverUpdateScript
    ];
  };
}
