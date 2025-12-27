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

## Mod Development Workflow

Mods are stored in the `MotorTownMods` submodule. We use a branch-based versioning system where each release has its own branch (e.g., `release/v19`).

### Local Development

1.  Set `services.motortown-server.modVersion = "dev";` in your NixOS configuration.
2.  Make changes to the Lua scripts in `./MotorTownMods/Scripts`.
3.  If you have a new compiled DLL, place it in `./MotorTownMods/dlls/main.dll`.
4.  **Important**: Because this is a Flake, you must stage your changes for Nix to see them:
    ```bash
    git add MotorTownMods
    ```
5.  Deploy as usual. Nix will bundle your local `./MotorTownMods` folder.

### Creating a New Release

1.  Make sure your changes on the `master` branch in the `MotorTownMods` submodule are ready.
2.  Create and push a new release branch:
    ```bash
    cd MotorTownMods
    git checkout -b release/v20
    git push -u origin release/v20
    ```
3.  **GitHub Actions** will automatically trigger, compile the project on Windows, and commit the resulting `main.dll` back to the `release/v20` branch.
4.  Get the commit hash of the new release:
    ```bash
    git rev-parse HEAD
    ```
5.  Update `mods.nix` in the parent repository:
    *   Add the version to `ue4ssVersionMap`.
    *   Add the version and its commit hash to `revMap`.

### Updating an Existing Release

If you need to push a fix to an existing release branch (e.g., `release/v19`):
1.  Push the changes to the branch in the submodule.
2.  Wait for the CI to finish and commit the new DLL.
3.  Update the commit hash in `mods.nix`'s `revMap`. This is required to keep the build "locked" and pure-compatible.

