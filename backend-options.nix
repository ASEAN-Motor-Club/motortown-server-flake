{ lib, config, ... }:
with lib;
let
  cfg = config;
  serverConfigOptions = {
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
    bAllowCorporation = mkOption {
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
  backendOptions = {
    enable = mkEnableOption "motortown server";
    enableMods = mkEnableOption "mods";
    modVersion = mkOption {
      type = types.str;
      default = "v0.7.5";
    };
    enableLogStreaming = mkEnableOption "log streaming";
    logsTag = mkOption {
      type = types.str;
      default = "mt-server";
    };
    enableExternalMods = mkOption {
      type = types.attrsOf types.bool;
      default = {};
    };
    engineIni = mkOption {
      type = types.str;
      default = "";
    };
    postInstallScript = mkOption {
      type = types.str;
      default = "";
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
      default = "Mon *-*-* 01:30:00";
      description = "The scheduled restart time(s), in systemd OnCalendar format: https://man.archlinux.org/man/systemd.time.7#CALENDAR_EVENTS";
    };
    restartAnnouncementSchedule = mkOption {
      type = types.str;
      default = "Mon *-*-* 01:15,25,29";
      description = "The scheduled restart announcement time(s), in systemd OnCalendar format: https://man.archlinux.org/man/systemd.time.7#CALENDAR_EVENTS";
    };
    restartMessage = mkOption {
      type = types.str;
      default = "The server will restart in $minutes minutes. You can rejoin 5 minutes after that";
    };
    dedicatedServerConfig = mkOption {
      type = types.submodule { options = serverConfigOptions; };
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
    relpServerHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The RELP server host to send logs to";
    };
    relpServerPort = mkOption {
      type = types.int;
      default = 2514;
      description = "The RELP server port to send logs to";
    };
  };

in {
  options = backendOptions;
}
