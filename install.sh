#!/bin/bash
disco="/dev/sda"
hostname="shamshung-pt2"

SSID="Sistemas Operativos en Red"
PASS="123456789"
INTERFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')

echo "=== Verificando conexión a internet ==="
# Hace ping a google, si sale bien exit 0 :D
if ping -c 2 -W 2 8.8.8.8; then
    echo "Conexión a internet: OK"
else
    echo "Sin conexión a internet"
    echo "Cancelando instalacion"
    exit 1
fi


# Particionado
echo "=== Instalando y particionando: $disco ==="

fdisk "$disco" <<EOF
o
n
p
1
    
    
a
p
w  
EOF

mkfs.ext4 /dev/sda1
mount --mkdir /dev/sda1 /mnt

echo "=== Partición creada en $disco ==="


# Instalacion y set up de la instalacion
echo "=== Preparar sistema operativo ==="
## Paquetes base del sistema
pacstrap -K /mnt base linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 5


arch-chroot /mnt


timedatectl set-timezone Europe/Madrid
hwclock --systohc
timedatectl

echo "LANG=es_ES.UTF-8" > /etc/locale.conf
echo "KEYMAP=es" > /etc/locale.conf
locale-gen

echo "$hostname" > /etc/hostname

pacman -Sy
pacman -Syu wpa_supplicant wireless_tools iw dhcpcd iproute2 iputils impala nano

echo "=== Configurando Wi-Fi ==="

# Generar configuración WPA
wpa_passphrase "$SSID" "$PASS" > /etc/wpa_supplicant/wpa_supplicant.conf

# Crear servicio de arranque automático
systemctl enable wpa_supplicant@$INTERFACE.service
systemctl enable dhcpcd@$INTERFACE.service

## Swaaaap
dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

swapon --show

## Configuracion del bootloader (vamos a usar grub como persona NORMAL)
echo "=== Instalando GRUB ==="
pacman -Sy --noconfirm grub

echo "==> Instalando el cargador en $disco..."
grub-install --target=i386-pc "$disco"

echo "==> Generando configuración de GRUB..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Aplicando configuración para arranque instantáneo..."
cat <<'EOF' > /etc/default/grub
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_DEFAULT=0
GRUB_DISABLE_SUBMENU=y
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_DISABLE_RECOVERY=true
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog"
GRUB_CMDLINE_LINUX=""
EOF

echo "==> Regenerando grub.cfg..."
grub-mkconfig -o /boot/grub/grub.cfg
