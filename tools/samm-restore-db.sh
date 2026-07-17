#!/usr/bin/env bash
# ===========================================================================
#  SAMM — DATABASE RESTORE  (standalone recovery tool, NOT part of SAMM)
#
#  🔴 DESTRUCTIVE: replaces the ENTIRE current SAMM database with the
#  contents of a dump made by samm-backup-db.sh (pg_dump -Fc). Everything
#  written after that backup is lost. SAMM services and FreeRADIUS are
#  stopped during the restore — AAA is briefly down (established PPPoE
#  sessions on the routers survive; new logins fail until services return).
#
#  Usage:  sudo bash samm-restore-db.sh [--dry-run] [--no-safety-backup] FILE
#            --dry-run            show what would happen, change nothing
#            --no-safety-backup   skip the automatic pre-restore dump
#
#  Safety: two typed confirmations · automatic pre-restore backup ·
#  single-transaction restore (an error rolls everything back) · services
#  restarted no matter how the restore ends.
# ===========================================================================
set -uo pipefail

DRY=0
SAFETY=1
DUMP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)          DRY=1; shift ;;
    --no-safety-backup) SAFETY=0; shift ;;
    --)                 shift ;;
    -h|--help)          sed -n '2,19p' "$0"; exit 0 ;;
    -*)                 echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
    *)                  DUMP="$1"; shift ;;
  esac
done

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root (use: sudo bash $0)"
PREFIX="${PREFIX:-/opt/samm}"
[ -d "$PREFIX" ] || die "no SAMM install at $PREFIX (bare-OS installs only)"
command -v pg_restore >/dev/null || die "pg_restore not found"
[ -n "$DUMP" ] || die "no dump file given — usage: sudo bash $0 /root/samm-backups/<file>.dump"
[ -f "$DUMP" ] || die "no such file: $DUMP"
pg_restore --list "$DUMP" >/dev/null 2>&1 || die "$DUMP is not a readable pg_dump custom-format archive"

# ── locate + parse the DSN (read, never echo it) ───────────────────────────
DSN="${DATABASE_URL:-}"
if [ -z "$DSN" ]; then
  for f in ${SAMM_CONF:-} /etc/samm/samm.yaml /etc/samm/api.env "$PREFIX/.env"; do
    [ -f "$f" ] || continue
    DSN="$(grep -aoE 'postgresql://[^"'"'"'[:space:]]+' "$f" | head -1)"
    [ -n "$DSN" ] && break
  done
fi
[ -n "$DSN" ] || die "could not find the PostgreSQL DSN. Set DATABASE_URL=... and re-run."
_rest="${DSN#postgresql://}"; _creds="${_rest%%@*}"; _hostdb="${_rest#*@}"
DB_USER="${_creds%%:*}"; DB_PASS="${_creds#*:}"
DB_HOST="${_hostdb%%:*}"; _portdb="${_hostdb#*:}"
DB_PORT="${_portdb%%/*}"; DB_NAME="${_portdb#*/}"; DB_NAME="${DB_NAME%%\?*}"
export PGPASSWORD="$DB_PASS"
PSQL=(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -qtA)
"${PSQL[@]}" -c 'SELECT 1' >/dev/null 2>&1 || die "cannot connect to database '$DB_NAME' on $DB_HOST:$DB_PORT"

SERVICES=(samm-api samm-worker samm-notification samm-telegram samm-radius freeradius)

echo
bold "SAMM — database restore"
echo  "  database : $DB_NAME @ $DB_HOST:$DB_PORT"
echo  "  dump file: $DUMP ($(du -h "$DUMP" | cut -f1), $(date -r "$DUMP" '+%F %T'))"
echo  "  stops    : ${SERVICES[*]}"
[ "$SAFETY" -eq 1 ] && echo "  safety   : pre-restore backup will be taken first"
echo

if [ "$DRY" -eq 1 ]; then
    ylw "DRY RUN — nothing was changed. The steps above would be executed."
    exit 0
fi

red  "This REPLACES the entire '$DB_NAME' database. Data written after the"
red  "backup was taken is LOST. AAA is briefly down while services restart."
echo
read -r -p "Type RESTORE to continue: " a1
[ "$a1" = "RESTORE" ] || die "aborted"
read -r -p "Type the database name ($DB_NAME) to confirm: " a2
[ "$a2" = "$DB_NAME" ] || die "aborted"

if [ "$SAFETY" -eq 1 ]; then
    SAFE="/root/samm-backups/pre-restore-${DB_NAME}-$(date +%Y%m%d-%H%M%S).dump"
    mkdir -p /root/samm-backups
    bold "Taking safety backup: $SAFE"
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc -f "$SAFE" "$DB_NAME" \
        || die "safety backup failed — restore NOT started"
    pg_restore --list "$SAFE" >/dev/null 2>&1 || die "safety backup unreadable — restore NOT started"
    grn "Safety backup verified."
fi

bold "Stopping services..."
systemctl stop "${SERVICES[@]}" 2>/dev/null || true

restart_services() {
    bold "Starting services..."
    systemctl start "${SERVICES[@]}" 2>/dev/null || true
}
trap restart_services EXIT

# close any leftover connections so --clean can drop objects
"${PSQL[@]}" -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB_NAME' AND pid<>pg_backend_pid()" \
  >/dev/null 2>&1 || true

bold "Restoring (single transaction — an error rolls everything back)..."
if pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        --clean --if-exists --no-owner --single-transaction "$DUMP"; then
    grn "Restore complete."
else
    red "RESTORE FAILED — the transaction was rolled back; the previous data is intact."
    exit 1
fi

# services restart via the EXIT trap
