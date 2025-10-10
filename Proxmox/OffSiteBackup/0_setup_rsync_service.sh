#!/usr/bin/env bash
set -euo pipefail

echo "💾 === Raspberry Pi Offsite Backup Setup ==="

# --- 🧠 User input with defaults ---
read -rp "👤 Введи ім'я користувача для rsync [backup]: " USER
USER=${USER:-backup}

read -rp "📂 Введи точку монтування SSD [/mnt/backupdisk]: " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-/mnt/backupdisk}

read -rsp "🔑 Введи пароль для користувача $USER (обов’язково): " PASS
echo
if [[ -z "$PASS" ]]; then
    echo "❌ Пароль не може бути порожнім."
    exit 1
fi

echo "============================================="
echo "🧾 Параметри:"
echo "   Ім’я користувача: $USER"
echo "   Точка монтування: $MOUNT_POINT"
echo "============================================="

# --- 🔍 Detect external disk ---
DISK=$(lsblk -ndo NAME,TRAN | awk '$2=="usb"{print "/dev/"$1; exit}')

if [[ -z "${DISK}" ]]; then
    echo "❌ Не знайдено жодного USB-диску. Підключи SSD і повтори."
    exit 1
fi
if [[ "$DISK" == *mmcblk0* ]]; then
    echo "🚫 Обрано системну SD-карту ($DISK). Зупиняюсь, щоб не стерти систему."
    exit 1
fi
echo "✅ Знайдено диск: $DISK"

# --- ⚙️ Ask about formatting ---
FSTYPE=$(lsblk -no FSTYPE "$DISK" | head -n1)
if [[ -n "$FSTYPE" ]]; then
    echo "ℹ️  На диску $DISK вже є файловa система: $FSTYPE"
else
    echo "⚠️  На диску $DISK немає файлової системи."
fi

read -rp "Хочеш відформатувати цей диск у ext4 (стерти всі дані)? (yes/NO): " confirm
if [[ "${confirm,,}" == "yes" ]]; then
    echo "🧹 Форматую диск у ext4..."
    sudo umount -f "${DISK}"* || true
    sudo mkfs.ext4 -F -L BACKUPDISK "$DISK"
    echo "✅ Диск відформатовано."
else
    echo "🚫 Пропускаю форматування. Використовуватиму існуючу файлову систему."
fi

# --- 📎 Get UUID ---
UUID=$(sudo blkid -s UUID -o value "$DISK")
if [[ -z "$UUID" ]]; then
    echo "❌ Не вдалося знайти UUID. Можливо, диск не відформатований?"
    exit 1
fi
echo "📎 UUID диску: $UUID"

# --- 📂 Mount setup ---
sudo mkdir -p "$MOUNT_POINT"

if ! grep -q "$UUID" /etc/fstab; then
    echo "📄 Додаю запис у /etc/fstab..."
    echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab
fi

echo "🔄 Монтуємо диск..."
sudo mount -a

# --- 👤 Create user ---
if ! id "$USER" >/dev/null 2>&1; then
    echo "👤 Створюю користувача $USER..."
    sudo adduser --disabled-password --gecos "" "$USER"
fi
sudo chown -R "$USER:$USER" "$MOUNT_POINT"

# --- ⚙️ Rsync daemon configuration ---
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

# --- 🔄 Enable daemon ---
echo "🚀 Встановлюю rsync..."
sudo apt-get update -y && sudo apt-get install -y rsync

echo "🔄 Запускаю rsync daemon..."
sudo systemctl enable rsync
sudo systemctl restart rsync

echo "✅ Все готово!"
echo "---------------------------------------------"
echo "Rsync daemon працює на порті 873"
echo "Модуль: backup"
echo "Шлях: $MOUNT_POINT"
echo "Користувач: $USER"
echo "Пароль: $PASS"
echo "---------------------------------------------"