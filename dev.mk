RELEASE ?=
KERNEL_DEFCONFIG ?= rockchip_linux_defconfig

ifneq (,$(RELEASE))
LOCALVERSION ?= -$(RELEASE)-ayufan-g$$(git rev-parse --short HEAD)
else
LOCALVERSION ?= -dev
endif

KERNEL_VERSION ?= $(shell $(KERNEL_MAKE) -s kernelversion)
KERNEL_RELEASE ?= $(shell $(KERNEL_MAKE) -s kernelrelease)
KDEB_PKGVERSION ?= $(KERNEL_VERSION)-$(RELEASE)-ayufan

KERNEL_MAKE ?= make \
	ARCH=arm64 \
	HOSTCC=aarch64-linux-gnu-gcc \
	CROSS_COMPILE="ccache aarch64-linux-gnu-" \
	LOCALVERSION=$(LOCALVERSION)

.config: arch/arm64/configs/$(KERNEL_DEFCONFIG)
	$(KERNEL_MAKE) $(KERNEL_DEFCONFIG)

version:
	@echo "$(KDEB_PKGVERSION)"

.PHONY: info
info: .config
	@echo $(KERNEL_RELEASE)

.PHONY: kernel-menuconfig
kernel-menuconfig:
	$(KERNEL_MAKE) $(KERNEL_DEFCONFIG)
	$(KERNEL_MAKE) HOSTCC=gcc menuconfig
	$(KERNEL_MAKE) savedefconfig
	mv defconfig arch/arm64/configs/$(KERNEL_DEFCONFIG)

.PHONY: kernel-image
kernel-image: .config
	$(KERNEL_MAKE) Image dtbs -j$$(nproc)

.PHONY: kernel-modules
kernel-image-and-modules: .config
	$(KERNEL_MAKE) Image modules dtbs -j$$(nproc)
	$(KERNEL_MAKE) modules_install INSTALL_MOD_PATH=$(CURDIR)/out/linux_modules

.PHONY: kernel-package
kernel-package: .config
	KDEB_PKGVERSION=$(KDEB_PKGVERSION) $(KERNEL_MAKE) bindeb-pkg -j$$(nproc)

REMOTE_DIR ?= root@$(REMOTE_HOST):

.PHONY: kernel-update-modules
kernel-update-modules: .config
	$(KERNEL_MAKE) modules -j$$(nproc)
	$(KERNEL_MAKE) modules_install INSTALL_MOD_PATH=$(CURDIR)/out/linux_modules
	rsync --partial --checksum -av out/linux_modules/lib/modules/$(KERNEL_RELEASE) $(REMOTE_DIR)/lib/modules

.PHONY: kernel-update-dts
kernel-update-dts: .config
	$(KERNEL_MAKE) dtbs -j$$(nproc)
	rsync --partial --checksum --include="*.dtb" -rv arch/arm64/boot/dts/rockchip $(REMOTE_DIR)/boot/dtbs/$(KERNEL_RELEASE)

.PHONY: kernel-update
kernel-update-image:
	rsync --partial --checksum -rv arch/arm64/boot/Image $(REMOTE_DIR)/boot/vmlinuz-$(KERNEL_RELEASE)
	rsync --partial --checksum --include="*.dtb" -rv arch/arm64/boot/dts/rockchip $(REMOTE_DIR)/boot/dtbs/$(KERNEL_RELEASE)
	rsync --partial --checksum -av out/linux_modules/lib/modules/$(KERNEL_RELEASE) $(REMOTE_DIR)/lib/modules
