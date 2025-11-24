# SPDX-License-Identifier: Unlicense
{
  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self, nixpkgs, systems, ... }@inputs:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = eachSystem (pkgs: {
        default = (import ./mods.nix { inherit pkgs; lib = pkgs.lib; }).motorTownMods;
      });
      nixosModules.default = import ./motortown-server.nix;
      nixosModules.logger = import ./logger.nix;

      nixosModules.containers =  { config, pkgs, lib, ... }:
      with lib;
      let
        hostConfig = config;
        cfg = config.services.motortown-server-containers;
        hostStateForContainer = name: "/var/lib/motortown-server-${name}";
        openPorts = lib.flatten (lib.attrsets.mapAttrsToList (name: backendOptions: [
          backendOptions.motortown-server.port backendOptions.motortown-server.queryPort
        ]) cfg);
        mkContainer = name: backendOptions: {
          name = "motortown-server-${name}";
          value = {
            autoStart = true;
            restartIfChanged = false;
            bindMounts.${backendOptions.motortown-server.credentialsFile}.isReadOnly = true;
            bindMounts.${name} = {
              isReadOnly = false;
              mountPoint = "/var/lib/motortown-server";
              hostPath = hostStateForContainer name;
            };
            config = { config, pkgs, lib, ... }: ({
              imports = [
                self.nixosModules.default
                hostConfig.services.motortown-server-containers-env
                backendOptions.config
              ] ++ backendOptions.imports;
              services.motortown-server = { logsTag = name; } // backendOptions.motortown-server;
            });
          };
        };
      in {
        options = {
          services.motortown-server-containers = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options.imports = lib.mkOption {
                type = lib.types.listOf lib.types.deferredModule;
                default = [];
              };
              options.config = lib.mkOption {
                type = lib.types.attrs;
                default = {};
              };
              options.motortown-server = lib.mkOption {
                type = lib.types.submodule (import ./backend-options.nix);
              };
            });
          };
          services.motortown-server-containers-env = lib.mkOption {
            type = lib.types.attrs;
            default = {};
          };
        };

        config = {
          systemd.tmpfiles.settings = lib.attrsets.concatMapAttrs (name: backendOptions: {
            "motortown-server-${name}" = {
              ${hostStateForContainer name} = {
                d = {
                  group = "modders";
                  mode = "0755";
                  user = "root";
                };
              };
            };
          }) cfg;

          networking.firewall.allowedTCPPorts = openPorts;
          networking.firewall.allowedUDPPorts = openPorts;

          containers = listToAttrs (mapAttrsToList mkContainer cfg);
        };
      };

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (pkgs.writeShellScriptBin "deploy-scripts" (builtins.readFile ./deploy_mod.sh))
            # Add development dependencies here
          ];
        };
      });
    };
}
