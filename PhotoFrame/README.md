# Photo Frame — Quick Setup

> Minimal steps to bring a new photoframe online with logging + migration scripts.

---

## 1) Install Alloy (logs & metrics)

One-liner (runs as root; auto-handles sudo if needed):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/refs/heads/main/PhotoFrame/logs-and-monitoring/install_alloy.sh)"
```


## 2) Install/Run migration & helper scripts

Bootstraps resizer/sync/backup helpers and any prerequisites:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ravado/UsefullScripts/refs/heads/main/PhotoFrame/migration/install_all.sh)"
```

## Links

- [Logs & Monitoring — README](logs-and-monitoring/README.md)  
- [Migration & Helpers — README](migration/README.md)  