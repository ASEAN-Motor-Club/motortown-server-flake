# SPDX-License-Identifier: Unlicense
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self, nixpkgs, systems, ... }@inputs:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
    in
    {
      nixosModules.default = import ./motortown-server.nix;
      nixosModules.logger = import ./logger.nix;

      nixosModules.containers =  { config, pkgs, lib, ... }:
      with lib;
      let
        hostConfig = config;
        cfg = config.services.motortown-server-containers;
        hostStateForContainer = name: "/var/lib/motortown-server-${name}";
        mkContainer = name: backendOptions: {
          name = "motortown-server-${name}";
          value = {
            autoStart = true;
            bindMounts.${backendOptions.credentialsFile}.isReadOnly = true;
            bindMounts.${name} = {
              isReadOnly = false;
              mountPoint = "/var/lib/motortown-server";
              hostPath = hostStateForContainer name;
            };
            config = { config, pkgs, lib, ... }: {
              imports = [
                self.nixosModules.default
              ];
              services.motortown-server = backendOptions;
            };
          };
        };
      in {
        options = {
          services.motortown-server-containers = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule (import ./backend-options.nix));
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

          networking.firewall.allowedTCPPorts = lib.flatten (lib.attrsets.mapAttrsToList (name: backendOptions: [
            backendOptions.port backendOptions.queryPort
          ]) cfg);
          networking.firewall.allowedUDPPorts = lib.flatten (lib.attrsets.mapAttrsToList (name: backendOptions: [
            backendOptions.port backendOptions.queryPort
          ]) cfg);

          containers = listToAttrs (mapAttrsToList mkContainer cfg);
        };
      };

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Add development dependencies here
          ];
        };
      });
    };
}
