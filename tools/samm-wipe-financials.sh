#!/usr/bin/env bash
# ===========================================================================
#  SAMM — WIPE FINANCIAL DATA  (standalone maintenance tool, NOT part of SAMM)
#
#  Deletes every financial transaction so an ISP can restart its books from
#  zero, while leaving ALL AAA / subscriber data completely untouched.
#
#  REMOVES (transactions):
#     invoice, invoice_item          — all invoices and their line items
#     journal_entry, journal_line    — the double-entry ledger: payments,
#                                      receipts, adjustments, wallet top-ups
#                                      and withdrawals all live here, so this
#                                      is what zeroes AR / cash / wallets
#     payment_txn                    — online gateway transactions
#     expense                        — expenses
#     asset                          — fixed assets (+ their depreciation)
#     acct_activity                  — the accounting activity log
#   ...then resets the id + numbering sequences so the next invoice starts at 1.
#
#  KEEPS (configuration):
#     gl_account (chart of accounts), cash_account, capital_account,
#     payment_gateway, tax_group, accounting settings
#
#  KEEPS (everything AAA / subscriber):
#     users, plans, speed windows, limits, usage counters, plan history,
#     cards & card groups, routers, sessions, RADIUS accounting, tickets,
#     admins, audit log — none of it is touched.
#
#  Cash/wallet/AR balances are DERIVED from the ledger, so they read zero once
#  the ledger is gone — no balance column needs editing.
#
#  Usage:   sudo bash samm-wipe-financials.sh [--dry-run] [--yes]
#             --dry-run   show what would be deleted, change nothing
#             --yes       skip the interactive prompts (for automation ONLY —
#                         you are asserting a backup already exists)
# ===========================================================================
set -uo pipefail

DRY_RUN=0
ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown option: $a (try --help)" >&2; exit 2 ;;
  esac
done

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die()  { red "ERROR: $*"; exit 1; }

# ── preflight ──────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "must run as root (use: sudo bash $0)"

PREFIX="${PREFIX:-/opt/samm}"
[ -d "$PREFIX" ] || die "no SAMM install at $PREFIX"

# The DSN lives in /etc/samm/samm.yaml (db:) on a normal install; older/other
# layouts keep it in api.env. Accept an explicit DATABASE_URL override too.
# Read it without ever echoing it.
DSN="${DATABASE_URL:-}"
if [ -z "$DSN" ]; then
  for f in ${SAMM_CONF:-} /etc/samm/samm.yaml /etc/samm/api.env "$PREFIX/.env"; do
    [ -f "$f" ] || continue
    DSN="$(grep -aoE 'postgresql://[^"'"'"'[:space:]]+' "$f" | head -1)"
    [ -n "$DSN" ] && { CONF_SRC="$f"; break; }
  done
fi
[ -n "$DSN" ] || die "could not find the PostgreSQL DSN (looked in /etc/samm/samm.yaml and /etc/samm/api.env). Set DATABASE_URL=... and re-run."

# postgresql://USER:PASS@HOST:PORT/DB
_rest="${DSN#postgresql://}"
_creds="${_rest%%@*}"
_hostdb="${_rest#*@}"
DB_USER="${_creds%%:*}"
DB_PASS="${_creds#*:}"
DB_HOST="${_hostdb%%:*}"
_portdb="${_hostdb#*:}"
DB_PORT="${_portdb%%/*}"
DB_NAME="${_portdb#*/}"
DB_NAME="${DB_NAME%%\?*}"
[ -n "$DB_NAME" ] || die "could not parse the database name from DATABASE_URL"

export PGPASSWORD="$DB_PASS"
PSQL=(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -qtA)

"${PSQL[@]}" -c 'SELECT 1' >/dev/null 2>&1 || die "cannot connect to database '$DB_NAME' on $DB_HOST:$DB_PORT"

# Tables emptied, in FK-safe order (children first).
WIPE=(journal_line journal_entry invoice_item invoice payment_txn expense asset acct_activity)
# Sequences reset to 1 (ids + the human-facing numbering).
SEQS=(invoice_id_seq invoice_item_id_seq journal_entry_id_seq journal_line_id_seq
      payment_txn_id_seq expense_id_seq asset_id_seq acct_activity_id_seq
      invoice_no_seq journal_no_seq expense_no_seq)

echo
bold "SAMM — financial data wipe"
echo  "  install : $PREFIX"
echo  "  database: $DB_NAME @ $DB_HOST:$DB_PORT"
echo

# ── what is about to be deleted ────────────────────────────────────────────
bold "Financial data found (WILL BE DELETED):"
TOTAL=0
for t in "${WIPE[@]}"; do
  n="$("${PSQL[@]}" -c "SELECT count(*) FROM samm.$t" 2>/dev/null || echo 0)"
  printf '  %-16s %8s\n' "$t" "$n"
  TOTAL=$((TOTAL + n))
