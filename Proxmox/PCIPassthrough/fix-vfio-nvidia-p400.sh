#!/usr/bin/env bash

# • знаходить GPU та його HDMI-audio;
# • чисто переписує vfio.conf з правильними ids=;
# • вмикає автозавантаження vfio-модулів;
# • перевантажує модулі, відв’язує старі драйвери й підв’язує vfio-pci;
# • показує підсумковий стан.


# fix-vfio-amd-rx-5700xt.sh — авто-налаштування vfio для NVIDIA GPU + HDMI audio
# Використання: bash fix-vfio-amd-rx-5700xt.sh
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
need lspci; need sed; need grep; need awk

echo "[1/7] Шукаю NVIDIA GPU…"
# Беремо перший VGA/3D від NVIDIA
GPU_LINE=$(lspci -Dnns | awk '/(VGA compatible controller|3D controller).*NVIDIA/{print; exit}')
[[ -n "${GPU_LINE}" ]] || { echo "Не знайдено NVIDIA VGA/3D контролер"; exit 1; }
GPU_PCI=$(awk '{print $1}' <<<"$GPU_LINE")
GPU_ID=$(grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' <<<"$GPU_LINE" | tr -d '[]')

# Його аудіо зазвичай .1; якщо ні — шукаємо поруч
AUDIO_PCI="${GPU_PCI%.*}.1"
AUDIO_LINE=$(lspci -Dnns -s "$AUDIO_PCI" 2>/dev/null || true)
if [[ -z "$AUDIO_LINE" ]]; then
  BUS="${GPU_PCI%:*}"
  AUDIO_LINE=$(lspci -Dnns | awk -v b="$BUS" '/Audio device.*NVIDIA/ && index($1,b":")==1{print; exit}')
  [[ -n "$AUDIO_LINE" ]] && AUDIO_PCI=$(awk '{print $1}' <<<"$AUDIO_LINE")
fi
[[ -n "${AUDIO_LINE}" ]] || { echo "Не знайдено NVIDIA HDMI Audio"; exit 1; }
AUDIO_ID=$(grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' <<<"$AUDIO_LINE" | tr -d '[]')

echo "GPU:   $GPU_PCI  id=$GPU_ID"
echo "Audio: $AUDIO_PCI id=$AUDIO_ID"

echo "[2/7] Бекап і чистка /etc/modprobe.d/vfio.conf…"
VFIO_CONF="/etc/modprobe.d/vfio.conf"
[[ -f "$VFIO_CONF" ]] && cp -a "$VFIO_CONF" "${VFIO_CONF}.bak.$(date +%s)" || true
cat > "$VFIO_CONF" <<EOF
# VFIO GPU configuration (автогенеровано для NVIDIA)
options vfio-pci ids=${GPU_ID},${AUDIO_ID} disable_vga=1
EOF

echo "[3/7] Вмикаю автозавантаження vfio-модулів…"
MLD="/etc/modules-load.d/vfio.conf"
if ! grep -qs 'vfio_pci' "$MLD" 2>/dev/null; then
  cat > "$MLD" <<'EOF'
# VFIO modules for GPU passthrough
vfio
vfio_pci
vfio_iommu_type1
EOF
fi

echo "[4/7] Перезавантажую vfio_pci з новими ids…"
modprobe -r vfio_pci 2>/dev/null || true
modprobe -v vfio_pci ids="${GPU_ID},${AUDIO_ID}" disable_vga=1

echo "[5/7] Встановлюю driver_override та unbind старих драйверів…"
for DEV in "$GPU_PCI" "$AUDIO_PCI"; do
  DEVPATH="/sys/bus/pci/devices/$DEV"
  [[ -e "$DEVPATH" ]] || { echo "Нема $DEVPATH"; exit 1; }
  echo vfio-pci > "$DEVPATH/driver_override"
  if [[ -L "$DEVPATH/driver" ]]; then
    echo "$DEV" > "$DEVPATH/driver/unbind" || true
  fi
done

echo "[6/7] Прив’язую обидва пристрої до vfio-pci…"
for DEV in "$GPU_PCI" "$AUDIO_PCI"; do
  echo "$DEV" > /sys/bus/pci/drivers/vfio-pci/bind
done

echo "[7/7] Перевірка стану драйверів:"
lspci -nnk -s "$GPU_PCI"
lspci -nnk -s "$AUDIO_PCI"

echo "✅ Готово. Має бути 'Kernel driver in use: vfio-pci' для обох (GPU та Audio)."
echo "Після ребута прив’язка збережеться (через vfio.conf та modules-load)."