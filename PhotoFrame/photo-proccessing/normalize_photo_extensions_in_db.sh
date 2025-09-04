#!/bin/bash
#
# === normalize_db_extensions.sh ===
# Скрипт для нормалізації розширень у базі SQLite (таблиця file, поле extension).
# Перед внесенням змін робить резервну копію.
#
# Використання:
#   ./normalize_db_extensions.sh pictureframe.db3           # реальне оновлення
#   ./normalize_db_extensions.sh pictureframe.db3 --dry-run # показати, без змін
#

DB=""
DRYRUN=0

# розбір аргументів
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRYRUN=1 ;;
        *) DB="$arg" ;;
    esac
done

if [[ -z "$DB" ]]; then
    echo "❌ Помилка: потрібно вказати шлях до бази даних"
    exit 1
fi

if [[ ! -f "$DB" ]]; then
    echo "❌ Помилка: база даних $DB не існує"
    exit 1
fi

# --- Перевірка наявності sqlite3 ---
if ! command -v sqlite3 &>/dev/null; then
    echo "ℹ️ sqlite3 не знайдено. Спроба встановлення..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y sqlite3
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y sqlite
    elif command -v apk &>/dev/null; then
        sudo apk add sqlite
    elif command -v brew &>/dev/null; then
        brew install sqlite
    else
        echo "❌ Не вдалося автоматично встановити sqlite3. Встанови вручну."
        exit 1
    fi
fi

# скільки рядків підлягає зміні
TO_UPDATE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM file WHERE extension != lower(extension);")

if [[ "$TO_UPDATE" -eq 0 ]]; then
    echo "ℹ️ Нічого змінювати не потрібно"
    exit 0
fi

if [[ $DRYRUN -eq 1 ]]; then
    echo "🔍 Dry-run: знайдено $TO_UPDATE рядків для оновлення"
    sqlite3 "$DB" "SELECT file_id, extension FROM file WHERE extension != lower(extension) LIMIT 50;"
    echo "ℹ️ Показані перші 50 рядків (щоб не захаращувати консоль)"
    echo "👉 Реальних змін не зроблено"
else
    # резервна копія
    BACKUP="${DB}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$DB" "$BACKUP"
    echo "📦 Резервну копію створено: $BACKUP"

    sqlite3 "$DB" "UPDATE file SET extension = lower(extension) WHERE extension != lower(extension);"
    echo "✅ Оновлено $TO_UPDATE рядків"
fi