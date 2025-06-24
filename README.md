# Nix Flake for Motor Town Server

This flake is for running a dedicated "Motor Town: Behind the Wheel" dedicated server.

## Usage

Use this flake as an input for your flake.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    motortown-server.url = "github:ASEAN-Motor-Club/motortown-server-flake";
  };
  outputs =
    { self, nixpkgs, motortown-server, ... }@inputs: {
    # Your flake outputs here
  }
}
```


Include `nixosModules.default` as a module in your NixOS configuration.

```nix
{
  ### in configuration.nix, or as a module passed into nixpkgs.lib.nixosSystem
  services.motortown-server = {
    enable = true;
    enableMods = false;
    user = "steam";
    openFirewall = true;
    credentialsFile = /path/to/dotenv/file;
    dedicatedServerConfig =  {
      ServerName = "Test Server";
      ServerMessage = "Welcome";
      Password = "";
      MaxPlayers = 10;
      MaxVehiclePerPlayer = 10;
      bAllowPlayerToJoinWithCompanyVehicles = true;
      bAllowCompanyAIDriver = true;
      MaxHousingPlotRentalPerPlayer = 1;
      MaxHousingPlotRentalDays = 7;
      HousingPlotRentalPriceRatio = 0.1;
      bAllowModdedVehicle = false;
      NPCVehicleDensity = 0.2;
      NPCPoliceDensity = 0.1;
      bEnableHostWebAPIServer = true;
      HostWebAPIServerPassword = "hackme";
      HostWebAPIServerPort = 8080;
      Admins = [
        {
          UniqueNetId = "12345";
          Nickname = "Admin1";
        }
        {
          UniqueNetId = "54321";
          Nickname = "Admin2";
        }
      ];
    };
  };
}
```


## Bootstraping

Before you can run this service successfully, you have to run `steam` at least
once under the `user` you provided, in order for the dedicated server to launch successfully.

## Updating the Dedicated Server

By default, restarting the service will not update the server.
To force an update, delete `/var/lib/motortown-server/DedicatedServerConfig.json`, then restart the server.
The missing file would be detected, which triggers the update.

