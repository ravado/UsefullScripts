# ⚡ Quickstart

Run these on fresh Zorin OS:

```bash
# Install TeamViewer, Viber, Telegram (+ Chrome & Brave)
bash <(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/refs/heads/main/macbook-resurrection/1.install_required_apps.sh) --with-chrome --with-brave

# Install only TeamViewer, Viber, Telegram
bash <(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/refs/heads/main/macbook-resurrection/1.install_required_apps.sh)

# Apply mac-like layout (top bar + bottom dock)
bash <(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/refs/heads/main/macbook-resurrection/2.zorin-maclike-layout.sh)
```

---

# 💻 MacBook Resurrection — Zorin OS Helpers

Two helper scripts to finish setup on Zorin OS (e.g., MBP Late-2013):  

1. `1.install_required_apps.sh` → TeamViewer, Viber, Telegram (+ optional Chrome & Brave)  
2. `2.zorin-maclike-layout.sh` → top bar + bottom mac-like dock  

---

## 🚀 Quick run (remote one-liners)

**Apps (with Chrome + Brave):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/refs/heads/main/macbook-resurrection/1.install_required_apps.sh) --with-chrome --with-brave
```

**Apps (just TeamViewer, Viber, Telegram):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/refs/heads/main/macbook-resurrection/1.install_required_apps.sh)
```

**Mac-like layout (top + dock):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ravado/usefull-scripts/refs/heads/main/macbook-resurrection/2.zorin-maclike-layout.sh)
```

---

## 📦 Script details

### `1.install_required_apps.sh`
- Installs:
  - 🖥️ TeamViewer  
  - 💬 Viber  
  - ✈️ Telegram  
- Flags:  
  - `--with-chrome` → 🌐 Google Chrome  
  - `--with-brave` → 🦁 Brave browser  

### `2.zorin-maclike-layout.sh`
- Enables **Dash-to-Dock**  
- Moves dock ➡️ bottom, centered icons, autohide  
- Keeps Zorin’s top bar  

---

## 🔄 Browser data tip

- Use **Chrome Sync** (easy) or  
- Export/import bookmarks `.html` or  
- Copy Chrome profile → import into Brave  

---

## ⚠️ Notes
- Wi-Fi on MBP 2013:  
  ```bash
  sudo apt install -y bcmwl-kernel-source && sudo reboot
  ```
- If dock doesn’t show, log out/in once.  
