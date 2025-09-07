#!/usr/bin/env bash
set -euo pipefail

# --- Configurable paths ---
LOCAL_PATH="${HOME}/Downloads/Photos"
NAS_BASE="/Volumes/Photo-Frames"

# --- Defaults ---
TARGET=""
DRY_RUN=0

usage() {
  echo "Usage: $0 -target {home|batanovs|cherednychoks} [-n]"
  echo "  -target   NAS target subfolder (required)"
  echo "  -n        Dry run (show what would happen, no changes)"
  exit 1
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -target)
      TARGET="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "❌ Error: -target is required"
  usage
fi

# Capitalize first letter for path mapping
case "$TARGET" in
  home)       TARGET_DIR="Home" ;;
  batanovs)   TARGET_DIR="Batanovs" ;;
  cherednychoks) TARGET_DIR="Cherednychoks" ;;
  *)
    echo "❌ Invalid target: $TARGET"
    usage
    ;;
esac

DEST="${NAS_BASE}/${TARGET_DIR}/Original"

echo "📂 Syncing photos"
echo "   From: ${LOCAL_PATH}"
echo "   To:   ${DEST}"
[[ $DRY_RUN -eq 1 ]] && echo "   Mode: Dry-run" || echo "   Mode: Live"

# --- Run rsync ---
RSYNC_OPTS="-avh --delete"
[[ $DRY_RUN -eq 1 ]] && RSYNC_OPTS="$RSYNC_OPTS --dry-run"

rsync $RSYNC_OPTS "$LOCAL_PATH/" "$DEST/"

echo "✅ Sync finished"