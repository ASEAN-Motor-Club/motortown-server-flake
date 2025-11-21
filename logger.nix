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
    services.rsyslogd.extraConfig = ''
      input(type="imfile"
        File="${cfg.serverLogsPath + "/*.log"}"
        Tag="${cfg.tag}"
        ruleset="mt-out"
        addMetadata="on"
      )
    '';
  };
}
