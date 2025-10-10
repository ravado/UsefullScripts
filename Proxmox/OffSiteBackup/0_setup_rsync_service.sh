#!/usr/bin/env bash
set -euo pipefail

echo "🔧 === Встановлення та налаштування rsyncd ==="

read -rp "👤 Введи ім'я користувача для rsync [backup]: " USER
USER=${USER:-backup}

read -rsp "🔑 Введи пароль для користувача $USER (обов’язково): " PASS
echo
if [[ -z "$PASS" ]]; then
    echo "❌ Пароль не може бути порожнім."
    exit 1
fi

read -rp "📂 Вкажи шлях до каталогу для бекапів [/mnt/backupdisk]: " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-/mnt/backupdisk}

# --- 👤 Створюємо користувача ---
if ! id "$USER" >/dev/null 2>&1; then
    echo "👤 Створюю користувача $USER..."
    sudo adduser --disabled-password --gecos "" "$USER"
fi
sudo chown -R "$USER:$USER" "$MOUNT_POINT"

# --- 🚀 Встановлення rsync ---
echo "📦 Встановлюю rsync..."
sudo apt-get update -y && sudo apt-get install -y rsync

# --- ⚙️ Конфігурація rsyncd ---
echo "📝 Створюю /etc/rsyncd.conf..."
sudo tee /etc/rsyncd.conf >/dev/null <<EOF
uid = $USER
gid = $USER
use chroot = no
max connections = 2
log file = /var/log/rsyncd.log
timeout = 300

[backup]
   path = $MOUNT_POINT
   comment = Backup module
   read only = false
   auth users = $USER
   secrets file = /etc/rsyncd.secrets
EOF

# --- 🔑 Secrets ---
echo "🔑 Створюю /etc/rsyncd.secrets..."
echo "$USER:$PASS" | sudo tee /etc/rsyncd.secrets >/dev/null
sudo chmod 600 /etc/rsyncd.secrets
sudo chown root:root /etc/rsyncd.secrets

# --- 🔄 Запуск демона ---
echo "🚀 Увімкнення rsync..."
sudo systemctl enable rsync
sudo systemctl restart rsync

echo "✅ Rsyncd готовий!"
echo "   - Порт: 873"
echo "   - Модуль: backup"
echo "   - Шлях: $MOUNT_POINT"
echo "   - Користувач: $USER"