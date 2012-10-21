.PHONY: all clean help
.PHONY: tools
.PHONY: submodule-init %-repository-init u-boot linux hwpack

CROSS_COMPILE=arm-linux-gnueabihf-
OUTPUT_DIR=output
Q=@

all: tools

clean:
	rm -rf $(OUTPUT_DIR)
	rm -f chosen_board.mk

tools: sunxi-tools-repository-init
	$(Q)$(MAKE) -C sunxi-tools

u-boot: u-boot-sunxi-repository-init
	$(Q)$(MAKE) -C u-boot-sunxi $(UBOOT_CONFIG) CROSS_COMPILE=${CROSS_COMPILE}

O_PATH=build/linux-$(KERNEL_CONFIG)
linux: linux-sunxi-repository-init
	$(Q)$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm $(KERNEL_CONFIG)
	$(Q)$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} uImage
	$(Q)$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} INSTALL_MOD_PATH=$(O_PATH) modules
	$(Q)$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} INSTALL_MOD_PATH=$(O_PATH) modules_install

script.bin: tools
	$(Q)mkdir -p $(OUTPUT_DIR)
	$(Q)sunxi-tools/fex2bin sunxi-boards/sys_config/$(SOC)/$(BOARD).fex > $(OUTPUT_DIR)/$(BOARD).bin

boot.scr:
	$(Q)mkdir -p $(OUTPUT_DIR)
	$(Q)[ -e boot.cmd ] &&mkimage -A arm -O u-boot -T script -C none -n "boot" -d boot.cmd $(OUTPUT_DIR)/boot.scr ||echo

hwpack: u-boot boot.scr script.bin linux
	$(Q)echo WIP hwpack
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs

	$(Q)## Only support Debian/Ubuntu for now
	#$(Q)cp a10-config/rootfs/debian-ubuntu/* $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs -rf

	$(Q)## bins
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/usr/bin
	#$(Q)cp ../../a10-tools/a1x-initramfs.sh $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/usr/bin
	#$(Q)chmod 755 $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/usr/bin/a1x-initramfs.sh

	$(Q)## libs
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/bin-backup
	$(Q)cp mali-libs/r2p4/armhf/x11/* $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs -rf
	$(Q)cp mali-libs/r2p4/armhf/x11/* $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/bin-backup -rf

	$(Q)## kernel
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel
	$(Q)cp linux-sunxi/$(O_PATH)/arch/arm/boot/uImage $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel/
	$(Q)cp $(OUTPUT_DIR)/$(BOARD).bin $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel/
	$(Q)## boot.scr (optional)
	-$(Q)cp $(OUTPUT_DIR)/boot.scr $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel/boot.scr 

	$(Q)## kernel modules
	$(Q)cp linux-sunxi/$(O_PATH)/output/lib $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/lib -rf

	$(Q)## bootloader
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/bootloader
	$(Q)cp u-boot-sunxi/spl/sunxi-spl.bin $(OUTPUT_DIR)/$(BOARD)_hwpack/bootloader/
	$(Q)cp u-boot-sunxi/u-boot.bin $(OUTPUT_DIR)/$(BOARD)_hwpack/bootloader/

	$(Q)## compress hwpack
	$(Q)cd $(OUTPUT_DIR)/$(BOARD)_hwpack/ && 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../$(BOARD)_hwpack.7z .

hwpack-install: 
ifndef SD_CARD
	$(Q)echo "Define SD_CARD variable"
else
	$(Q)scripts/a1x-media-create.sh $(SD_CARD) $(OUTPUT_DIR)/$(BOARD)_hwpack.7z norootfs
endif

update: submodule-init
	$(Q)git submodule -q foreach git pull origin HEAD

submodule-init:
	$(Q)git submodule init

%-repository-init: submodule-init
	$(Q)[ -e $*/.git ] || git submodule update $*


include chosen_board.mk
