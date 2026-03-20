#!/bin/sh
set -eu

log() {
  printf '[nextcloud-sync] %s\n' "$*"
}

SYNC_DIR="${NEXTCLOUD_SYNC_DIR:-/nextcloud}"
STATE_DIR="${NEXTCLOUD_STATE_DIR:-/nextcloud-state}"
NETRC_FILE="${NEXTCLOUD_NETRC_FILE:-$STATE_DIR/.netrc}"
SYNC_INTERVAL="${NEXTCLOUD_SYNC_INTERVAL:-300}"
TRUST_SELF_SIGNED="${NEXTCLOUD_TRUST_SELF_SIGNED:-0}"
NEXTCLOUD_URL="${NEXTCLOUD_URL:-}"
NEXTCLOUD_USER="${NEXTCLOUD_USER:-}"
NEXTCLOUD_PASSWORD="${NEXTCLOUD_PASSWORD:-}"
NEXTCLOUD_NETRC_MACHINE="${NEXTCLOUD_NETRC_MACHINE:-}"

if ! command -v nextcloudcmd >/dev/null 2>&1; then
  log "nextcloudcmd not found"
  exit 1
fi

if [ -z "$NEXTCLOUD_URL" ] || [ -z "$NEXTCLOUD_USER" ] || [ -z "$NEXTCLOUD_PASSWORD" ]; then
  log "missing NEXTCLOUD_URL, NEXTCLOUD_USER, or NEXTCLOUD_PASSWORD; sync loop not started"
  exit 0
fi

mkdir -p "$SYNC_DIR" "$STATE_DIR"

if [ -z "$NEXTCLOUD_NETRC_MACHINE" ]; then
  NEXTCLOUD_NETRC_MACHINE=$(printf '%s' "$NEXTCLOUD_URL" | sed -E 's#^[a-zA-Z]+://([^/@]+@)?([^/:]+).*#\2#')
fi

cat > "$NETRC_FILE" <<EOF
machine $NEXTCLOUD_NETRC_MACHINE
login $NEXTCLOUD_USER
password $NEXTCLOUD_PASSWORD
EOF
chmod 600 "$NETRC_FILE"

run_sync() {
  export HOME="$STATE_DIR"
  export NETRC="$NETRC_FILE"

  set -- nextcloudcmd --non-interactive --user "$NEXTCLOUD_USER" --password "$NEXTCLOUD_PASSWORD"
  if [ "$TRUST_SELF_SIGNED" = "1" ] || [ "$TRUST_SELF_SIGNED" = "true" ] || [ "$TRUST_SELF_SIGNED" = "TRUE" ]; then
    set -- "$@" --trust
  fi
  set -- "$@" "$SYNC_DIR" "$NEXTCLOUD_URL"

  "$@"
}

log "sync loop started for $NEXTCLOUD_URL -> $SYNC_DIR"
while true; do
  if run_sync; then
    log "sync completed"
  else
    log "sync failed; retrying after $SYNC_INTERVAL seconds"
  fi
  sleep "$SYNC_INTERVAL"
done
