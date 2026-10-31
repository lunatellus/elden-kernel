### AnyKernel3 setup
properties() { '
kernel.string=Elden BakaSU + SUSFS
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=elden
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

BLOCK=boot
IS_SLOT_DEVICE=auto

. tools/ak3-core.sh

# Write the complete AVB-signed boot image.
flash_generic boot
