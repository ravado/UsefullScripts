#!/usr/bin/env bash
set -euo pipefail

# --- Configurable paths ---
LOCAL_PATH="${HOME}/Downloads/Photos"
NAS_BASE="/Volumes/Photo-Frames"
LOG_FILE="${HOME}/sync_photos.log"

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
  home)          TARGET_DIR="Home" ;;
  batanovs)      TARGET_DIR="Batanovs" ;;
  cherednychoks) TARGET_DIR="Cherednychoks" ;;
  *)
    echo "❌ Invalid target: $TARGET"
    usage
    ;;
esac

DEST="${NAS_BASE}/${TARGET_DIR}/Original"

# --- Logging ---
timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }

log "📂 Starting photo sync"
log "   From: ${LOCAL_PATH}"
log "   To:   ${DEST}"
[[ $DRY_RUN -eq 1 ]] && log "   Mode: Dry-run" || log "   Mode: Live"

# --- Run rsync ---
RSYNC_OPTS="-avh --delete"
[[ $DRY_RUN -eq 1 ]] && RSYNC_OPTS="$RSYNC_OPTS --dry-run"

# Pipe rsync output to both console and logfile
rsync $RSYNC_OPTS "$LOCAL_PATH/" "$DEST/" 2>&1 | tee -a "$LOG_FILE"

log "✅ Sync finished"