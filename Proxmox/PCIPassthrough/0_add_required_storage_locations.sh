#!/usr/bin/env bash
set -euo pipefail

log()  { echo -e "➤ $*"; }
warn() { echo -e "⚠️  $*" >&2; }
die()  { echo -e "❌ $*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "Run as root."; }

exists_storage() {
  local id="$1"
  pvesm status 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$id"
}

load_env() {
  local envfile="${1:-.env}"
  [ -f "$envfile" ] || die "Env file '$envfile' not found."
  # shellcheck disable=SC1090
  source "$envfile"
}

# ---------- ISO over NFS ----------
add_or_update_iso_nfs() {
  local id="$ISO_ID"
  local server="${ISO_SERVER:?ISO_SERVER is required}"
  local export="${ISO_EXPORT:?ISO_EXPORT is required}"
  local content="${ISO_CONTENT:-iso}"
  local nodes_opt=""
  local nfsver_opt=""

  [ -n "${ISO_NODES:-}" ]       && nodes_opt="--nodes ${ISO_NODES}"
  [ -n "${ISO_NFS_VERSION:-}" ] && nfsver_opt="--options vers=${ISO_NFS_VERSION}"

  if exists_storage "$id"; then
    log "Storage '$id' exists. Updating NFS settings…"
    # pvesm set не змінює сервер/експорт, тому робимо safe перезапис:
    [ "${DRY_RUN}" = "true" ] || pvesm remove "$id"
  fi

  log "Adding NFS ISO storage '$id' (${server}:${export})…"
  local cmd=(pvesm add nfs "$id" --server "$server" --export "$export" --content "$content")
  [ -n "$nodes_opt" ]  && cmd+=($nodes_opt)
  [ -n "$nfsver_opt" ] && cmd+=($nfsver_opt)
  log "CMD: ${cmd[*]}"
  [ "${DRY_RUN}" = "true" ] || "${cmd[@]}"
}

# ---------- PBS ----------
add_or_update_pbs() {
  local id="$PBS_ID"
  local server="${PBS_SERVER:?PBS_SERVER is required}"
  local ds="${PBS_DATASTORE:?PBS_DATASTORE is required}"
  local user="${PBS_USERNAME:?PBS_USERNAME is required}"
  local secret="${PASSWORD_OR_TOKEN:?PASSWORD_OR_TOKEN is required}"
  local fp="${PBS_FINGERPRINT:?PBS_FINGERPRINT is required}"
  local content="${PBS_CONTENT:-backup}"
  local nodes_opt=""
  local ns_opt=""

  [ -n "${PBS_NODES:-}" ]    && nodes_opt="--nodes ${PBS_NODES}"
  [ -n "${PBS_NAMESPACE:-}" ]&& ns_opt="--namespace ${PBS_NAMESPACE}"

  if exists_storage "$id"; then
    log "PBS storage '$id' exists. Updating…"
    local cmd=(pvesm set "$id" --type pbs --server "$server" --datastore "$ds" \
               --username "$user" --password "$secret" --fingerprint "$fp" \
               --content "$content")
    [ -n "$nodes_opt" ] && cmd+=($nodes_opt)
    [ -n "$ns_opt" ]    && cmd+=($ns_opt)
    log "CMD: ${cmd[*]}"
    [ "${DRY_RUN}" = "true" ] || "${cmd[@]}"
  else
    log "Adding PBS storage '$id'…"
    local cmd=(pvesm add pbs "$id" --server "$server" --datastore "$ds" \
               --username "$user" --password "$secret" --fingerprint "$fp" \
               --content "$content")
    [ -n "$nodes_opt" ] && cmd+=($nodes_opt)
    [ -n "$ns_opt" ]    && cmd+=($ns_opt)
    log "CMD: ${cmd[*]}"
    [ "${DRY_RUN}" = "true" ] || "${cmd[@]}"
  fi

  # Невеликий sanity-check з’єднання
  if [ "${DRY_RUN}" != "true" ]; then
    log "Checking PBS connection (fingerprint & auth)…"
    pvesm status | awk 'NR==1 || $2=="pbs" {print $0}'
  fi
}

main() {
  need_root
  load_env "${1:-.env}"
  command -v pvesm >/dev/null 2>&1 || die "pvesm not found (are you on Proxmox VE?)."
  log "DRY_RUN=${DRY_RUN}"

  add_or_update_iso_nfs
  add_or_update_pbs

  log "Final storages:"
  pvesm status || true
}

main "$@"