done
echo  "  ------------------------------"
printf '  %-16s %8s\n' "TOTAL ROWS" "$TOTAL"
echo
bold "Preserved (subscriber / AAA data — NOT touched):"
for t in user plan card card_group router session_active user_usage_daily user_plan_history ticket; do
  n="$("${PSQL[@]}" -c "SELECT count(*) FROM samm.$t" 2>/dev/null || echo '-')"
  printf '  %-20s %8s\n' "$t" "$n"
done
n="$("${PSQL[@]}" -c "SELECT count(*) FROM radius.radacct" 2>/dev/null || echo '-')"
printf '  %-20s %8s\n' "radius.radacct" "$n"
echo
bold "Preserved (accounting configuration):"
for t in gl_account cash_account capital_account payment_gateway tax_group; do
  n="$("${PSQL[@]}" -c "SELECT count(*) FROM samm.$t" 2>/dev/null || echo '-')"
  printf '  %-20s %8s\n' "$t" "$n"
done
echo

if [ "$TOTAL" -eq 0 ]; then
  grn "Nothing to do — there is no financial data in this install."
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  ylw "--dry-run: nothing was changed."
  exit 0
fi

# ── confirmations ──────────────────────────────────────────────────────────
if [ "$ASSUME_YES" -eq 0 ]; then
  red "THIS IS IRREVERSIBLE. All invoices, payments, receipts, wallet"
  red "balances and ledger history will be permanently destroyed."
  echo
  ylw "Have you taken a FULL BACKUP of the SAMM database?"
  echo  "  (e.g.  sudo -u postgres pg_dump $DB_NAME | gzip > /root/samm-backup.sql.gz )"
  echo
  read -r -p "Type YES if you have a verified backup: " ans
  [ "$ans" = "YES" ] || { red "Aborted — take a backup first."; exit 1; }

  echo
  read -r -p "Take an extra safety backup now before wiping? [Y/n]: " mkbk
  if [ "${mkbk:-Y}" != "n" ] && [ "${mkbk:-Y}" != "N" ]; then
    mkdir -p /var/backups/samm
    BK="/var/backups/samm/pre-financial-wipe-$(date +%Y%m%d-%H%M%S).sql.gz"
    echo "  dumping -> $BK"
    if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" | gzip > "$BK"; then
      grn "  backup written: $BK ($(du -h "$BK" | cut -f1))"
    else
      die "backup failed — refusing to wipe"
    fi
  fi

  echo
  read -r -p "Type WIPE to permanently delete the $TOTAL financial rows: " ans2
  [ "$ans2" = "WIPE" ] || { red "Aborted."; exit 1; }
fi

# ── quiesce the writers (RADIUS stays UP so customers stay online) ──────────
STOPPED=()
for svc in samm-api samm-worker samm-notification; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    systemctl stop "$svc" && STOPPED+=("$svc")
  fi
done
[ ${#STOPPED[@]} -gt 0 ] && echo "  paused: ${STOPPED[*]}  (samm-radius / freeradius left running — subscribers stay online)"

restore_services() {
  for svc in "${STOPPED[@]:-}"; do
    [ -n "$svc" ] && systemctl start "$svc" 2>/dev/null || true
  done
}
trap restore_services EXIT

# ── the wipe: one transaction, all-or-nothing ──────────────────────────────
echo
bold "Wiping…"
SQL="BEGIN;"
# Skip tables this SAMM version does not have (older installs predate some of
# them) — a DELETE on a missing table would abort the whole transaction.
for t in "${WIPE[@]}"; do
  SQL+=" DO \$\$ BEGIN IF to_regclass('samm.$t') IS NOT NULL THEN DELETE FROM samm.$t; END IF; END \$\$;"
done
for s in "${SEQS[@]}"; do
  # only reset sequences that exist on this version
  SQL+=" DO \$\$ BEGIN IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname='samm' AND sequencename='$s') THEN PERFORM setval('samm.$s', 1, false); END IF; END \$\$;"
done
# A stale accounting lock date would block posting into the fresh books.
SQL+=" UPDATE samm.settings SET value='' WHERE key='accounting_lock_date';"
SQL+=" COMMIT;"

if ! "${PSQL[@]}" -c "$SQL"; then
  red "Wipe FAILED — the transaction was rolled back; no data was changed."
  exit 1
fi

# ── verify ─────────────────────────────────────────────────────────────────
echo
bold "Result:"
LEFT=0
for t in "${WIPE[@]}"; do
  n="$("${PSQL[@]}" -c "SELECT count(*) FROM samm.$t" 2>/dev/null || echo 0)"
  printf '  %-16s %8s\n' "$t" "$n"
  LEFT=$((LEFT + n))
done
echo
USERS="$("${PSQL[@]}" -c 'SELECT count(*) FROM samm."user"' 2>/dev/null || echo '?')"
if [ "$LEFT" -eq 0 ]; then
  grn "Financial data wiped. Books start from zero — next invoice will be #1."
  grn "Subscribers intact: $USERS users, plans/cards/routers/sessions untouched."
else
  red "WARNING: $LEFT financial rows remain — check the output above."
  exit 1
fi

restore_services
trap - EXIT
[ ${#STOPPED[@]} -gt 0 ] && echo "  restarted: ${STOPPED[*]}"
echo
