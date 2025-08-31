# VFIO Fix Scripts for Proxmox

Цей репозиторій містить допоміжні скрипти для виправлення проблем з PCIe passthrough у Proxmox.

## Передісторія
PCIe passthrough можна зручно налаштувати за допомогою [Proxmox Enhanced Configuration Utility](https://github.com/Danilop95/Proxmox-Enhanced-Configuration-Utility).  
Але на практиці іноді вона створює некоректні параметри в `/etc/modprobe.d/vfio.conf` (наприклад, сотні повторів `ids=`), через що ядро видає помилки на кшталт:

```
modprobe: ERROR: could not insert ‘vfio_pci’: No space left on device
dmesg: ids: string doesn’t fit in 1023 chars.
```

У такому випадку відеокарта або її аудіо-частина не прив’язуються до `vfio-pci`, і passthrough у ВМ не працює.

## Що роблять скрипти
- знаходять GPU та його HDMI-audio пристрій (AMD або NVIDIA);
- формують чистий та коректний рядок `options vfio-pci ids=…` у `/etc/modprobe.d/vfio.conf`;
- вмикають автозавантаження необхідних модулів (`vfio`, `vfio_pci`, `vfio_iommu_type1`);
- перевантажують модуль `vfio_pci` з новими параметрами;
- відв’язують GPU/Audio від старих драйверів (`amdgpu`, `nvidia`, `snd_hda_intel`) та прив’язують до `vfio-pci`;
- перевіряють, що для обох пристроїв драйвер у use — `vfio-pci`.

## Скрипти
- `fix-vfio-amd-rx-5700xt.sh` — для карт **AMD (Radeon)**  
- `fix-vfio-amd-rx-5700xt.sh` — для карт **NVIDIA (Quadro/GeForce)**  

Запуск:
```bash
bash fix-vfio-amd-rx-5700xt.sh
# або
bash fix-vfio-amd-rx-5700xt.sh
```