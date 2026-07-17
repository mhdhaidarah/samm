#!/usr/bin/env bash
# ===========================================================================
#  SAMM — DATABASE BACKUP  (standalone tool, NOT part of SAMM)
#
#  Takes a verified PostgreSQL dump of the SAMM database while everything
#  keeps running (pg_dump is online — no downtime, subscribers stay up).
#  Read-only apart from writing the dump file.
#
#  Usage:  sudo bash samm-backup-db.sh [--output FILE]
#            --output FILE   where to write (default:
#                            /root/samm-backups/samm-<db>-<timestamp>.dump)
#
#  The dump is PostgreSQL custom format (-Fc, compressed) — restore it with
#  the samm-restore-db.sh tool, or manually with pg_restore.
# ===========================================================================
set -uo pipefail

OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output)   OUT="${2:-}"; shift 2 2>/dev/null || shift ;;
    --output=*) OUT="${1#--output=}"; shift ;;
    -h|--help)  sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root (use: sudo bash $0)"
PREFIX="${PREFIX:-/opt/samm}"
[ -d "$PREFIX" ] || die "no SAMM install at $PREFIX (bare-OS installs only)"
command -v pg_dump >/dev/null || die "pg_dump not found"

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

if [ -z "$OUT" ]; then
    mkdir -p /root/samm-backups
    OUT="/root/samm-backups/samm-${DB_NAME}-$(date +%Y%m%d-%H%M%S).dump"
fi

echo
bold "SAMM — database backup"
echo  "  database: $DB_NAME @ $DB_HOST:$DB_PORT"
echo  "  output  : $OUT"
echo

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -Fc -f "$OUT" "$DB_NAME" \
    || die "pg_dump failed"

# verify the dump is a readable archive before calling it a backup
pg_restore --list "$OUT" >/dev/null 2>&1 || die "dump verification failed — do NOT trust $OUT"

grn "Backup complete and verified: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Restore later with:  sudo samm-tools samm-restore-db -- \"$OUT\""
echo "                or:  sudo bash samm-restore-db.sh \"$OUT\""
