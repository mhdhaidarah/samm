<div align="center">

<img src="s-box-logo.svg" width="96" alt="SAMM logo" />

# SAMM

### SecuryTik Active MikroTik Manager

**Full-stack ISP management platform for MikroTik PPPoE, Hotspot & IPoE/DHCP networks**

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white&style=flat-square)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-latest-009688?logo=fastapi&logoColor=white&style=flat-square)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-4169E1?logo=postgresql&logoColor=white&style=flat-square)](https://postgresql.org)
[![FreeRADIUS](https://img.shields.io/badge/FreeRADIUS-3-CC0000?style=flat-square&logoColor=white)](https://freeradius.org)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-E95420?logo=ubuntu&logoColor=white&style=flat-square)](https://ubuntu.com)

[**securytik.com**](https://securytik.com) &nbsp;·&nbsp; [Report a Bug](mailto:samm@securytik.com?subject=SAMM%20Bug%20Report) &nbsp;·&nbsp; [Request a Feature](mailto:samm@securytik.com?subject=SAMM%20Feature%20Request) &nbsp;·&nbsp; [SAMM-Docker](https://github.com/mhdhaidarah/samm-docker)

</div>

---

## Overview

SAMM is an ISP management platform built on FreeRADIUS and PostgreSQL. It handles subscriber authentication, real-time usage enforcement, and billing for MikroTik PPPoE, Hotspot, and IPoE/DHCP deployments — with a polished web portal for administrators and customers.

The stack is designed to keep logic close to the database: byte accumulation, limit evaluation, and CoA enqueueing all run inside PostgreSQL functions called directly by FreeRADIUS `unlang` on every Interim-Update — no Python round-trip on the hot path.

```
MikroTik(s) ──Auth/Acct──► FreeRADIUS ──unlang+rlm_sql──► PostgreSQL
                ▲                                               │
                │                                               ▼
                └──── CoA / Disconnect ◄──── samm-radius · samm-worker · samm-api
       ▲                                                        │
       │                                                        ▼
   WireGuard ◄────── (admin / management plane) ─────────► nginx ◄─► cloudflared ──► Internet
```

---

## Features

<table>
<tr>
<td valign="top" width="50%">

**🔐 AAA Core**
- FreeRADIUS 3 + PostgreSQL, PAP/CHAP
- PPPoE, Hotspot, and IPoE/DHCP support (IPoE authenticates each DHCP lease by Option 82 circuit-id or device MAC)
- Hybrid CoA: CoA-Update → auto-fallback to Disconnect-Request
- Dynamic NAS registration — no FreeRADIUS restart on add/remove
- Per-user static IP override

**📊 Plans & Limits**
- Speed (download/upload Mbps) + optional RADIUS Framed-Pool
- 4 independent limits per plan: `expiration`, `quota`, `uptime`, `daily`
- Each limit can throttle, switch plan, or disconnect on exhaust
- Speed windows: scheduled boosts with midnight-crossing support
- Non-resettable billing counters separate from resettable limit state

**💰 Billing & Financial Accounting**
- Double-entry accounting engine
- Invoices, expenses, resellers, assets, depreciation
- Automatic overdue-invoice detection + configurable dunning (bill → due → block)
- Tax groups, prepaid wallet with customer self-service top-up
- **Online payments**: Stripe, Binance Pay (USDT), PayPal — auto-applied to invoices
- Export to **QuickBooks / Xero / spreadsheet** (CSV + API)

**🔌 REST API & Webhooks**
- Token-based API v1: customers, plans, sessions, cards, billing, accounting, NAS
- Scoped tokens with expiry + revocation, managed from System → API
- Outbound webhooks for integration with external systems

</td>
<td valign="top" width="50%">

**🖥️ Admin Portal**
- Customer and plan management
- Live MikroTik device inventory (ping, RouterOS version, interfaces)
- Firewall backup and scheduled revert
- WiFi / cAPsMAN management
- Hotspot voucher card generation & printing
- Customer support ticket queue
- Role-based permissions (superadmin / manager / viewer, per page block)

**🌐 System (host integration)**
- **WireGuard VPN server** — manage peers, generate keys, download config / QR / MikroTik commands, all from the admin UI
- **Cloudflare Tunnel** — paste a Zero Trust connector token to publish SAMM online; start / stop / restart / rotate token from the UI, no shell needed

**👤 Customer Portal**
- Self-service: usage, plan info, invoices, support tickets, wallet top-up
- Email / Telegram / SMS / WhatsApp notifications: renewals, expiry, quota, receipts
- Admin announcements broadcast to subscribers on any channel

**🤖 Telegram Self-Service Bot**
- Verify once with SAMM username + password (password message auto-deleted)
- Check plan, quota, usage, expiration; view & download invoices as PDF
- Update profile, change password, manage support tickets — all in chat

**🌍 Multilingual & Themeable**
- 8 built-in languages: English, Arabic (RTL), Russian, Persian (RTL), Turkish, French, Spanish, German
- Live translation editor at `/admin/translations` — no restart needed
- 16 visual themes, preference saved per user account

</td>
</tr>
</table>

---

## Installation

SAMM installs everything it needs — **one script, one server, online in minutes.**

### What the installer sets up automatically

| Component | Details |
|---|---|
| **FreeRADIUS 3** | Configured with PostgreSQL backend, dynamic NAS clients |
| **PostgreSQL** | Database + schema + all migrations applied automatically |
| **Python runtime** | A standalone CPython 3.12 into `/opt/samm/runtime` (via `uv`) + a venv with all dependencies — no system-Python conflicts on any supported OS |
| **nginx** | Reverse-proxy → 8000, SAMM vhost added **additively** (existing sites untouched). Uses port 80 when free; if port 80 is occupied the installer prompts for an alternate port (or set `SAMM_HTTP_PORT`). |
| **samm-api** | FastAPI admin + customer portal (systemd unit) |
| **samm-radius** | CoA dispatcher + expiration/quota enforcement (systemd unit) |
| **samm-worker** | MikroTik API sync + ping monitor (systemd unit) |
| **samm-notification** | Email / Telegram / SMS / WhatsApp notification delivery worker (systemd unit) |
| **samm-telegram** | Interactive Telegram self-service bot (systemd unit) |
| **WireGuard** | `wireguard` + `wireguard-tools` packages; `/etc/wireguard` group-writable by `samm`; sudoers entry for `wg` / `wg-quick`. Configure peers from System → VPN. |
| **cloudflared** | Binary always installed (Cloudflare apt repo) + sudoers entry; tunnel **token** optional at install — paste at the prompt, set `CF_TOKEN=…` env var, or configure later via System → Cloudflare Tunnel. |

All credentials (DB password, session signing keys) are **auto-generated** on first install.

### Prerequisites

- Ubuntu 22.04 / 24.04 / 26.04 or Debian 12 / 13
- Root / sudo access

### Step 1 — Run the installer (one line)

```bash
curl -fsSL https://samm.securytik.com/install.sh | sudo bash
```

That's the whole install: it downloads the latest SAMM release, extracts it to
`/opt/samm`, and runs the bundled installer (FreeRADIUS + PostgreSQL + nginx +
all SAMM services).

<details>
<summary>Alternative — install from a downloaded release bundle (offline / air-gapped)</summary>

```bash
tar -xzf samm-<version>.tar.gz -C /tmp
sudo bash /tmp/samm-<version>/install.sh        # the installer rsyncs itself into /opt/samm
```

Release bundles: <https://github.com/mhdhaidarah/samm/releases>
</details>

### Step 2 — Watch it finish

```bash
# re-running the installer later is always safe:
sudo bash /opt/samm/install.sh
```

The installer is **idempotent** — safe to re-run for upgrades. It shows a live colored progress display (a percentage bar + a per-phase checklist); raw command output is captured in `/var/log/samm-install.log`. Run with `SAMM_VERBOSE=1` to stream that output instead of the bar.

Any prompts happen **up front**, before installation begins:

```
Cloudflare Zero Trust — paste a connector token to publish SAMM online
without opening firewall ports.  Get it at:
  https://one.dash.cloudflare.com  ->  Networks  ->  Tunnels
Press Enter to skip (configure later from Admin -> System -> Cloudflare Tunnel).
Token: █
```

If **port 80 is already in use** by another web server, the installer leaves those sites untouched and asks for an alternate port for SAMM (default `8080`); pass `SAMM_HTTP_PORT=<port>` to choose non-interactively.

Paste your connector token and press Enter. SAMM will be live on your Cloudflare domain immediately — no DNS changes, no open ports, no SSL configuration needed.

To skip and add it later, just press Enter. You then have two options to configure the tunnel without touching the shell again:

1. **From the UI** *(recommended)*: open **Admin → System → Cloudflare Tunnel**, paste your token, click Configure. Start / stop / restart / replace token / uninstall are all one click away. Same page for token rotation later.
2. From the shell: re-run `CF_TOKEN='your-token' sudo bash /opt/samm/install.sh`.

### Step 3 — First login

When the installer finishes it prints a summary:

```
============================================================
  SAMM is installed and running.  (94s)
  Admin portal  : http://localhost/admin/login
  Default login : admin / admin   <- CHANGE AFTER FIRST LOGIN
  HTTP port     : 80
  DB user / pass: samm / <auto-generated>
  Config files  : /etc/samm/samm.yaml  /etc/samm/api.env
  Cloudflare ZT : tunnel configured — check status in the Cloudflare dashboard
  WireGuard VPN : configure at Admin -> System -> VPN
  Email OTP     : set SMTP_* in /etc/samm/api.env to enable
  Install log   : /var/log/samm-install.log
============================================================
```

Open the admin portal via your Cloudflare tunnel URL or `http://server-ip/admin/login` (use the `HTTP port` shown above if it is not `80`).  
Log in with **admin / admin** and change your password immediately.

### Step 4 — Add your first router

Go to **Admin → NAS / Routers → Add**. Fill in the router's IP, RADIUS shared secret, and optionally MikroTik API credentials for live device sync. No FreeRADIUS restart needed — NAS records are resolved dynamically from the database.

### Step 5 — Point your MikroTik at SAMM

On the MikroTik, configure:
- **RADIUS server**: your server IP, port 1812/1813, the shared secret you entered in step 4
- **PPPoE / Hotspot / IPoE**: set RADIUS authentication enabled, Interim-Update interval 60 s. For IPoE, the DHCP server's `radius-password` is simply that router's RADIUS shared secret — nothing extra to configure.

That's it. SAMM handles everything else.

### Step 6 — *(optional)* Stand up a WireGuard VPN for management access

If your MikroTiks live behind NAT or on a separate management network, run a WireGuard server on the SAMM host:

1. **Admin → System → VPN → Server tab**
2. Click **Generate Keys**, set the listen port (default 51820) and tunnel address (default `10.254.254.1/24`), tick **Enable**, click **Save**
3. **Clients tab → Add Client** — name the peer, then download its config file, scan the QR with the WireGuard mobile app, or copy the MikroTik RouterOS terminal commands directly to any router

`wg0` is brought up by `wg-quick`; SAMM rewrites `/etc/wireguard/wg0.conf` and reloads the interface in-band for every change.

---

## Upgrading

**From the panel (recommended):** open **System → Updates** and click *Apply
update*. SAMM downloads the signed release, verifies its signature, backs up the
current install, applies migrations, and restarts services — with a live
progress display. A daily timer can also apply updates automatically.

**From the shell (equivalent):** re-run the installer with the latest release:

```bash
curl -fsSL https://samm.securytik.com/install.sh | sudo bash
```

Either path re-applies all SQL migrations (every file is idempotent), reloads FreeRADIUS and nginx configs, and restarts all services. Your config files (`/etc/samm/samm.yaml`, `/etc/samm/api.env`, `/etc/samm/secret.key`), the Python runtime, and the WhatsApp bridge's linked session are **never touched** by upgrades, and the HTTP port chosen at first install is preserved.

**On Docker,** upgrades ship as new container images — pull the new tag and recreate the stack via the [`samm-docker`](https://github.com/mhdhaidarah/samm-docker) compose bundle; the in-app **System → Updates** page is intentionally hidden on container installs (it would have nothing to apply).

---

## High Availability

For a no-single-point-of-failure deployment — PostgreSQL streaming replication (primary + hot standby), a standby AAA node, and a tested promote/repoint failover procedure — see **[the HA runbook](https://samm.securytik.com/docs#doc-ha)** (also ships as `docs/HA.md` in every install).

---

## IPv6 dual-stack

Every subscriber can get IPv6 alongside IPv4. Turn it on in the **router wizard** (an optional, off-by-default step — Auto-Complete never touches it) where you supply a single **IPv6 block** and the IPv6 DNS resolvers (defaults to Google IPv6 DNS); the wizard creates one MikroTik `/ipv6` pool, enables IPv6 forwarding (`/ipv6 settings forward=yes`), sets the PPP profile's `remote-ipv6-prefix-pool` so every subscriber gets a **/64 on their link**, and enables router-advertisement DNS — so the client SLAACs a global IPv6 address and learns the resolvers over RA (RDNSS). Per-subscriber **static** overrides (`framed_ipv6_prefix` / `delegated_ipv6_prefix`, also on the API) pin a fixed prefix for business customers — SAMM's RADIUS reply then carries the matching `Framed-IPv6-Prefix` / `Delegated-IPv6-Prefix` — and the prefix shows in **Live Sessions**. Works for PPPoE, Hotspot and IPoE.

---

## Accounting export

The double-entry books export to **QuickBooks / Xero / spreadsheet** as CSV (General Journal, Chart of Accounts, Invoices, Trial Balance, P&L, Balance Sheet) from **Accounting → Reports → Export to accounting software**, and over the API at `GET /api/v1/accounting/export/{kind}` (`format=json|csv`, scope `billing:read`). Exports exclude voided entries, so they always reconcile with the on-screen reports.

---

## WhatsApp notifications

Two ways to send subscriber notifications over WhatsApp, chosen per install under **Notifications → Channels → WhatsApp**:

- **Meta WhatsApp Cloud API** *(official, recommended)* — a permanent access token + Phone-Number-ID from Meta for Developers; template or free-form messages. Reliable 1–3 s delivery, works on bare-OS and Docker with no extra service.
- **Unofficial QR link** *(at your own risk)* — links a normal WhatsApp number by QR (like WhatsApp Web) via a small local **bridge**. On **bare-OS** the panel's one-click *Set up bridge* installs it as the `samm-wa-bridge` service; on **Docker and MikroTik RouterOS** it's already part of the stack — the self-contained multi-arch image `mhdhaidarah/samm:wa-bridge-<ver>` — so you just pick the QR provider and scan (it idles until then). It violates WhatsApp's Terms of Service and the number can be banned; the Cloud API above is the supported path.

---

## Configuration

### `/etc/samm/samm.yaml`

Shared by all Python services. Holds the canonical DB DSN — never duplicate it elsewhere.

```yaml
db:
  dsn: "postgresql://samm:<password>@127.0.0.1:5432/samm"
  min_size: 2
  max_size: 10

log:
  level: INFO   # DEBUG / INFO / WARNING / ERROR

secret_key_file: "/etc/samm/secret.key"
```

### `/etc/samm/api.env`

Loaded by `samm-api` via systemd `EnvironmentFile=`. **Preserve this file across upgrades** — rotating the cookie secrets invalidates all active sessions.

```bash
DISPLAY_TIMEZONE=UTC          # portal display timezone (e.g. Asia/Beirut)
ADMIN_SECRET=<random>         # admin session cookie signing key — keep stable
CUSTOMER_SECRET=<random>      # customer session cookie signing key — keep stable

# Email (OTP password recovery) — leave blank to disable
SMTP_HOST=
SMTP_PORT=465
SMTP_USE_SSL=1
SMTP_USERNAME=
SMTP_FROM=SAMM <noreply@example.com>
SMTP_PASSWORD=
```

`samm-api` refuses to start if `ADMIN_SECRET` or `CUSTOMER_SECRET` is missing or still set to a placeholder value.

### Live tunables — `samm.settings` table

Updated at runtime with no restart required:

```sql
UPDATE samm.settings SET value = '15' WHERE key = 'samm_radius_interval_seconds';
```

| Key | Default | Description |
|---|---|---|
| `samm_radius_interval_seconds` | `30` | samm-radius loop cadence |
| `samm_worker_interval` | `60` | Router ping + API sync cadence |
| `acct_interim_interval_seconds` | `60` | Acct-Interim-Interval pushed to routers |
| `daily_reset_time` | `00:00` | Time of daily counter rollover |
| `server_timezone` | `UTC` | Timezone for windows + daily reset |
| `coa_default_port` | `3799` | Default CoA UDP port |
| `coa_retry_max` | `3` | CoA retries before Disconnect-Request fallback |
| `telegram_bot_enabled` | `true` | Master switch for the Telegram self-service bot |

---

## Service Management

```bash
# Status overview
systemctl status freeradius nginx cloudflared samm-api samm-radius samm-worker samm-notification samm-telegram

# Restart all SAMM services
systemctl restart samm-api samm-radius samm-worker samm-notification samm-telegram

# Live logs
journalctl -u samm-api          -f
journalctl -u samm-radius       -f
journalctl -u samm-worker       -f
journalctl -u samm-notification -f
journalctl -u samm-telegram     -f

# Validate FreeRADIUS config after any change under freeradius/
freeradius -CX

# Run a daemon in the foreground for debugging
sudo -u samm SAMM_CONFIG=/etc/samm/samm.yaml /opt/samm/venv/bin/python -m samm_radius.main
sudo -u samm SAMM_CONFIG=/etc/samm/samm.yaml /opt/samm/venv/bin/python -m samm_worker.main
sudo -u samm SAMM_CONFIG=/etc/samm/samm.yaml /opt/samm/venv/bin/python -m samm_telegram.main

# Port 8000 stuck after a crash
kill -9 $(lsof -ti:8000) && systemctl restart samm-api
```

---

## Admin CLI

The CLI inserts rows into `samm.audit_log`. `samm-radius` applies them on its next tick and sends a live CoA refresh if the subscriber is currently online.

```bash
CLI="sudo -u samm /opt/samm/venv/bin/python -m samm_radius.cli"

$CLI reset-quota       alice      # reset quota counter
$CLI reset-daily       alice      # reset daily counter
$CLI reset-uptime      alice      # reset uptime counter
$CLI reset-expiration  alice      # reset expiration counter

$CLI change-plan alice home-50M   # switch plan (takes effect within one tick)

$CLI encrypt-pw                   # encrypt a MikroTik API password for the DB
```

## Maintenance tools

Standalone recovery / maintenance scripts live in [`tools/`](tools/). They are **not** part of the running product — **download, read, then run** as root on the SAMM server. Never pipe them straight into a shell.

**Reset a locked-out admin password** — set a new password for a superadmin straight in the database (also re-enables the account if it was disabled):

```bash
curl -fsSL -o samm-reset-admin-password.sh \
  https://raw.githubusercontent.com/mhdhaidarah/samm/main/tools/samm-reset-admin-password.sh

sudo bash samm-reset-admin-password.sh --list        # list the superadmin accounts
sudo bash samm-reset-admin-password.sh               # reset (prompts for the new password, twice)
sudo bash samm-reset-admin-password.sh --user alice  # pick a specific superadmin
```

**Wipe financial data** — reset the books to zero (invoices, ledger, payments, expenses, assets) while leaving every subscriber / AAA record untouched:

```bash
curl -fsSL -o samm-wipe-financials.sh \
  https://raw.githubusercontent.com/mhdhaidarah/samm/main/tools/samm-wipe-financials.sh

sudo bash samm-wipe-financials.sh --dry-run          # show what would be deleted, change nothing
sudo bash samm-wipe-financials.sh                    # do it
```

---

## Architecture

**FreeRADIUS** (`unlang` + `rlm_sql`) handles every Auth and Acct packet. On each Interim-Update it calls two PostgreSQL functions directly:

- `samm.apply_interim(acctuniqueid, in_bytes, out_bytes, session_secs)` — accumulates usage into `user_limit_state`, `user_usage_totals`, `user_usage_daily`
- `samm.evaluate_user_limits(user_id)` — first-exhausted-wins evaluation (`expiration → quota → daily → uptime`); inserts a `coa_outbox` row when a limit fires

**samm-radius** drains `samm.coa_outbox` via pyrad (CoA-Update → Disconnect-Request on NACK), runs the expiration sweep, daily reset, speed-window edge detection, and applies admin commands from `samm.audit_log`.

**samm-worker** pings every router and — for routers with API credentials — syncs identity, model, RouterOS version, and interface statistics from the MikroTik API.

**samm-api** is read/write for the web portals but **never sends CoAs directly**. Admin actions are written to `samm.audit_log` and applied by samm-radius within one tick.

**samm-notification** delivers customer notifications (renewal reminder, expiry, quota, payment receipt, plan renewed, broadcast) over Email, Telegram, SMS and WhatsApp through one throttled `samm.notif_outbox` queue — it only ever *sends*.

**samm-telegram** runs the interactive Telegram self-service bot. A customer verifies once with their SAMM username and password, then checks plan / quota / usage / expiration, updates profile details, changes their password, views invoices and manages support tickets — entirely from Telegram. It is the sole `getUpdates` poller for the bot token; conversation state lives in `samm.tg_bot_session`.

---

## Plans and Limits

Plans define speed (download/upload Mbps), an optional RADIUS Framed-Pool, and up to four independent limit types:

| Limit | Tracks | On exhaust |
|---|---|---|
| `expiration` | Days since activation or assignment | `throttle`, `next_plan`, or `disconnect` |
| `quota` | Total bytes (configurable: both / download / upload) | same |
| `daily` | Bytes since last daily reset | same |
| `uptime` | Cumulative session seconds | same |

Each limit resets independently. `samm.user_limit_state` holds resettable counters; `samm.user_usage_totals` and `samm.user_usage_daily` hold permanent billing counters that are never zeroed.

**Speed windows** override the plan's base speed for specific days and clock ranges (highest-speed match wins). Throttled or exhausted users are excluded — the system never lifts speed while a limit is in force.

---

## RADIUS Smoke Test

```bash
# 1. Authenticate
radtest alice alicepw 127.0.0.1 0 testing123

# 2. Acct-Start
echo 'Acct-Status-Type = Start
Acct-Session-Id = "s-1"
User-Name = "alice"
NAS-IP-Address = 127.0.0.1
Framed-IP-Address = 10.0.0.55' | radclient -x 127.0.0.1:1813 acct testing123

# 3. Interim-Update (triggers limit evaluation inside PostgreSQL)
echo 'Acct-Status-Type = Interim-Update
Acct-Session-Id = "s-1"
User-Name = "alice"
NAS-IP-Address = 127.0.0.1
Acct-Input-Octets = 800000
Acct-Output-Octets = 400000
Acct-Session-Time = 30' | radclient -x 127.0.0.1:1813 acct testing123

# 4. Inspect DB state
psql -h 127.0.0.1 -U samm -d samm -c "TABLE samm.user_limit_state;"
psql -h 127.0.0.1 -U samm -d samm -c "TABLE samm.coa_outbox;"
psql -h 127.0.0.1 -U samm -d samm -c "TABLE samm.user_usage_daily;"
```

---

## Notes

- **Cleartext passwords** are required for PAP/CHAP. EAP is explicitly disabled by the installer.
- **No SSL on the server** — SAMM runs on port 80 behind Cloudflare Zero Trust. TLS is terminated at the Cloudflare edge; the tunnel between cloudflared and the SAMM server is encrypted by the connector.
- **CoA timing**: time-driven events (expiration, speed windows, daily reset) fire within `samm_radius_interval_seconds` (default 30 s). Lower this in `samm.settings` for tighter enforcement.
- **Remote PostgreSQL**: the installer assumes a local PG instance. For a remote DB, update `pg_hba.conf` on the DB server and set the DSN in `/etc/samm/samm.yaml` manually after install.
- **Legacy migration**: only `sql/0006_legacy_extensions.sql`, `sql/0007_invoices.sql`, `sql/legacy_to_samm.sql` and `sql/cleanup_public.sql` are migration-only scripts the installer skips — apply them by hand only when migrating from a pre-SAMM `public.*` schema. Every other numbered `sql/` file is applied automatically on a fresh install.
- **Regenerating WireGuard server keys is destructive**: every deployed client config still has the OLD server pubkey baked into its `[Peer]` block. After regeneration, you must re-hand-out the updated config (Clients tab → Config / QR) to every device. The UI gates this with a "type REGENERATE to confirm" dialog.
- **Cloudflare token storage**: the token is never persisted in SAMM's database. `cloudflared service install` embeds it in the unit file's `ExecStart` line under `/etc/systemd/system/cloudflared.service`. Removing the tunnel from the UI deletes that unit file entirely.
- **Source provenance** — SAMM ships SAMM. Everything else (FreeRADIUS, PostgreSQL, nginx, Python, WireGuard, cloudflared) is fetched at install time from upstream apt repos. Air-gapped installs need to pre-stage those packages.

---

<div align="center">

Built by [SecuryTik](https://securytik.com)

</div>
