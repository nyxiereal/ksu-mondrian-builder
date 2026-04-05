# KSU for mondrian

## workflow
the workflow builds kernelsu and kernelsu-next kernel module files for mondrian and throws them to github releases. this is done against the lineageos (nongki 5.15) kernel, which is the default one for LOS-based ROMs

## ksupatcher-mondrian
this script is used for the actual kernel patching part, since some KSU managers dont allow the usage of custom `.ko` files for LKM integration. usage examples below

### new boot image patching
1. put your `boot.img` in your phone's internal storage, you can get the boot image [here](https://download.lineageos.org/devices/mondrian/builds)
2. download the script and put it in your phone's temp dir - `adb push ksupatcher-mondrian.sh /data/local/tmp/`
3. enter the adb shell - `adb shell`
4. in the shell, execute the script - `cd /data/local/tmp && chmod +rwx ksupatcher-mondrian.sh && ./ksupatcher-mondrian.sh`
5. patch your downloaded boot image with kernelsu-next - `./ksupatcher-mondrian.sh ksun`
6. the boot image is now in downloads, you can now transfer it to your computer - `adb pull /sdcard/Download/kernelsu_next_patched_12345678_12345678.img`
7. reboot the phone to bootloader - `adb reboot bootloader`
8. flash the new boot image - `fastboot flash boot kernelsu_next_patched_12345678_12345678.img`
9. reboot your phone, install the root manager, and you're done!

### OTA patching
1. finish downloading and installing an OTA, you have to **see** the reboot button, do not click it
2. download the script and put it in your phone's temp dir - `adb push ksupatcher-mondrian.sh /data/local/tmp/`
3. enter the adb shell - `adb shell`
4. in the shell, execute the script - `cd /data/local/tmp && chmod +rwx ksupatcher-mondrian.sh && ./ksupatcher-mondrian.sh`
5. patch your new boot image (extracted from the phone) - `./ksupatcher-mondrian.sh ksun ota`
6. after the script finishes, you can safely reboot the phone (and keep your root access intact)!

## thanks
i would like to thank cyberknight777 for their work [here](https://t.me/motorolag54updates/247), which was the inspiration for this script
