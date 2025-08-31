#!/usr/bin/env bash
# • знаходить твій AMD GPU і його HDMI-audio (PCI-адреси та VEN:DEV),
# • чисто переписує vfio.conf (без дубльованих ids=),
# • підвантажує vfio_pci з правильними ids,
# • відв’язує від старих драйверів і прив’язує до vfio-pci,
# • ставить автозавантаження vfio-модулів.

# fix-vfio-amd-rx-5700xt.sh — коротке авто-налаштування vfio для AMD GPU + HDMI audio
# Використання: bash fix-vfio-amd-rx-5700xt.sh
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
need lspci
need sed
need grep
need awk

echo "[1/7] Визначаю AMD GPU…"
GPU_LINE=$(lspci -Dnns | awk '/VGA compatible controller.*AMD|ATI/{print; exit}')
[[ -n "${GPU_LINE}" ]] || { echo "Не знайдено AMD VGA контролер"; exit 1; }
GPU_PCI=$(awk '{print $1}' <<<"$GPU_LINE")
GPU_ID=$(grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' <<<"$GPU_LINE" | tr -d '[]')

# Припускаємо, що аудіо — функція .1 того ж слоту
AUDIO_PCI="${GPU_PCI%.*}.1"
AUDIO_LINE=$(lspci -Dnns -s "$AUDIO_PCI" 2>/dev/null || true)
if [[ -z "$AUDIO_LINE" ]]; then
  # fallback: шукаємо будь-який AMD HDMI Audio на тому ж bus
  BUS="${GPU_PCI%:*}"
  AUDIO_LINE=$(lspci -Dnns | awk -v b="$BUS" '/Audio device.*AMD|ATI/ && index($1,b":")==1{print; exit}')
  [[ -n "$AUDIO_LINE" ]] && AUDIO_PCI=$(awk '{print $1}' <<<"$AUDIO_LINE")
fi
[[ -n "${AUDIO_LINE}" ]] || { echo "Не знайдено AMD HDMI Audio"; exit 1; }
AUDIO_ID=$(grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' <<<"$AUDIO_LINE" | tr -d '[]')

echo "GPU:   $GPU_PCI  id=$GPU_ID"
echo "Audio: $AUDIO_PCI id=$AUDIO_ID"

echo "[2/7] Резервую та правлю /etc/modprobe.d/vfio.conf…"
VFIO_CONF="/etc/modprobe.d/vfio.conf"
[[ -f "$VFIO_CONF" ]] && cp -a "$VFIO_CONF" "${VFIO_CONF}.bak.$(date +%s)" || true
{
  echo "# VFIO GPU configuration (автогенеровано)"
  echo "options vfio-pci ids=${GPU_ID},${AUDIO_ID} disable_vga=1"
} > "$VFIO_CONF"

echo "[3/7] Гарантую автозавантаження vfio-модулів…"
MLD="/etc/modules-load.d/vfio.conf"
grep -q 'vfio_pci' "$MLD" 2>/dev/null || {
  {
    echo "# VFIO modules for GPU passthrough"
    echo "vfio"
    echo "vfio_pci"
    echo "vfio_iommu_type1"
  } > "$MLD"
}

echo "[4/7] Перезавантажую модуль vfio_pci з новими ids…"
modprobe -r vfio_pci 2>/dev/null || true
modprobe -v vfio_pci ids="${GPU_ID},${AUDIO_ID}" disable_vga=1

echo "[5/7] Встановлюю driver_override і unbind старих драйверів…"
for DEV in "$GPU_PCI" "$AUDIO_PCI"; do
  DEVPATH="/sys/bus/pci/devices/$DEV"
  [[ -e "$DEVPATH" ]] || { echo "Нема $DEVPATH"; exit 1; }
  echo vfio-pci > "$DEVPATH/driver_override"
  if [[ -L "$DEVPATH/driver" ]]; then
    echo "$DEV" > "$DEVPATH/driver/unbind" || true
  fi
done

echo "[6/7] Прив’язую до vfio-pci…"
for DEV in "$GPU_PCI" "$AUDIO_PCI"; do
  echo "$DEV" > /sys/bus/pci/drivers/vfio-pci/bind
done

echo "[7/7] Перевірка драйверів у use…"
lspci -nnk -s "$GPU_PCI"
lspci -nnk -s "$AUDIO_PCI"

echo "✅ Готово. Якщо тут бачиш 'Kernel driver in use: vfio-pci' для обох — все ок."
echo "Після перезавантаження прив’язка збережеться (через vfio.conf і modules-load)."