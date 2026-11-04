{
  name,
  settings,
}:
# Renders ONE extra Motor Town dedicated server as its own systemd unit
# (`motortown-server-<name>`), independent of the primary
# `services.motortown-server` instance: own state directory, ports, pak set,
# steamcmd installer and Proton prefix.
#
# This is a plain fragment FACTORY rather than a NixOS option on purpose.
# Declaring an `attrsOf submodule` option and rendering its instances from the
# same module recurses (system config -> module config -> option value ->
# system config), and so did feeding `config` into the instance submodule. A
# function returning a module fragment has no option-system involvement at all:
#
#   imports = [ (motortown-server.lib.mkExtraInstance {
#     name = "c1v2";
#     settings = { port = 27779; queryPort = 27017; /* ... */ };
#   }) ];
#
# Extras deliberately get no update/restart timers, no crash notification and
# no log streaming — those stay properties of the primary server.
{ lib, pkgs, ... }: let
  # Mirrors the defaults in backend-options.nix so callers only spell out what
  # differs from a normal server.
  defaults = {
    enable = true;
    enableMods = false;
    mapName = "Jeju_World";
    modVersion = "v0.7.5";
    enableExternalMods = {};
    engineIni = "";
    maxFps = 120;
    postInstallScript = "";
    openFirewall = true;
    port = 7777;
    queryPort = 27015;
    user = "steam";
    stateDirectory = "motortown-server";
    betaBranch = "beta";
    betaBranchPassword = "motortowndedi";
    keepServerLogs = 20;
    credentialsFile = null;
    environment = {};
    dedicatedServerConfig = {};
  };
  c = defaults // settings;

  unit = "motortown-server-${name}";
  steamPath = "/home/${c.user}/.steam/steam";
  gameAppId = "2223650"; # Steam App ID

  updateScript = pkgs.writeScriptBin "${unit}-update" ''
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
      +app_update ${gameAppId} -beta ${c.betaBranch} -betapassword ${c.betaBranchPassword} validate \
      +quit
  '';

  configFile = pkgs.writeText "DedicatedServerConfig-${name}.json" (builtins.toJSON c.dedicatedServerConfig);

  mods = import ./mods.nix {
    inherit pkgs lib;
    inherit (c) enableExternalMods engineIni modVersion maxFps;
  };
in {
  networking.firewall = lib.mkIf c.openFirewall {
    allowedTCPPorts = [c.port c.queryPort];
    allowedUDPPorts = [c.port c.queryPort];
  };

  systemd.services.${unit} = lib.mkIf c.enable {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    description = "Motortown Dedicated Server (${name})";
    environment =
      {
        STEAM_COMPAT_CLIENT_INSTALL_PATH = steamPath;
        WINEDLLOVERRIDES =
          if c.enableMods
          then "version=n,b"
          else "";
      }
      // c.environment;
    restartIfChanged = false;
    serviceConfig = {
      Type = "simple";
      User = c.user;
      Group = "modders";
      Restart = "always";
      RestartSec = "10s";
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
      MemorySwapMax = "0";
      TimeoutStartSec = "30m";
      TimeoutStopSec = "30s";
      LimitNOFILE = "65536";
      EnvironmentFile = c.credentialsFile;
      StateDirectory = c.stateDirectory;
      StateDirectoryMode = "770";
      CPUAffinity = "0 1 2 3";
      Nice = "-5";
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 0;
    };
    preStart = ''
      if [[ ! -e "$STATE_DIRECTORY/DedicatedServerConfig.json" ]]; then
        ${lib.getExe updateScript}
        ${c.postInstallScript}
      fi
      ${
        if c.enableMods
        then (lib.getExe mods.installModsScriptBin)
        else ""
      }
      rm -f "$STATE_DIRECTORY/DedicatedServerConfig.json"
      cp --no-preserve=mode,owner ${configFile} "$STATE_DIRECTORY/DedicatedServerConfig.json"
      mkdir -p "$STATE_DIRECTORY/compatdata"
      mkdir -p "$STATE_DIRECTORY/run"

      log_dir="$STATE_DIRECTORY/MotorTown/Saved/ServerLog"
      log_keep=${toString c.keepServerLogs}
      if [ -d "$log_dir" ]; then
        mkdir -p "$log_dir/archive"
        ls -t "$log_dir"/*.log 2>/dev/null | tail -n +$((log_keep + 1)) | while read -r f; do
          case " $f " in
            *" /archive/ "*) continue ;;
          esac
          mv "$f" "$log_dir/archive/"
        done
      fi
    '';
    script = ''
      export XDG_RUNTIME_DIR="$STATE_DIRECTORY/run"
      export STEAM_COMPAT_DATA_PATH="$STATE_DIRECTORY/compatdata"
      exec ${pkgs.steam-run}/bin/steam-run ${pkgs.proton-ge-bin.steamcompattool}/proton run "$STATE_DIRECTORY/MotorTown/Binaries/Win64/MotorTownServer-Win64-Shipping.exe" "${c.mapName}?listen?" -server -log -useperfthreads -Port=${toString c.port} -QueryPort=${toString c.queryPort}
    '';
  };
}
