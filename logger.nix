{ lib, pkgs, config, ...}:
with lib;
let
  cfg = config.services.motortown-server-logger;
in
{
  options.services.motortown-server-logger = {
    enable = lib.mkEnableOption "log streaming";
    serverLogsPath = mkOption {
      type = types.str;
      description = "The path to Saved/ServerLog";
    };
    modLogsPath = mkOption {
      type = types.str;
      description = "The path to UE4SS.log";
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
    tag = mkOption {
      type = types.str;
      description = "The tag for log lines";
      default = "mt-server";
    };
  };

  config = mkIf cfg.enable {
    services.rsyslogd = {
      enable = true;
      extraConfig = ''
        module(load="imfile")
        module(load="omrelp")

        input(type="imfile"
          File="${cfg.serverLogsPath + "/*.log"}"
          Tag="${cfg.tag}"
          ruleset="mt-out"
          addMetadata="on"
        )
        input(type="imfile"
          File="${cfg.modLogsPath}"
          Tag="${cfg.tag}"
          ruleset="mod-out"
        )
        template(name="with_filename" type="list") {
          property(name="timestamp" dateFormat="rfc3339")
          constant(value=" ")
          property(name="hostname")
          constant(value=" ")
          property(name="syslogtag")
          constant(value=" ")
          property(name="$!metadata!filename")
          property(name="msg" spifno1stsp="on" )
          property(name="msg" droplastlf="on" )
          constant(value="\n")
        }
        Ruleset(name="mt-out") {
          action(type="omrelp"
            target="${cfg.relpServerHost}"
            port="${toString cfg.relpServerPort}"
            template="with_filename"
          )
        }
        Ruleset(name="mod-out") {
          action(type="omfile"
            File="/var/log/UE4SS.log"
          )
        }
      '';
    };
  };
}
