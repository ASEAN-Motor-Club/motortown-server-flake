#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <target> [options]

Deploy MTDediMod dev build to a NixOS server.

Arguments:
  target                SSH target (e.g., root@server)

Options:
  -p, --path PATH       Path to MTDediMod source (default: \$HOME/MTDediMod)
  -c, --container NAME  Container name to restart (default: motortown-server-test)
  -h, --help            Show this help message

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

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    -p|--path) MTDEDIMOD_PATH="$2"; shift 2 ;;
    -c|--container) CONTAINER_NAME="$2"; shift 2 ;;
    -*) echo "Unknown option: $1"; usage 1 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Error: target is required"
  usage 1
fi

echo "==> Building MTDediMod package from $MTDEDIMOD_PATH..."
(cd "$MTDEDIMOD_PATH" && nix run .#package)

echo "==> Rsyncing to $TARGET:/var/lib/mtdedimod-dev/ue4ss/"
rsync -avz --delete \
  --exclude 'UE4SS.log' --exclude '*.backup.log' \
  "$MTDEDIMOD_PATH/package/ue4ss/" "$TARGET:/var/lib/mtdedimod-dev/ue4ss/"

echo "==> Fixing permissions for container user..."
ssh "$TARGET" "chown -R steam:modders /var/lib/mtdedimod-dev/ue4ss/ && chmod -R u+w /var/lib/mtdedimod-dev/ue4ss/"

echo "==> Restarting container '$CONTAINER_NAME'..."
ssh "$TARGET" "nixos-container restart $CONTAINER_NAME"

echo "==> Done!"
