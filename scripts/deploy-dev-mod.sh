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
  -g, --generate-types  Deploy TypeGenerator mod, sync types back to MTDediMod/types/game/
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
DO_GENERATE_TYPES=false

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
    -g|--generate-types) DO_GENERATE_TYPES=true; shift ;;
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

# Deploy TypeGenerator if requested
if [[ "$DO_GENERATE_TYPES" == "true" ]]; then
  echo "==> Deploying TypeGenerator mod..."
  rsync -avz "$MTDEDIMOD_PATH/TypeGenerator/" "$TARGET:/var/lib/mtdedimod-dev/ue4ss/Mods/TypeGenerator/"
  
  # Add TypeGenerator to mods.txt if not already present
  echo "==> Enabling TypeGenerator in mods.txt..."
  ssh "$TARGET" "grep -q '^TypeGenerator' /var/lib/mtdedimod-dev/ue4ss/Mods/mods.txt || echo 'TypeGenerator : 1' >> /var/lib/mtdedimod-dev/ue4ss/Mods/mods.txt"
fi

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

# Health check
HOST="${TARGET#*@}"
echo "==> Running health check on $HOST:55001/status..."
HEALTH_CHECK_RETRIES=5
HEALTH_CHECK_DELAY=2

for i in $(seq 1 $HEALTH_CHECK_RETRIES); do
  RESPONSE=$(curl -s "$HOST:55001/status" 2>/dev/null || echo "")
  if [[ "$RESPONSE" == '{"status":"ok"}' ]]; then
    echo "✓ Health check passed: Server is responding correctly"
    break
  else
    if [[ $i -lt $HEALTH_CHECK_RETRIES ]]; then
      echo "  Health check attempt $i/$HEALTH_CHECK_RETRIES failed (got: '$RESPONSE'), retrying in ${HEALTH_CHECK_DELAY}s..."
      sleep $HEALTH_CHECK_DELAY
    else
      echo "✗ Health check failed after $HEALTH_CHECK_RETRIES attempts"
      echo "  Expected: '{\"status\":\"ok\"}'"
      echo "  Got: '$RESPONSE'"
      echo "⚠ Deployment completed but server may not be healthy"
      exit 1
    fi
  fi
done

# Generate and sync types if requested
if [[ "$DO_GENERATE_TYPES" == "true" ]]; then
  echo ""
  echo "==> Generating Lua types..."
  echo "Waiting 30 seconds for game state initialization and type generation..."
  sleep 30
  
  # Check if types were generated
  echo "==> Checking if types were generated on server..."
  TYPE_COUNT=$(ssh "$TARGET" "find /var/lib/mtdedimod-dev/ue4ss/Mods/shared/types -name '*.lua' 2>/dev/null | wc -l" || echo "0")
  
  if [[ "$TYPE_COUNT" -gt 0 ]]; then
    echo "✓ Found $TYPE_COUNT type files on server"
    
    # Sync types to local MTDediMod/types/game/
    echo "==> Syncing types to $MTDEDIMOD_PATH/types/game/..."
    mkdir -p "$MTDEDIMOD_PATH/types/game"
    rsync -avz "$TARGET:/var/lib/mtdedimod-dev/ue4ss/Mods/shared/types/" "$MTDEDIMOD_PATH/types/game/"
    
    echo "✓ Types synced successfully"
    echo ""
    echo "Next steps:"
    echo "  1. Review the generated types in types/game/"
    echo "  2. Commit them: git add types/game/ && git commit -m 'feat: update generated Lua types'"
    echo "  3. Disable TypeGenerator mod if no longer needed"
  else
    echo "⚠ Warning: No type files found on server"
    echo "Check server logs for TypeGenerator output:"
    echo "  ssh $TARGET 'tail -100 /var/lib/mtdedimod-dev/ue4ss/UE4SS.log | grep TypeGenerator'"
  fi
fi

echo "==> Done!"
