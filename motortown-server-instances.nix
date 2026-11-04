{
  lib,
  pkgs,
  config,
  ...
}:
# Additional Motor Town dedicated servers on the same host, each as its own
# systemd unit (`motortown-server-<name>`), fully independent of the primary
# `services.motortown-server` instance: own state directory, ports, pak set,
# steamcmd installer and Proton prefix.
#
# Kept as a SEPARATE module on purpose: rendering extra units from inside the
# module that declares the primary `services.motortown-server` submodule makes
# the option system recurse (reading the instance configs forces the parent
# module config, which forces the instance configs again).
#
# Extra instances deliberately get no motortown-server-update / restart timers,
# no crash notification and no log streaming — those stay properties of the
# primary server. Start/stop them with plain systemctl on their own unit.
with lib; let
  cfg = config.services.motortown-server-instances;

  gameAppId = "2223650"; # Steam App ID

  mkUpdateScript = binName: c:
    pkgs.writeScriptBin binName ''
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

  mkInstance = name: c: let
    unit = "motortown-server-${name}";
    steamPath = "/home/${c.user}/.steam/steam";
    updateScript = mkUpdateScript "${unit}-update" c;
    configFile = pkgs.writeText "DedicatedServerConfig-${name}.json" (builtins.toJSON c.dedicatedServerConfig);
    mods = import ./mods.nix {
      inherit pkgs lib;
      inherit (c) enableExternalMods engineIni modVersion maxFps;
    };
  in
    mkMerge [
      (mkIf c.openFirewall {
        networking.firewall = {
          allowedTCPPorts = [c.port c.queryPort];
          allowedUDPPorts = [c.port c.queryPort];
        };
      })
      {
        systemd.services.${unit} = {
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
    ];
in {
  options.services.motortown-server-instances = mkOption {
    type = types.attrsOf (types.submodule (import ./backend-options.nix));
    default = {};
    description = ''
      Extra Motor Town dedicated servers, keyed by instance name. Each entry
      becomes its own systemd unit `motortown-server-<name>` running beside
      `services.motortown-server`.

      `stateDirectory` must be set explicitly (its default is the primary
      server's directory and would collide) and every port must be free.
    '';
  };

  config = mkIf (cfg != {}) (mkMerge (mapAttrsToList (name: c: mkIf c.enable (mkInstance name c)) cfg));
}
