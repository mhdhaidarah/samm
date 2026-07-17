#!/usr/bin/env bash
# ===========================================================================
#  SAMM — HEALTH CHECK  (standalone diagnostic tool, NOT part of SAMM)
#
#  Read-only. Checks a bare-OS SAMM install end to end and prints a report:
#  services, database, RADIUS ports, admin portal, disk, memory and recent
#  service errors. Changes NOTHING.
#
#  Usage:  sudo bash samm-health-check.sh
#  Exit code: 0 = all OK (warnings allowed), 1 = at least one FAIL.
# ===========================================================================
set -uo pipefail

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

FAILS=0
WARNS=0
ok()   { printf '  \033[32m OK \033[0m %s\n' "$*"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$*"; WARNS=$((WARNS+1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAILS=$((FAILS+1)); }

[ "$(id -u)" -eq 0 ] || die "must run as root (use: sudo bash $0)"
PREFIX="${PREFIX:-/opt/samm}"
[ -d "$PREFIX" ] || die "no SAMM install at $PREFIX (bare-OS installs only)"

VER="$(cd "$PREFIX" 2>/dev/null && ./venv/bin/python -c 'from app.version import SAMM_VERSION; print(SAMM_VERSION)' 2>/dev/null)"
echo
bold "SAMM health check — ${VER:+v$VER, }$(hostname), $(date '+%F %T')"
echo

# ── services ───────────────────────────────────────────────────────────────
bold "Services"
for u in samm-api samm-radius samm-worker samm-notification samm-telegram \
         freeradius postgresql nginx; do
    if systemctl is-active --quiet "$u" 2>/dev/null; then
        ok "$u active"
    else
        # postgresql may be a template unit alias that reports inactive
        if [ "$u" = postgresql ] && systemctl list-units 'postgresql*' --state=active --no-legend 2>/dev/null | grep -q .; then
            ok "postgresql active (template unit)"
        else
            fail "$u NOT active"
        fi
    fi
done
for t in samm-license-enforcer.timer samm-updater.timer; do
    systemctl is-active --quiet "$t" 2>/dev/null && ok "$t active" || warn "$t not active"
done

# ── database ───────────────────────────────────────────────────────────────
bold "Database"
DSN="${DATABASE_URL:-}"
if [ -z "$DSN" ]; then
  for f in ${SAMM_CONF:-} /etc/samm/samm.yaml /etc/samm/api.env "$PREFIX/.env"; do
    [ -f "$f" ] || continue
    DSN="$(grep -aoE 'postgresql://[^"'"'"'[:space:]]+' "$f" | head -1)"
    [ -n "$DSN" ] && break
  done
fi
if [ -z "$DSN" ]; then
    fail "could not find the PostgreSQL DSN (/etc/samm/samm.yaml)"
else
    _rest="${DSN#postgresql://}"; _creds="${_rest%%@*}"; _hostdb="${_rest#*@}"
    DB_USER="${_creds%%:*}"; DB_PASS="${_creds#*:}"
    DB_HOST="${_hostdb%%:*}"; _portdb="${_hostdb#*:}"
    DB_PORT="${_portdb%%/*}"; DB_NAME="${_portdb#*/}"; DB_NAME="${DB_NAME%%\?*}"
    export PGPASSWORD="$DB_PASS"
    PSQL=(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -qtA)
    if "${PSQL[@]}" -c 'SELECT 1' >/dev/null 2>&1; then
        ok "connect to $DB_NAME @ $DB_HOST:$DB_PORT"
        subs="$("${PSQL[@]}" -c 'SELECT count(*) FROM samm."user"' 2>/dev/null)" \
            && ok "subscribers: $subs" || warn "could not count subscribers"
        nas="$("${PSQL[@]}" -c 'SELECT count(*) FROM samm.router' 2>/dev/null)" \
            && ok "routers: $nas" || warn "could not count routers"
        dbsize="$("${PSQL[@]}" -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'))" 2>/dev/null)" \
            && ok "database size: $dbsize"
    else
        fail "cannot connect to database"
    fi
fi

# ── network surfaces ───────────────────────────────────────────────────────
bold "Network"
ss -lun 2>/dev/null | grep -qE ':1812\b' && ok "RADIUS auth 1812/udp listening" || fail "RADIUS 1812/udp NOT listening"
ss -lun 2>/dev/null | grep -qE ':1813\b' && ok "RADIUS acct 1813/udp listening" || fail "RADIUS 1813/udp NOT listening"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1/admin/login 2>/dev/null)
if [ "$code" = 200 ]; then ok "admin portal answers 200"; else
    # non-80 port installs
    port=$(grep -rhoE 'listen [0-9]+' /etc/nginx/sites-enabled/ 2>/dev/null | awk '{print $2}' | head -1)
    code2=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://127.0.0.1:${port:-80}/admin/login" 2>/dev/null)
    [ "$code2" = 200 ] && ok "admin portal answers 200 (port ${port})" || fail "admin portal HTTP ${code2:-unreachable}"
fi

# ── host resources ─────────────────────────────────────────────────────────
bold "Host"
duse=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
if   [ "$duse" -ge 95 ]; then fail "root filesystem ${duse}% full"
elif [ "$duse" -ge 85 ]; then warn "root filesystem ${duse}% full"
else ok "root filesystem ${duse}% used"; fi
memavail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
if [ "$memavail" -lt 200 ]; then warn "only ${memavail} MB RAM available"; else ok "${memavail} MB RAM available"; fi

# ── recent errors ──────────────────────────────────────────────────────────
bold "Recent errors (last hour)"
for u in samm-api samm-radius samm-worker; do
    n=$(journalctl -u "$u" --since '-1 hour' -p err --no-pager -q 2>/dev/null | wc -l)
    if [ "$n" -gt 0 ]; then warn "$u: $n error line(s) — journalctl -u $u -p err"; else ok "$u: no errors"; fi
done

echo
if [ "$FAILS" -gt 0 ]; then red "RESULT: $FAILS FAIL, $WARNS warning(s)"; exit 1
elif [ "$WARNS" -gt 0 ]; then ylw "RESULT: healthy with $WARNS warning(s)"; else grn "RESULT: healthy"; fi
exit 0
