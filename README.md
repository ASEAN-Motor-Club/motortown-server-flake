# Nix Flake for Motor Town Server

This flake is for running a dedicated "Motor Town: Behind the Wheel" dedicated server.

Include `nixosModules.default` as a module in your NixOS configuration.

```nix
{
  ### in configuration.nix
  services.motortown-server = {
    enable = true;
    user = "steam";
    openFirewall = true;
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

Before you can run this service successfully, you must first run `motortown-update` using the user that you have specified.
You must export `STEAM_USERNAME` and `STEAM_PASSWORD` environment variables.
This will run steamcmd to install the dedicated server.
If you have enabled mods, this step will also install UE4SS and the mods.

You also have to run `steam` at least once before the dedicated server can launch successfully.

This process can be automated using a oneshot systemd service, which is left as an exercise for the reader.

