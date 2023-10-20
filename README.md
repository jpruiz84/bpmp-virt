# BPMP virtualization

The BPMP (Boot and Power Management Processor) virtualization allows the
virtual machines (VMs) to access the BPMP resources (such as specific
devices' clocks and resets) to passthrough platform devices where the
drivers requires to control the resets and clocks configurations.

The next diagram shows on the left how the GPU or UART drivers on host
communicate with the BPMP driver to enable the reset and clocks to init
the device. Due to Nvidia does not support a mailbox passthrough to
communicate a VM directly to the BPMP we need to virtualize the BPMP services.
We have found that the reset and clock transactions are done in the BPMP
driver with a common function that is called **tegra_bpmp_transfer**. Then,
to virtualize the BPMP we will virtualize this function.

                                            VM
                                   +------------------+
                                   |GPU or UART driver|
                                   +------------------+
                                             | Reset/clocks
                                             v
                                   +------------------+
                                   | BPMP guest proxy |
                                   +------------------+
                                             |
                                  -----------|-----------
                                  VMM/Qemu   v
                                   +------------------+
                                   |   BPMP VMM guest |
                                   +------------------+
                                             |
                                  -----------|-----------
    Host                          Host       v
     +------------------+           +-----------------+
     |GPU or UART driver|           | BPMP host proxy |
     +------------------+           +-----------------+
               | Reset/clocks                |
               v                             v
       +--------------+              +--------------+
       | BPMP driver  |              | BPMP driver  |
       +--------------+              +--------------+


## General design assumptions

1. Use the same kernel for guest and host, with the same kernel
   configuration.
2. Minimal modifications to kernel bpmp source code.
3. Add another repository for BPMP proxy (host and guest) as kernel overlay.
   This repository with this README.md is a fork of such previous work.
   Specificly, https://github.com/jpruiz84/bpmp-virt has been forked to this 
   repository.

### BPMP host proxy

- Runs in the host kernel. It exposes the tegra_bpmp_transfer function to the
  user level via a char device "/dev/bpmp-host".
- Written as a builtin kernel module overlay in this repository.
- Enabled in the kernel via a "*nvidia,bpmp-host-proxy*" device tree node on the
  host device tree.
- In the "nvidia,bpmp-host-proxy" device tree node define the clocks and resets
  that will be allowed to be used by the VMs.
- See complle instructions below


### BPMP VMM guest

- Communicates the BPMP-host to the BPMP-guest through a IOMEM in the VMM/Qemu.
- Compile Qemu with patched additions and install Qemu on host.
  The code is available in: https://github.com/vadika/qemu-bpmp/tree/v7.2.0-bpmp
  Alternatively you can use the 8.1.0 version in https://github.com/KimGSandstrom/qemu-bpmp.git. 
  You can also use the code from the official Qemu repository and patch the code with

  		0008-bpmp-guest-proxy-dts.patch

### BPMP guest proxy

- Runs in the guest kernel. It intercepts tegra_bpmp_transfer call and routes
  the request through proxies to the host kernel driver.
- Written as a builtin kernel module overlay in this repository.
- It is enabled by the "*virtual-pa*" property in the bpmp node in the guest device tree
  it defines the VPA (Virtual Physical Address) QEMU assigns for the BPMP VMM guest.
- Use the same kernel code as for host.


### BPMP driver

The BPMP driver has small modifications intended to:
- Intercepts the tegra_bpmp_transfer function to use the tegra_bpmp_transfer_redirect
  from the BPMP guest.
- Reads the *virtual-pa* property from the guest device tree to pass the BPMP VMM 
  guest VPA to the BPMP guest proxy module.

Modifications to the BPMP driver are included in patches against the NVIDIA kernel-5.10 with 
tag jetson_35.3.1

## Installation steps

1. Create a development environment with Ubuntu 20.04 on your Nvidia Orin.

2. Download the Nvidia L4T Driver Package (BSP) version 35.3.1 from (also
   tested with version 35.2.1):

		https://developer.nvidia.com/embedded/jetson-linux-r3531

3. Extract the Nvidia L4T Driver Package (BSP):

		tar -xvf Jetson_Linux_R35.3.1_aarch64.tbz2

4. Sync the source code to the tag *jetson_35.3.1*

		cd Linux_for_Tegra
		./source_sync.sh -t jetson_35.3.1

5. Clone this repository to Linux_for_Tegra/sources/kernel

		cd sources/kernel
		git clone https://github.com/jpruiz/bpmp-virt.git

6. Apply patches from the repo with:

		git -C kernel-5.10/ apply \
			../bpmp-virt/0001-added-configurations-to-support-vda.patch \
			../bpmp-virt/0002-vfio_platform-reset-required-false.patch \
			../bpmp-virt/0003-bpmp-support-bpmp-virt.patch
			../bpmp-virt/0007-bpmp-overlay.patch

	Applying the '0002-vfio_platform-reset-required-false.patch' is redundant 
	if kernel boot parameters are set as described below

7. NOTE that the bpmp-virt kernel overlay is added by the '0007-bpmp-overlay.patch'. The line
   "bpmp-virt" has been added to the files.

		kernel-5.10/kernel-int-overlays.txt
		kernel-5.10/kernel-overlays.txt

8. Check that the following configuration lines were added by the '0001-added-configurations-to-support-vda.patch' to
   kernel-5.10/arch/arm64/configs/defconfig

		CONFIG_VFIO=y
		CONFIG_KVM_VFIO=y
		CONFIG_VFIO_PLATFORM=y
		CONFIG_TEGRA_BPMP_GUEST_PROXY=y
		CONFIG_TEGRA_BPMP_HOST_PROXY=y

9. Compile the Linux kernel and the bpmp-virt kernel overlay with the next commands

		cd Linux_for_Tegra/sources/kernel
		make -C kernel-5.10/ ARCH=arm64 O=../kernel_out -j12 defconfig
		make -C kernel-5.10/ ARCH=arm64 O=../kernel_out -j12 Image

    You will find the compiled kernel image in:

		kernel_out/arch/arm64/boot/Image

    **IMPORTANT NOTE:** use this same image for both host and kernel.


## UARTA passthrough instructions

This instructions describes the modifications on the device tree to passthrough
the UARTA that is BPMP dependent

1. For the host, modify the uarta node in Linux_for_Tegra/sources/hardware/
   nvidia/soc/t23x/kernel-dts/tegra234-soc/tegra234-soc-uart.dtsi
   with this content:

		uarta: serial@3100000 {
			compatible = "nvidia,tegra194-dummy", "nvidia,vfio-platform";
			//iommus = <&smmu_niso0 TEGRA_SID_NISO0_GPCDMA_0>;
			iommus = <&smmu_niso0 TEGRA_SID_NISO1_SMMU_TEST>;
			dma-coherent;
			reg = <0x0 0x03100000 0x0 0x10000>;
			reg-shift = <2>;
			interrupts = <0 TEGRA234_IRQ_UARTA 0x04>;
			nvidia,memory-clients = <14>;
			dmas = <&gpcdma 8>, <&gpcdma 8>;
			dma-names = "rx", "tx";
			clocks = <&bpmp_clks TEGRA234_CLK_UARTA>,
				<&bpmp_clks TEGRA234_CLK_PLLP_OUT0>;
			clock-names = "serial", "parent";
			resets = <&bpmp_resets TEGRA234_RESET_UARTA>;
			reset-names = "serial";
			status = "okay";
		 };

    Alternatively you can apply the changes from a patch

		pushd path-to/Linux_for_Tegra/sources/hardware/nvidia/soc/t23x/
		patch -p1 < path-to/0006-bpmp-host-uarta-dts.patch
		popd

    This places the UARTA alone in the IOMMU group TEGRA_SID_NISO1_SMMU_TEST.
    Also, this configuration disables the default nvidia,tegra194-hsuart driver
    by replacing it with a dummy driver.

2. For the host add the bpmp_host_proxy node to Linux_for_Tegra/sources/
   hardware/nvidia/soc/t23x/kernel-dts/tegra234-soc/tegra234-soc-base.dtsi
   with the next content:

		bpmp_host_proxy: bpmp_host_proxy {
			compatible = "nvidia,bpmp-host-proxy";
			dmas = <&gpcdma 8>, <&gpcdma 8>;
			dma-names = "rx", "tx";
			clocks = <&bpmp_clks TEGRA234_CLK_UARTA>,
				<&bpmp_clks TEGRA234_CLK_PLLP_OUT0>;
			clock-names = "serial", "parent";
			resets = <&bpmp_resets TEGRA234_RESET_UARTA>;
			reset-names = "serial";
			status = "okay";
		};

    Alternatively you can apply the changes from a patch

		pushd path-to/Linux_for_Tegra/sources/hardware/nvidia/soc/t23x/
		patch -p1 < path-to/0005-bpmp-host-proxy-dts.patch
		popd

    With this configuration we enable the bpmp-host in the host. Also, here
    we inform to the bpmp-host which are the allowed resources (clocks and
    resets) that can be used by the VMs. Copy these resources from the device
    tree node of the devices that you will passthrough.

3. If it is not already there, remember to add the interrupts configurations 
   to the node "*intc: interrupt-controller@f400000*" in the file 
   kernel-dts/tegra234-soc/tegra234-soc-minimal.dtsi in 
   Linux_for_Tegra/sources/hardware/nvidia/soc/t23x

		interrupts = <GIC_PPI 9
			(GIC_CPU_MASK_SIMPLE(8) | IRQ_TYPE_LEVEL_HIGH)>;
		interrupt-parent = <&intc>;

4. Compile the device tree with the command:

 		cd Linux_for_Tegra/sources/kernel
 		make -C kernel-5.10/ ARCH=arm64 O=../kernel_out -j12 dtbs

	You will find the compiled device tree for Nvidia Jetson Orin AGX host on:

		kernel_out/arch/arm64/boot/dts/nvidia/tegra234-p3701-0000-p3737-0000.dtb

5. Copy kernel Image and tegra234-p3701-0000-p3737-0000.dtb files to the appropriate
   locations defined in

		/boot/extlinux/extlinux.conf

6. Start setting up the guest. Extract and edit guests Device Tree
	Dump the guests Device Tree from Qemu:

		qemu-system-aarch64 -machine virt,accel=kvm,dumpdtb=virt.dtb -cpu host

	Extract the dts code from the dtb file and copy it for editing:

		dtc -Idtb -Odts virt.dtb -o virt-qemu-8.1.0.dts
		cp virt-qemu-8.1.0.dts uarta-qemu-8.1.0.dts

	Now you can edit the guest Device Tree in 'uarta-qemu-8.1.0.dts'.

7. In the previous steps you have prepared the guest's dtb for editing. An alternative 
   to the amendments described in steps 8 - 9 is also available in a patch file

		patch -p0 < 0008-bpmp-guest-proxy-dts.patch -o uarta-qemu-8.1.0.dts

    Note that the patch file is for files named 'virt-qemu-8.1.0.dts' and 
    'uarta-qemu-8.1.0.dts'. Adjust names or patch file accordingly.

8. Edit the Qemu guest's device tree.

		nvim uarta-qemu-8.1.0.dts

	Add the bpmp node and the VPA address property (virtual-pa) to the device tree root.

		bpmp: bpmp {
		    compatible = "nvidia,tegra234-bpmp", "nvidia,tegra186-bpmp";
		    virtual-pa = <0x0 0x090c0000>;
		    #clock-cells = <1>;
		    #reset-cells = <1>;
		    status = "okay";
		};

	Here you define to the bpmp-guest the address of the VPA (virtual-pa), that in
	this case is 0x090c0000

9. For UARTA passthrough you will need to add the *uarta* node to the guest DT.
   Add the uarta node (to the file uarta-qemu-8.1.0.dts)

	*platform@c00000* node:

		platform@c000000 {
		    interrupt-parent = <0x8001>;
		    ranges = <0xc000000 0x00 0xc000000 0x2000000>;
		    #address-cells = <0x01>;
		    #size-cells = <0x01>;
		    compatible = "qemu,platform\0simple-bus";

		    uarta: serial@c000000 {
			compatible = "nvidia,tegra194-hsuart";
			reg = <0xc000000 0x10000>;

			interrupts = <0 0x70 0x04>;
			nvidia,memory-clients = <14>;
			clocks = <&bpmp 155U>,
			<&bpmp 102U>;
			clock-names = "serial", "parent";
			resets = <&bpmp 100U>;
			reset-names = "serial";
			status = "okay";
		    };

    Also, you will need to add the alias for the uarta node. This code must be inserted 
    after the uarta definition. For instance at the end of the root block

		aliases {
		  serial0 = &uarta;
		};

    Note again that steps 8 -9 are available as a patch file described in step 7.

10. Compile the amended guest Device Tree

		dtc -Idts -Odtb uarta-qemu-8.1.0.dts -o uarta-qemu-8.1.0.dtb

11. Also, you will need to allow unsafe interrupts
	Either type as sudo

		echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts

	or add this kernel boot parameter in /boot/extlinux/extlinux.conf

		vfio_iommu_type1.allow_unsafe_interrupts=1

	After reboot, you can check the status with

		cat /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts

	or with

		modinfo vfio_iommu_type1

	You need to bind the uarta serial port to vfio-platform

		echo vfio-platform > /sys/bus/platform/devices/3100000.serial/driver_override
		echo 3100000.serial > /sys/bus/platform/drivers/vfio-platform/bind

	You can check if binding is successful with:

		ls -l /sys/bus/platform/drivers/vfio-platform/3100000.serial

    A symbolic link should be present.

12. Finally you can run your VM. Use the following environment variables and Qemu command. 
    Qemu monitor will be on pty, VM console will be in the startup terminal:

		rootfs="tegra_rootfs.qcow2"
		kernel=Image
		dtb=uarta-qemu-8.1.0.dtb
		sudo -E qemu-system-aarch64 \
		    -nographic \
		    -machine virt,accel=kvm \
		    -cpu host \
		    -m 4G \
		    -no-reboot \
		    -kernel ${kernel} \
		    -dtb ${dtb} \
		    -append "rootwait root=/dev/vda console=ttyAMA0" \
		    -device vfio-platform,host=3100000.serial \
		    -drive file=${rootfs},if=virtio,format=qcow2 \
		    -net user,hostfwd=tcp::2222-:22 -net nic \
		    -chardev pty,id=mon0 \		    -mon chardev=mon0,mode=readline

13. To test the UARTA you can send a *"123"* string with this command from
    the VM:

		echo 123 > /dev/ttyTHS0

    The UARTA (or UART1 in the full package) in the Nvidia Jetson Orin AGX is
    connected to the external  40-pin connector. You can connect a USB to UART
    as follows (the number 1 pin is top right):

		Nvidia Orin AGX      USB to UART
		40 pin connector       cable
		----------------------------------
		6  (GND)	 Black (GND)
		8  (UART1_TX)	 Yellow (RX)
		10 (UART1_RX)	 Orange (TX)

    Then you can get the output of what you sent on your PC from a serial
    terminal:

		picocom -b 9600 /dev/ttyUSB0
