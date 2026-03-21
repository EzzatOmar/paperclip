#!/bin/sh
set -eu

log() {
  printf '[entrypoint] %s\n' "$*"
}

PAPERCLIP_HOME_DIR="${PAPERCLIP_HOME:-/paperclip}"
NEXTCLOUD_SYNC_DIR="${NEXTCLOUD_SYNC_DIR:-/nextcloud}"
NEXTCLOUD_STATE_DIR="${NEXTCLOUD_STATE_DIR:-/nextcloud-state}"
CHROME_USER_DATA_DIR="${CHROME_USER_DATA_DIR:-/chrome-data}"

mkdir -p "$PAPERCLIP_HOME_DIR" "$NEXTCLOUD_SYNC_DIR" "$NEXTCLOUD_STATE_DIR" "$CHROME_USER_DATA_DIR"

NEXTCLOUD_ENABLED="${NEXTCLOUD_ENABLED:-}"
if [ -z "$NEXTCLOUD_ENABLED" ]; then
  if [ -n "${NEXTCLOUD_URL:-}" ] && [ -n "${NEXTCLOUD_USER:-}" ] && [ -n "${NEXTCLOUD_PASSWORD:-}" ]; then
    NEXTCLOUD_ENABLED="true"
  else
    NEXTCLOUD_ENABLED="false"
  fi
fi

case "$NEXTCLOUD_ENABLED" in
  1|true|TRUE|yes|YES|on|ON)
    if command -v nextcloudcmd >/dev/null 2>&1; then
      log "starting Nextcloud sync loop"
      /app/docker/nextcloud-sync-loop.sh &
    else
      log "Nextcloud sync requested but nextcloudcmd is not installed"
    fi
    ;;
  *)
    log "Nextcloud sync disabled"
    ;;
esac

exec "$@"
