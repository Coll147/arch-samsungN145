#!/bin/bash

echo "------> Verificando conexión a internet..."
# Hace ping a google, si sale bien exit 0 :D
if ping -c 2 -W 2 8.8.8.8; then
    echo "Conexión a internet: OK"
else
    echo "Sin conexión a internet"
    echo "Cancelando instalacion"
    exit 1
fi


# Particionado
echo "------> Instalando y particionando: $disco"
disco="/dev/sda"

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

echo "------>> Partición creada en $disco"


# Instalacion y set up de la instalacion
echo "------> Preparar sistema operativo"
## Paquetes base del sistema
pacstrap -K /mnt base linux linux-firmware
                # optimizar la intalacion de firmwres, se intalan demasiados <<<<

genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 5


arch-chroot /mnt


timedatectl set-timezone Europe/Madrid
hwclock --systohc
timedatectl

echo "LANG=es_ES.UTF-8" > /etc/locale.conf
echo "KEYMAP=es" > /etc/locale.conf
setfont sun12x22.psfu.gz
locale-gen

echo "cojones-arch" > /etc/hostname

pacman -Sy
pacman -Syu \
    # Servicios de red / wifi
    systemd-networkd \
    systemd-resolved \
    iwd \

    # Nano (odio vim)
    nano \

## Swaaaap
dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

swapon --show

## Configuracion del bootloader (syslinux :3)
pacman -S syslinux
sudo dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/sda
syslinux --install /dev/sda1

mkdir -p /boot/syslinux
cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux

cat <<EOF > /boot/syslinux/syslinux.cfg
UI menu.c32
PROMPT 0
TIMEOUT 30
DEFAULT arch

LABEL arch
    LINUX /vmlinuz-linux
    INITRD /initramfs-linux.img
    APPEND root=/dev/sda1 rw
EOF


## Creacion de usuarios
echo "root:root" | chpasswd 