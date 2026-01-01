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

## Development Deployment Workflow

For rapid development iteration, use the `scripts/deploy-dev-mod.sh` script to deploy UE4SS mods (like MTDediMod) directly to a remote NixOS server without going through the full release process.

### Script Overview

The deployment script ([scripts/deploy-dev-mod.sh](./scripts/deploy-dev-mod.sh)) automates:
- Building the mod package using Nix
- Syncing mod files and shared DLLs to the server
- Fixing permissions for container users
- Optionally restarting containers or reloading mods via API

### Prerequisites

1.  **SSH Access**: You need SSH access to the target server (e.g., `root@asean-mt-server`)
2.  **MTDediMod Source**: The mod source should be in `./MTDediMod` or a custom path
3.  **Shared DLLs**: Windows DLLs (luasocket, cjson, ssl, etc.) should be in `../shared` relative to the script or set via `SHARED_PATH`
4.  **Nix Package Command**: The mod must have a `nix run .#package` command that builds to `./package/`

### Basic Usage

Deploy to a server (builds automatically if needed):
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server
```

The script will:
1. Build the mod package (unless `package/` already exists)
2. Rsync files to `/var/lib/mtdedimod-dev/ue4ss/` on the server
3. Copy shared DLLs to `/var/lib/mtdedimod-dev/ue4ss/Mods/shared/`
4. Fix permissions (`steam:modders`)

### Common Options

**Deploy and restart the container:**
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server --restart
```

**Deploy and restart a custom container:**
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server --restart motortown-server-dev
```

**Deploy and hot-reload mods via API (no container restart):**
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server --reload
```

**Skip building (use existing package):**
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server --no-build
```

**Custom mod path:**
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server --path /custom/path/to/MTDediMod
# Or use environment variable
MTDEDIMOD_PATH=/custom/path ./scripts/deploy-dev-mod.sh root@asean-mt-server
```

### Deployment Modes

| Mode | Command | Use Case |
|------|---------|----------|
| **Basic** | `./scripts/deploy-dev-mod.sh <target>` | Deploy changes without server restart |
| **Restart** | `--restart` | Apply changes requiring full container restart |
| **Hot Reload** | `--reload` | Reload Lua scripts without downtime (via API) |
| **Quick Sync** | `--no-build` | Skip build, sync existing package only |

### Rapid Development Iteration

**Typical workflow for script changes:**

1.  Make changes to your Lua scripts in `MTDediMod/`
2.  Deploy with hot-reload:
    ```bash
    ./scripts/deploy-dev-mod.sh root@asean-mt-server --reload
    ```
3.  Test your changes immediately (server stops briefly, then reloads mods)

**For compiled mod changes (C++ DLLs):**

1.  Make changes to your C++ code
2.  Force rebuild and restart:
    ```bash
    rm -rf MTDediMod/package
    ./scripts/deploy-dev-mod.sh root@asean-mt-server --restart
    ```

**Quick sync without rebuild:**

If you've already built locally and just want to sync files:
```bash
./scripts/deploy-dev-mod.sh root@asean-mt-server --no-build --restart
```

### Advanced Configuration

**Custom shared DLLs path:**
```bash
SHARED_PATH=/path/to/shared ./scripts/deploy-dev-mod.sh root@server
```

**Environment variables:**
```bash
export MTDEDIMOD_PATH=/custom/mtdedimod
export SHARED_PATH=/custom/shared
./scripts/deploy-dev-mod.sh root@asean-mt-server
```

### Troubleshooting

**Package builds with root ownership:**

If files in `package/` are owned by root, remove the package and rebuild:
```bash
sudo rm -rf MTDediMod/package
./scripts/deploy-dev-mod.sh root@asean-mt-server
```

**Permission errors on the server:**

The script automatically fixes permissions, but if issues persist:
```bash
ssh root@asean-mt-server "chown -R steam:modders /var/lib/mtdedimod-dev/ue4ss/ && chmod -R u+w /var/lib/mtdedimod-dev/ue4ss/"
```

**Reload API not responding:**

Ensure the server has the web API enabled and the correct port (55000/55001):
```nix
bEnableHostWebAPIServer = true;
HostWebAPIServerPort = 8080;  # Or your custom port
```

**Build not detecting changes:**

Since this is a Nix flake, stage your changes:
```bash
cd MTDediMod
git add .
cd ..
```

