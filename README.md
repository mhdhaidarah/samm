<div align="center">

<img src="s-box-logo.svg" width="96" alt="SAMM logo" />

# SAMM

### SecuryTik Active MikroTik Manager

**Full-stack ISP management platform for MikroTik PPPoE & Hotspot networks**

[![Release](https://img.shields.io/github/v/release/mhdhaidarah/samm?style=flat-square&color=3b82f6&label=latest%20release)](https://github.com/mhdhaidarah/samm/releases/latest)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white&style=flat-square)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-latest-009688?logo=fastapi&logoColor=white&style=flat-square)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-4169E1?logo=postgresql&logoColor=white&style=flat-square)](https://postgresql.org)
[![FreeRADIUS](https://img.shields.io/badge/FreeRADIUS-3-CC0000?style=flat-square&logoColor=white)](https://freeradius.org)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-E95420?logo=ubuntu&logoColor=white&style=flat-square)](https://ubuntu.com)
[![A SecuryTik product](https://img.shields.io/badge/a-SecuryTik%20product-22d3ee?style=flat-square)](https://securytik.com)

[**samm.securytik.com**](https://samm.securytik.com) &nbsp;·&nbsp; [Documentation](https://samm.securytik.com/docs) &nbsp;·&nbsp; [Report a Bug](mailto:samm@securytik.com?subject=SAMM%20Bug%20Report) &nbsp;·&nbsp; [Request a Feature](mailto:samm@securytik.com?subject=SAMM%20Feature%20Request)

</div>

---

## Overview

SAMM is an ISP management platform built on FreeRADIUS and PostgreSQL. It handles subscriber authentication, real-time usage enforcement, and billing for MikroTik PPPoE and Hotspot deployments — with a polished web portal for administrators and customers.

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

This is the **public distribution repository**. The shipped product is a compiled bundle published on the [**Releases**](https://github.com/mhdhaidarah/samm/releases) page; the full source is maintained privately by [SecuryTik](https://securytik.com).

---

## Features

<table>
<tr>
<td valign="top" width="50%">

**🔐 AAA Core**
- FreeRADIUS 3 + PostgreSQL, PAP/CHAP
- PPPoE and Hotspot support
- Hybrid CoA: CoA-Update → auto-fallback to Disconnect-Request
- Dynamic NAS registration — no FreeRADIUS restart on add/remove
- Per-user static IP override

**📊 Plans & Limits**
- Speed (download/upload Mbps) + optional RADIUS Framed-Pool
- 4 independent limits per plan: `expiration`, `quota`, `uptime`, `daily`
- Each limit can throttle, switch plan, or disconnect on exhaust
- Speed windows: scheduled boosts with midnight-crossing support
- Non-resettable billing counters separate from resettable limit state

**💰 Financial Accounting**
- Double-entry accounting engine
- Invoices, expenses, resellers, assets, depreciation
- Automatic overdue-invoice detection

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
- Self-service: usage, plan info, invoices, support tickets
- Email / Telegram notifications: renewals, expiry, quota, receipts

**🤖 Telegram Self-Service Bot**
- Verify once with SAMM username + password (password message auto-deleted)
- Check plan, quota, usage, expiration; view & download invoices as PDF
- Update profile, change password, manage support tickets — all in chat

**🌍 Multilingual & Themeable**
- 6 built-in languages: English, Arabic (RTL), Turkish, French, Spanish, German
- Live translation editor at `/admin/translations` — no restart needed
- 11 visual themes, preference saved per user account

</td>
</tr>
</table>

---

## Installation

SAMM installs everything it needs — **one script, one server, online in minutes.**

### One-command install

On a fresh **Ubuntu 22.04 / 24.04** or **Debian 12** server:

```bash
curl -fsSL https://samm.securytik.com/install.sh | sudo bash
```

That downloads the latest release and runs the full installer automatically.

<details>
<summary><b>Or install manually from a release bundle</b></summary>

<br>

Download the latest `samm-<version>.tar.gz` from the [Releases](https://github.com/mhdhaidarah/samm/releases/latest) page, then:

```bash
tar -xzf samm-<version>.tar.gz
cd samm-<version>
sudo bash install.sh
```

</details>

### What the installer sets up automatically

| Component | Details |
|---|---|
| **FreeRADIUS 3** | Configured with PostgreSQL backend, dynamic NAS clients |
| **PostgreSQL** | Database + schema + all migrations applied automatically |
| **Python venv** | All Python dependencies installed |
| **nginx** | Reverse-proxy on port 80; if occupied the installer prompts for an alternate port (or set `SAMM_HTTP_PORT`) |
| **samm-api** | FastAPI admin + customer portal (systemd unit) |
| **samm-radius** | CoA dispatcher + expiration/quota enforcement (systemd unit) |
| **samm-worker** | MikroTik API sync + ping monitor (systemd unit) |
| **samm-notification** | Email / Telegram notification delivery worker (systemd unit) |
| **samm-telegram** | Interactive Telegram self-service bot (systemd unit) |
| **WireGuard** | Packages installed; configure peers from System → VPN |
| **cloudflared** | Binary installed; paste a Zero Trust token at the prompt or configure later via System → Cloudflare Tunnel |

All credentials (DB password, session signing keys) are **auto-generated** on first install.

The installer is **idempotent** — safe to re-run for upgrades. It shows a live colored progress display; raw output is captured in `/var/log/samm-install.log`. Run with `SAMM_VERBOSE=1` to stream that output instead.

Any prompts happen **up front**, before installation begins:

```
Cloudflare Zero Trust — paste a connector token to publish SAMM online
without opening firewall ports.  Get it at:
  https://one.dash.cloudflare.com  ->  Networks  ->  Tunnels
Press Enter to skip (configure later from Admin -> System -> Cloudflare Tunnel).
Token: █
```

Paste your connector token and press Enter — SAMM will be live on your Cloudflare domain immediately. To skip, press Enter and configure later from **Admin → System → Cloudflare Tunnel**.

### First login

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

Open the admin portal via your Cloudflare tunnel URL or `http://server-ip/admin/login`.
Log in with **admin / admin** and change your password immediately.

### Add your first router

Go to **Admin → NAS / Routers → Add**. Fill in the router's IP, RADIUS shared secret, and optionally MikroTik API credentials for live device sync. No FreeRADIUS restart needed — NAS records are resolved dynamically from the database.

### Point your MikroTik at SAMM

On the MikroTik, configure:
- **RADIUS server**: your server IP, port 1812/1813, the shared secret from the step above
- **PPPoE / Hotspot**: enable RADIUS authentication, set Interim-Update interval to 60 s

That's it. SAMM handles everything else.

### Set up WireGuard VPN *(optional)*

If your MikroTiks live behind NAT or on a separate management network:

1. **Admin → System → VPN → Server tab**
2. Click **Generate Keys**, set the listen port (default 51820) and tunnel address (default `10.254.254.1/24`), tick **Enable**, click **Save**
3. **Clients tab → Add Client** — name the peer, then download its config file, scan the QR, or copy the MikroTik RouterOS terminal commands directly

---

## Upgrading

Re-run the installer with the newer bundle to upgrade. The installer re-applies all migrations, reloads configs, and restarts services. Your config files (`/etc/samm/samm.yaml`, `/etc/samm/api.env`, `/etc/samm/secret.key`) are **never overwritten** on re-runs.

```bash
curl -fsSL https://samm.securytik.com/install.sh | sudo bash
```

Or let SAMM keep itself current automatically via **System → License → auto-update** in the admin portal.

---

## Configuration

### `/etc/samm/samm.yaml`

Shared by all SAMM services. Holds the database connection — never duplicate it elsewhere.

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

Loaded by `samm-api`. **Preserve this file across upgrades** — rotating the cookie secrets invalidates all active sessions.

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

### Live tunables

Updated at runtime with no restart required from **Admin → System → Settings**:

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

# Port 8000 stuck after a crash
kill -9 $(lsof -ti:8000) && systemctl restart samm-api
```

---

## Admin CLI

Apply subscriber actions from the shell. Changes are picked up by `samm-radius` on its next tick and a live CoA is sent if the subscriber is currently online.

```bash
CLI="sudo -u samm /opt/samm/venv/bin/python -m samm_radius.cli"

$CLI reset-quota       alice      # reset quota counter
$CLI reset-daily       alice      # reset daily counter
$CLI reset-uptime      alice      # reset uptime counter
$CLI reset-expiration  alice      # reset expiration counter

$CLI change-plan alice home-50M   # switch plan immediately
```

---

## Licensing

Each SAMM install is licensed **per device**:

| Tier | AAA users | Hotspot cards | NAS / routers |
|---|---|---|---|
| **Free** | 100 | 500 | 2 |
| **Pro** | 2,000 | 5,000 | 5 |
| **Pro Max** | unlimited | unlimited | unlimited |

Activate and manage licensing from **System → License** in the admin portal. See [samm.securytik.com](https://samm.securytik.com) for pricing.

---

## Notes

- **Cleartext passwords** are required for PAP/CHAP. EAP is explicitly disabled by the installer.
- **No SSL on the server** — SAMM runs on port 80 behind Cloudflare Zero Trust. TLS is terminated at the Cloudflare edge; the tunnel between cloudflared and the SAMM server is encrypted by the connector.
- **CoA timing**: time-driven events (expiration, speed windows, daily reset) fire within `samm_radius_interval_seconds` (default 30 s). Lower this in **Admin → System → Settings** for tighter enforcement.
- **Remote PostgreSQL**: the installer assumes a local PG instance. For a remote DB, update `pg_hba.conf` on the DB server and set the DSN in `/etc/samm/samm.yaml` manually after install.
- **Regenerating WireGuard server keys is destructive**: every deployed client config still has the old server pubkey baked in. After regeneration, re-hand-out the updated config (Clients tab → Config / QR) to every device. The UI gates this with a "type REGENERATE to confirm" dialog.
- **Cloudflare token storage**: the token is never persisted in SAMM's database. Removing the tunnel from the UI deletes the `cloudflared` systemd unit entirely.
- **Dependencies**: SAMM ships SAMM. FreeRADIUS, PostgreSQL, nginx, Python, WireGuard, and cloudflared are fetched from upstream apt repos at install time. Air-gapped installs need to pre-stage those packages.

---

## Documentation & support

- 📖 **Full guide:** [samm.securytik.com/docs](https://samm.securytik.com/docs) — install & deploy, create plans, add subscribers, limits, and the complete operator manual
- 🐛 **Report a bug:** [samm@securytik.com](mailto:samm@securytik.com?subject=SAMM%20Bug%20Report)
- 💡 **Request a feature:** [samm@securytik.com](mailto:samm@securytik.com?subject=SAMM%20Feature%20Request)

---

<div align="center">

Built by [**SecuryTik**](https://securytik.com) &nbsp;·&nbsp; SAMM is a SecuryTik product

</div>
