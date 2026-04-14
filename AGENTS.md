# motortown-server-flake — Agent Guide

## Overview

A Nix flake that packages the Motor Town Dedicated Server with UE4SS mod support. It is consumed as a flake input by the parent `amc-server` repository and produces NixOS modules for running game servers in containers.

## Key Files

| File | Purpose |
|------|---------|
| `mods.nix` | Builds the mod installation script (`install-mt-mods`). Handles UE4SS mod zip extraction and external `.pak` mod downloads. |
| `motortown-server.nix` | NixOS module defining the `services.motortown-server` service (systemd unit, firewall, config generation). |
| `flake.nix` | Flake wiring — exposes the NixOS module and packages. |

---

## External Mods

Third-party `.pak` mods (e.g., Maja's Detail Works, MoneyRun) are managed via the `enableExternalMods` attrset in the NixOS config:

```nix
services.motortown-server.enableExternalMods = {
  "MajasDetailWorksV3-7.18_P" = true;
  "MajasMnTrailerworksV6-7.18_P" = true;
};
```

### How it works

1. Each enabled mod name maps to a `.pak` file downloaded at container startup.
2. The download URL is: `https://www.aseanmotorclub.com/releases/mods/{name}.pak`
3. Downloaded paks are cached at `$STATE_DIRECTORY/.mod-cache/paks/{name}.pak`.
4. On each restart, all non-base `.pak` files in `Content/Paks/` are deleted and re-downloaded.

### Pak naming

- Mod names in `enableExternalMods` become the `.pak` filename (and download path).
- Names containing dashes or dots must be quoted in Nix: `"MajasDetailWorksV3-7.18_P"`.
- The name must match the actual `.pak` filename served at the download URL.

---

## Updating External Mod Paks (Per Game Update)

When Motor Town releases a game update that breaks existing mods, or mod authors release new versions:

### 1. Download the updated mod packages

Get the new `.pak` files from the mod authors (typically via Nexus Mods).

### 2. Rename paks to match the naming convention

The `.pak` filename is the key used in `enableExternalMods`. Use a consistent pattern that includes the version:

```
MajasDetailWorksV3-7.18_P.pak
MajasMnTrailerworksV6-7.18_P.pak
```

### 3. Upload to amc-peripheral

The mod paks are served by nginx on **`amc-peripheral`** (not `asean-mt-server`). The nginx config maps `https://www.aseanmotorclub.com/releases/` → `/var/lib/mod-releases/`, and the download URL includes `/mods/` in the path.

Upload to `/var/lib/mod-releases/mods/` on amc-peripheral:

```bash
scp ~/Downloads/mt-mods/MajasDetailWorksV3-7.18_P.pak root@amc-peripheral:/var/lib/mod-releases/mods/
scp ~/Downloads/mt-mods/MajasMnTrailerworksV6-7.18_P.pak root@amc-peripheral:/var/lib/mod-releases/mods/
```

The corresponding download URL is `https://www.aseanmotorclub.com/releases/mods/{name}.pak`.

### 4. Update `flake.nix` in the parent repo

In the test container (or production) config, update `enableExternalMods`:

```nix
enableExternalMods = {
  # Remove old mod names
  # Add new mod names (use quoted strings if names contain dashes/dots)
  "MajasDetailWorksV3-7.18_P" = true;
  "MajasMnTrailerworksV6-7.18_P" = true;
};
```

### 5. Deploy

```bash
nix develop --command deploy root@asean-mt-server
```

### Verification

After deployment, check the container logs for download confirmation:

```bash
journalctl -u container@motortown-server-test -f
```

Look for `Downloading external mod: {name}` entries. If a mod fails to download (HTTP 404), verify the pak file exists at the expected URL or local path.

---

## Updating the Game Server

The `motortown-server-update` systemd service handles game updates via steamcmd. It stops the server, runs `app_update`, then restarts — ensuring no file conflicts.

### Trigger via backend

The backend writes to a trigger file on the host. The host's `.path` unit picks it up and starts the update. Two pieces are wired in the parent `flake.nix`:

- `UPDATE_MOTORTOWN_SCRIPT` env var set on the amc-backend service
- Host trigger at `/var/lib/motortown-update-trigger/trigger`

### Manual trigger

```bash
# Inside the container:
systemctl start motortown-server-update.service

# Or via trigger file:
echo "update requested at $(date)" > /var/lib/motortown-update-trigger/trigger
```

### Flow

1. Host `.path` unit detects trigger file change
2. Host `motortown-update-triggered.service` clears the trigger, starts `motortown-server-update.service` inside the container
3. `motortown-server-update` stops the server, runs steamcmd, calls `postInstallScript`, then starts the server

---

## UE4SS Mod (Server Mod)

The server mod (`MotorTownMods_*.zip`) is a separate artifact built from the [MTDediMod](../MTDediMod/) submodule. It is stored at:

```
/var/lib/mod-releases/MotorTownMods_{modVersion}.zip
```

The `modVersion` attribute in the NixOS config controls which version is extracted and installed. The UE4SS mod version is independent from external pak mod versions.
