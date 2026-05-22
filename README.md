# SAMM — SecuryTik Active Mikrotik Manager

SAMM is a FreeRADIUS + PostgreSQL + Python AAA stack for MikroTik networks
(PPPoE / Hotspot), with a FastAPI admin and customer portal — built and
maintained by [SecuryTik](https://securytik.com).

This is the **public distribution** repository. The shipped product is a
compiled bundle; the full source is private.

## Download & install

Grab the latest `samm-<version>.tar.gz` from the
[**Releases**](../../releases) page, then:

```bash
tar -xzf samm-<version>.tar.gz
cd samm-<version>
sudo bash install.sh
```

The installer is idempotent — re-run the same steps with a newer bundle to
upgrade. SAMM installs can also keep themselves current automatically
(System → License → auto-update).

## Tiers

Each SAMM install is licensed per device:

| Tier | AAA users | Hotspot cards | NAS |
| --- | --- | --- | --- |
| Free | 100 | 500 | 2 |
| Pro | 2,000 | 5,000 | 5 |
| Pro Max | unlimited | unlimited | unlimited |

Activate and manage licensing from **System → License** in the admin portal.
See [samm.securytik.com](https://samm.securytik.com) for details and pricing.

## Support

- Documentation: <https://samm.securytik.com/docs>
- Contact: accounts@securytik.com

© SecuryTik — SAMM is a SecuryTik product.
