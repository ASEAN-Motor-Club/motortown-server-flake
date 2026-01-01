#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <target> [options]

Deploy MTDediMod dev build to a NixOS server.
Also copies shared folder (Windows DLLs: luasocket, cjson, ssl, etc.)

Arguments:
  target                SSH target (e.g., root@server)

Options:
  -p, --path PATH       Path to MTDediMod source (default: \$PWD/MTDediMod)
  -r, --restart [NAME]  Restart container after deploy (default name: motortown-server-test)
  -l, --reload          Reload mods via API (stops server first)
  -n, --no-build        Skip building, use existing package
  -h, --help            Show this help message

Environment:
  MTDEDIMOD_PATH        Alternative to -p option
  SHARED_PATH           Path to shared folder with Windows DLLs (default: ../shared relative to script)

Examples:
  $(basename "$0") root@asean-mt-server
  $(basename "$0") root@test-server -c motortown-server-dev
  MTDEDIMOD_PATH=/custom/path $(basename "$0") root@server
EOF
  exit "${1:-0}"
}

# Defaults
MTDEDIMOD_PATH="${MTDEDIMOD_PATH:-$PWD/MTDediMod}"
CONTAINER_NAME="motortown-server-test"
TARGET=""
NO_BUILD="${NO_BUILD:-false}"
DO_RESTART=false
DO_RELOAD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    -p|--path) MTDEDIMOD_PATH="$2"; shift 2 ;;
    -r|--restart)
      DO_RESTART=true
      if [[ ${2:-} && ! ${2:-} =~ ^- ]]; then
        CONTAINER_NAME="$2"; shift
      fi
      shift ;;
    -l|--reload) DO_RELOAD=true; shift ;;
    -n|--no-build) NO_BUILD=true; shift ;;
    -*) echo "Unknown option: $1"; usage 1 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Error: target is required"
  usage 1
fi

if [[ "$NO_BUILD" == "true" ]]; then
  echo "==> Skipping build (--no-build)"
elif [[ -d "$MTDEDIMOD_PATH/package" ]]; then
  echo "==> Package already exists, skipping build (use 'rm -rf $MTDEDIMOD_PATH/package' to force rebuild)"
else
  echo "==> Building MTDediMod package from $MTDEDIMOD_PATH..."
  (cd "$MTDEDIMOD_PATH" && nix run .#package)
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_PATH="${SHARED_PATH:-$SCRIPT_DIR/../shared}"

echo "==> Rsyncing mod package to $TARGET:/var/lib/mtdedimod-dev/ue4ss/"
rsync -avz --delete \
  --exclude 'UE4SS.log' --exclude '*.backup.log' \
  "$MTDEDIMOD_PATH/package/ue4ss/" "$TARGET:/var/lib/mtdedimod-dev/ue4ss/"

echo "==> Rsyncing shared DLLs to $TARGET:/var/lib/mtdedimod-dev/ue4ss/Mods/shared/"
rsync -avz "$SHARED_PATH/" "$TARGET:/var/lib/mtdedimod-dev/ue4ss/Mods/shared/"

echo "==> Fixing permissions for container user..."
ssh "$TARGET" "chown -R steam:modders /var/lib/mtdedimod-dev/ue4ss/ && chmod -R u+w /var/lib/mtdedimod-dev/ue4ss/"

if [[ "$DO_RESTART" == "true" ]]; then
  echo "==> Restarting container '$CONTAINER_NAME'..."
  ssh "$TARGET" "nixos-container restart $CONTAINER_NAME"
else
  echo "==> Skipping container restart (use -r to restart)"
fi

if [[ "$DO_RELOAD" == "true" ]]; then
  # Extract host from TARGET (removes user@ part if present)
  HOST="${TARGET#*@}"
  echo "==> Reloading mods on $HOST..."
  curl -X POST "$HOST:55001/stop"
  sleep 1
  curl -X POST "http://$HOST:55000/mods/reload" -d ""
fi

echo "==> Done!"
