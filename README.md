<div align="center">

<img src="s-box-logo.svg" width="96" alt="SAMM logo" />

# SAMM

### SecuryTik Active MikroTik Manager

**Full-stack ISP management platform for MikroTik PPPoE & Hotspot networks**

[![Release](https://img.shields.io/github/v/release/mhdhaidarah/samm?style=flat-square&color=3b82f6&label=latest%20release)](https://github.com/mhdhaidarah/samm/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-E95420?logo=ubuntu&logoColor=white&style=flat-square)](https://ubuntu.com)
[![FreeRADIUS](https://img.shields.io/badge/FreeRADIUS-3-CC0000?style=flat-square&logoColor=white)](https://freeradius.org)
[![A SecuryTik product](https://img.shields.io/badge/a-SecuryTik%20product-22d3ee?style=flat-square)](https://securytik.com)

[**samm.securytik.com**](https://samm.securytik.com) &nbsp;·&nbsp; [Documentation](https://samm.securytik.com/docs) &nbsp;·&nbsp; [Report a Bug](mailto:samm@securytik.com?subject=SAMM%20Bug%20Report) &nbsp;·&nbsp; [Request a Feature](mailto:samm@securytik.com?subject=SAMM%20Feature%20Request)

</div>

---

## What is SAMM?

SAMM (**S**ecuryTik **A**ctive **M**ikroTik **M**anager) is a complete ISP management platform for MikroTik PPPoE & Hotspot networks — subscriber authentication, real-time usage enforcement, billing, hotspot vouchers, and a polished admin + customer portal — built on FreeRADIUS and PostgreSQL.

This is the **public distribution repository**. The shipped product is a compiled bundle published on the [**Releases**](https://github.com/mhdhaidarah/samm/releases) page; the full source is maintained privately by [SecuryTik](https://securytik.com).

---

## Install in one command

On a fresh **Ubuntu 22.04 / 24.04** or **Debian 12** server:

```bash
curl -fsSL https://samm.securytik.com/install.sh | sudo bash
```

That downloads the latest release, verifies it, and runs the full installer — FreeRADIUS, PostgreSQL, nginx, and all five SAMM services — online in minutes.

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

The installer is **idempotent** — re-run it with a newer bundle to upgrade, or let SAMM keep itself current automatically (**System → License → auto-update**).

When it finishes, open `http://<your-server>/admin/` and sign in with **`admin` / `admin`** — then change the password immediately.

---

## What's in the box

| | |
|---|---|
| **🔐 AAA core** | FreeRADIUS 3 + PostgreSQL · PPPoE & Hotspot · hybrid CoA (update → disconnect fallback) · dynamic NAS — no restart on router add/remove |
| **📊 Plans & limits** | Speed plans · 4 independent limits (expiration · quota · uptime · daily) · speed windows · throttle / switch-plan / disconnect on exhaust |
| **👥 Subscribers** | PPPoE & Hotspot users · prepaid hotspot voucher cards with printable PDFs · self-service customer portal |
| **💰 Billing** | Per-plan pricing · automatic invoices · receipts, payments & expenses ledger |
| **🖥️ Admin portal** | Live MikroTik inventory · role-based permissions · bulk tools · backup & restore |
| **🔔 Notifications** | Email + Telegram — renewals, expiry, quota warnings, receipts · interactive Telegram self-service bot |
| **🌐 System** | Built-in WireGuard VPN server · Cloudflare Tunnel · 6 languages · themeable UI |

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

## Documentation & support

- 📖 **Full guide:** [samm.securytik.com/docs](https://samm.securytik.com/docs) — install & deploy, create plans, add subscribers, limits, and the complete manual
- 🐛 **Report a bug:** [samm@securytik.com](mailto:samm@securytik.com?subject=SAMM%20Bug%20Report)
- 💡 **Request a feature:** [samm@securytik.com](mailto:samm@securytik.com?subject=SAMM%20Feature%20Request)

---

<div align="center">

Built by [**SecuryTik**](https://securytik.com) &nbsp;·&nbsp; SAMM is a SecuryTik product

</div>
