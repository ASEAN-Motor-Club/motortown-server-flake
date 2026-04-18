# SPDX-License-Identifier: Unlicense
{
  inputs = {
    self.submodules = true;
    self.lfs = true; # Automatically fetch Git LFS files (.pak mods)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    ...
  } @ inputs: let
    eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = eachSystem (pkgs: let
      mods = import ./mods.nix {
        inherit pkgs;
        lib = pkgs.lib;
      };
    in {
      default = mods.installModsScriptBin;
    });
    nixosModules.default = import ./motortown-server.nix;
    nixosModules.logger = import ./logger.nix;

    nixosModules.containers = {
      config,
      pkgs,
      lib,
      ...
    }:
      with lib; let
        hostConfig = config;
        cfg = config.services.motortown-server-containers;
        hostStateForContainer = name: "/var/lib/motortown-server-${name}";
        openPorts = lib.flatten (lib.attrsets.mapAttrsToList (name: backendOptions: [
            backendOptions.motortown-server.port
            backendOptions.motortown-server.queryPort
          ])
          cfg);
        mkContainer = name: backendOptions: let
          mt = backendOptions.motortown-server;
          gameForwardPorts = lib.optionals backendOptions.privateNetwork [
            {
              containerPort = mt.port;
              hostPort = mt.port;
              protocol = "tcp";
            }
            {
              containerPort = mt.port;
              hostPort = mt.port;
              protocol = "udp";
            }
            {
              containerPort = mt.queryPort;
              hostPort = mt.queryPort;
              protocol = "tcp";
            }
            {
              containerPort = mt.queryPort;
              hostPort = mt.queryPort;
              protocol = "udp";
            }
          ];
        in {
          name = "motortown-server-${name}";
          value = {
            autoStart = true;
            restartIfChanged = false;
            inherit (backendOptions) privateNetwork;
            hostAddress = lib.mkIf backendOptions.privateNetwork backendOptions.hostAddress;
            localAddress = lib.mkIf backendOptions.privateNetwork backendOptions.localAddress;
            forwardPorts = gameForwardPorts ++ backendOptions.extraForwardPorts;
            bindMounts.${backendOptions.motortown-server.credentialsFile}.isReadOnly = true;
            bindMounts.${name} = {
              isReadOnly = false;
              mountPoint = "/var/lib/motortown-server";
              hostPath = hostStateForContainer name;
            };
            bindMounts."/var/lib/mtdedimod-dev" = lib.mkIf (backendOptions.motortown-server.modVersion == "dev") {
              isReadOnly = false;
              hostPath = "/var/lib/mtdedimod-dev/ue4ss";
              mountPoint = "/var/lib/motortown-server/MotorTown/Binaries/Win64/ue4ss";
            };
            bindMounts."/var/lib/mod-releases" = {
              isReadOnly = true;
              hostPath = "/var/lib/mod-releases";
            };
            config = {
              config,
              pkgs,
              lib,
              ...
            }: {
              imports =
                [
                  self.nixosModules.default
                  hostConfig.services.motortown-server-containers-env
                  backendOptions.config
                ]
                ++ backendOptions.imports;
              system.stateVersion = "25.05";
              services.motortown-server = {logsTag = name;} // backendOptions.motortown-server;
            };
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
              options.privateNetwork = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Give the container its own private network namespace";
              };
              options.hostAddress = lib.mkOption {
                type = lib.types.str;
                default = "10.250.0.1";
                description = "Host-side IP on the veth pair";
              };
              options.localAddress = lib.mkOption {
                type = lib.types.str;
                default = "10.250.0.2";
                description = "Container-side IP on the veth pair";
              };
              options.extraForwardPorts = lib.mkOption {
                type = lib.types.listOf lib.types.attrs;
                default = [];
                description = "Additional ports to forward from host to container";
              };
            });
          };
          services.motortown-server-containers-env = lib.mkOption {
            type = lib.types.attrs;
            default = {};
          };
        };

        config = {
          systemd.tmpfiles.settings =
            lib.attrsets.concatMapAttrs (name: backendOptions: {
              "motortown-server-${name}" = {
                ${hostStateForContainer name} = {
                  d = {
                    group = "modders";
                    mode = "0755";
                    user = "root";
                  };
                };
              };
            })
            cfg
            // {
              "mtdedimod-dev" = {
                "/var/lib/mtdedimod-dev" = {
                  d = {
                    group = "modders";
                    mode = "0775";
                    user = "root";
                  };
                };
                "/var/lib/mtdedimod-dev/ue4ss" = {
                  d = {
                    group = "modders";
                    mode = "0775";
                    user = "root";
                  };
                };
              };
            };

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
