#!/usr/bin/env bash
set -euo pipefail

echo "🌐 === Встановлення та підключення Tailscale ==="

# --- 🧠 Hostname input ---
read -rp "📛 Введи hostname для цього пристрою [pi-backup]: " HOSTNAME
HOSTNAME=${HOSTNAME:-pi-backup}

# --- 🔐 SSH toggle ---
read -rp "🔑 Дозволити SSH через Tailscale? (yes/NO): " enable_ssh
enable_ssh=${enable_ssh,,}
SSH_FLAG=""
if [[ "$enable_ssh" == "yes" ]]; then
    SSH_FLAG="--ssh"
fi

echo "=============================================="
echo "🧾 Налаштування:"
echo "   Hostname: $HOSTNAME"
echo "   SSH через Tailscale: ${enable_ssh:-no}"
echo "=============================================="

# --- 🚀 Update system ---
echo "🚀 Оновлення системи..."
sudo apt-get update -y && sudo apt-get upgrade -y

# --- 📦 Install Tailscale ---
if ! command -v tailscale >/dev/null 2>&1; then
    echo "📦 Встановлюю Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "✅ Tailscale вже встановлено."
fi

# --- 🛠️ Enable service ---
echo "🛠️ Вмикаю tailscaled..."
sudo systemctl enable --now tailscaled

# --- 🔑 Connect to Tailnet ---
echo "🔑 Підключення до Tailnet..."
echo "💡 Зараз відкриється посилання для авторизації. Відкрий його в браузері та підтвердь вхід."
sleep 2
sudo tailscale up --hostname="$HOSTNAME" $SSH_FLAG

# --- 📋 Summary ---
echo "✅ Пристрій додано до Tailnet!"
TAIL_IP=$(tailscale ip -4 2>/dev/null || true)
echo "----------------------------------------------"
echo "   Hostname: $HOSTNAME"
echo "   Tailnet IP: ${TAIL_IP:-невідомо (перевір: tailscale ip -4)}"
echo "----------------------------------------------"
echo "Перевірити статус: tailscale status"
echo "Зупинити: sudo tailscale down"