# SAMM maintenance tools

Standalone, **root-only** scripts for maintenance jobs that are too destructive to
live inside the admin panel.

Anything that can wipe a live ISP's business in one click does **not** belong
behind a button. These tools are kept **outside the product on purpose**: you have
to find them, download them, read them, and run them deliberately from a shell.
They are not installed by SAMM, they are not shipped in the tarball or the
container image, and no update will ever place them on your server.

> ⚠️ **Every script here is destructive and irreversible.**
> Your only way back is a database backup. Take one, and verify it, before you run
> anything in this directory.

**These tools target bare-OS (Linux) installs.** They expect `/opt/samm`,
`/etc/samm/` and systemd on the host. On a Docker install they will refuse to run
(`no SAMM install at /opt/samm`) rather than do anything half-way.

---

## Available tools

| Script | What it does | Risk |
|---|---|---|
| [`samm-wipe-financials.sh`](samm-wipe-financials.sh) | Resets the books to zero — deletes all invoices, payments, receipts, wallet balances and ledger history. **Keeps every subscriber / AAA record.** | 🔴 **Irreversible data loss** |

---

## 🔴 `samm-wipe-financials.sh` — reset the books

Clears every financial transaction so an ISP can start its accounting from zero,
while leaving **all subscriber and AAA data completely intact**.

Useful when taking over an existing install, or after a trial / testing period,
when the books are full of data the operator wants gone but the customer base
must stay exactly as it is.

### 🔴 DANGER — irreversible data loss

**This permanently destroys all invoices, payments, receipts, wallet balances and
ledger history. There is no undo.** The only way back is a database backup. Never
run it on a production install you have not backed up **and verified** first.

### What it removes

- `invoice`, `invoice_item` — all invoices and their line items
- `journal_entry`, `journal_line` — the double-entry ledger: payments, receipts,
  adjustments, wallet top-ups and withdrawals all live here
- `payment_txn` — online payment-gateway transactions
- `expense`, `asset`, `acct_activity` — expenses, fixed assets, accounting activity log

Invoice numbering is reset, so the **next invoice starts at #1**.

### What it keeps

- **Everything AAA / subscriber:** users, plans, speed windows, limits, usage
  counters, plan history, hotspot cards, routers, sessions, RADIUS accounting,
  tickets, admins, audit log.
- **Accounting configuration:** chart of accounts, cash accounts, capital
  accounts, tax groups, payment gateways.

Cash, wallet and receivable balances are *derived* from the ledger, so they simply
read zero once it is gone — no balance is edited.

### Usage

Download it, read it, then run it. **Always do a dry run first.**

```bash
curl -fsSL -o samm-wipe-financials.sh \
  https://raw.githubusercontent.com/mhdhaidarah/samm/main/tools/samm-wipe-financials.sh

sudo bash samm-wipe-financials.sh --dry-run   # show what would be deleted, change nothing
sudo bash samm-wipe-financials.sh             # do it
```

> **Do not pipe this into a shell.** Never run it as `curl … | sudo bash`. For a
> script that destroys data you want to read it first, and a truncated download
> must not be able to execute half a wipe.

| Flag | Meaning |
|---|---|
| `--dry-run` | Print exactly what would be deleted; change nothing. |
| `--yes` | Skip the interactive prompts (automation only — you are asserting a backup exists). |

### Safety behaviour

- **Root-only**, and refuses to run if it cannot find a real SAMM install.
- Prints a full **before/after inventory** of what will be deleted and what will
  be preserved.
- Requires **two typed confirmations**: `YES` (you hold a verified backup), then
  `WIPE`.
- **Offers to take its own `pg_dump` backup** into `/var/backups/samm/` and
  **aborts if that dump fails**.
- Runs as a **single all-or-nothing transaction** — any error rolls everything
  back and nothing changes.
- Pauses `samm-api` / `samm-worker` / `samm-notification` to stop concurrent
  writes, but **deliberately leaves `samm-radius` and `freeradius` running, so
  your subscribers stay online** while the books are cleared. Services are
  restarted automatically, even if you abort.
- Works across SAMM versions — tables a given install does not have are skipped
  rather than aborting the wipe.

---

## Adding future tools

Any new maintenance job that is destructive, irreversible, or capable of taking a
live ISP offline belongs **here**, not in the admin panel. The bar for a script in
this directory:

1. **Root-only**, and it verifies it is running against a real SAMM install.
2. **Shows what it will do before it does it**, and supports `--dry-run`.
3. **Requires explicit typed confirmation**, including that a backup exists.
4. **All-or-nothing** — wrap the change in a transaction where possible.
5. **Keeps subscribers online** if it can (don't stop RADIUS unless you must).
6. **Documented in this README** with an honest danger notice.
