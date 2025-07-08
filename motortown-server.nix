{ lib, pkgs, config, ...}:
with lib;
let
  mods = import ./mods.nix { inherit pkgs; };
  cfg = config.services.motortown-server;

  # Paths
  steamPath = "/home/${cfg.user}/.steam/steam";

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

  # Restore $ sign for variable interpolation
  restartMessageParam = builtins.replaceStrings
    [ "%24" ]
    [ "$" ]
    (lib.strings.escapeURL cfg.restartMessage);

  serverUpdateScript = pkgs.writeScriptBin "motortown-update" ''
    set -xeu

    if [ -z "''${STEAM_USERNAME}" ]; then
      echo "Error: Environment variable STEAM_USERNAME is not set." >&2
      exit 1
    fi

    if [ -z "''${STEAM_PASSWORD}" ]; then
      echo "Error: Environment variable STEAM_PASSWORD is not set." >&2
      exit 1
    fi

    ${pkgs.steamcmd}/bin/steamcmd +@sSteamCmdForcePlatformType windows \
      +force_install_dir $STATE_DIRECTORY \
      +login $STEAM_USERNAME $STEAM_PASSWORD \
      +app_update ${gameAppId} -beta ${cfg.betaBranch} -betapassword ${cfg.betaBranchPassword} validate \
      +quit
    cp $STATE_DIRECTORY/*.dll "$STATE_DIRECTORY/MotorTown/Binaries/Win64/"
  '';
in
{
  options.services.motortown-server = {
    enable = lib.mkEnableOption "motortown server";
    postInstallScript = mkOption {
      type = types.str;
      default = if cfg.enableMods
        then lib.getExe mods.installModsScriptBin
        else nil;
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the require ports for the game server";
    };
    port = mkOption {
      type = types.int;
      default = 7777;
    };
    queryPort = mkOption {
      type = types.int;
      default = 27015;
    };
    user = mkOption {
      type = types.str;
      default = "steam";
      description = "The OS user that the process will run under";
    };
    stateDirectory = mkOption {
      type = types.str;
      default = "motortown-server";
      description = "The path where the server will be installed (inside /var/lib)";
    };
    betaBranch = mkOption {
      type = types.str;
      default = "beta";
    };
    betaBranchPassword = mkOption {
      type = types.str;
      default = "motortowndedi";
    };
    restartSchedule = mkOption {
      type = types.str;
      default = "Mon,Sat *-*-* 07:30:00";
      description = "The scheduled restart time(s), in systemd OnCalendar format: https://man.archlinux.org/man/systemd.time.7#CALENDAR_EVENTS";
    };
    restartAnnouncementSchedule = mkOption {
      type = types.str;
      default = "Mon,Sat *-*-* 01:15,25,29";
      description = "The scheduled restart announcement time(s), in systemd OnCalendar format: https://man.archlinux.org/man/systemd.time.7#CALENDAR_EVENTS";
    };
    restartMessage = mkOption {
      type = types.str;
      default = "The server will restart in $minutes minutes. You can rejoin 5 minutes after that";
    };
    dedicatedServerConfig = mkOption {
      type = serverConfigType;
      description = "DedicatedServerConfig.json. See the README in the dedi files.";
      default = null;
    };
    environment = mkOption {
      type = types.attrsOf types.str;
      description = "The runtime environment";
      default = {};
    };
    credentialsFile = mkOption {
      type = types.path;
      description = "An environment file containing STEAM_USERNAME and STEAM_PASSWORD";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.port cfg.queryPort];
      allowedUDPPorts = [cfg.port cfg.queryPort];
    };

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "steam"
      "steamcmd"
      "steam-original"
      "steam-unwrapped"
      "steam-run"
      "motortown-server"
      "steamworks-sdk-redist"
    ];

    programs.steam = {
      enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
      protontricks.enable = true;
    };

    users.groups.modders = {
      members = [ cfg.user ];
    };

    systemd.services.motortown-server = {
      wantedBy = [ "multi-user.target" ]; 
      after = [ "network.target" ];
      description = "Motortown Dedicated Server";
      environment = {
        STEAM_COMPAT_CLIENT_INSTALL_PATH = steamPath;
      } // cfg.environment;
      restartIfChanged = false;
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "modders";
        Restart = "always";
        EnvironmentFile = cfg.credentialsFile;
        KillSignal = "SIGKILL";
        StateDirectory = cfg.stateDirectory;
        StateDirectoryMode = "770";
      };
      preStart = ''
        if [[ ! -e "$STATE_DIRECTORY/DedicatedServerConfig.json" ]]; then
          ${lib.getExe serverUpdateScript}
          ${cfg.postInstallScript}
          cp --no-preserve=mode,owner ${dedicatedServerConfigFile} "$STATE_DIRECTORY/DedicatedServerConfig.json"
        fi
        mkdir -p "$STATE_DIRECTORY/compatdata"
        mkdir -p "$STATE_DIRECTORY/run"
      '';
      script = ''
        XDG_RUNTIME_DIR="$STATE_DIRECTORY/run" \
        STEAM_COMPAT_DATA_PATH="$STATE_DIRECTORY/compatdata" \
          ${pkgs.steam-run}/bin/steam-run ${pkgs.proton-ge-bin.steamcompattool}/proton run "$STATE_DIRECTORY/MotorTown/Binaries/Win64/MotorTownServer-Win64-Shipping.exe" Jeju_World?listen? -server -log -useperfthreads -Port=${toString cfg.port} -QueryPort=${toString cfg.queryPort}
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
        curl -X POST "http://localhost:${builtins.toString apiPort}/chat?password=${apiPassword}&message=${restartMessageParam}" -d ""
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
        OnCalendar = cfg.restartSchedule;
        AccuracySec = "1min";
        Unit = "motortown-server-restart.service";
      };
      wantedBy = [ "timers.target" ];
    };

    systemd.timers.motortown-server-restart-announcement = {
      description = "Timer to restart the server";
      timerConfig = {
        OnCalendar = cfg.restartAnnouncementSchedule;
        AccuracySec = "1min";
        Unit = "motortown-server-restart-announcement.service";
      };
      wantedBy = [ "timers.target" ];
    };

    users.users.${cfg.user}.packages = [
      pkgs.steamcmd
    ];
  };
}
