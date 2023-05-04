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
                                  -----------|-----------  
                                  VMM/Qemu   v             
                                   +------------------+    
                                   |   BPMP VMM guest |    
                                   +------------------+    
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


### BPMP host proxy

- Runs in the host kernel. It exposes the tegra_bpmp_transfer function to the 
  user level via a char device "/dev/bpmp-host".
- Written as a builtin kernel module overlay in this repository.
- Enabled in the kernel via a "*nvidia,bpmp-host-proxy*" device tree node on the 
  host device tree.
- In the "nvidia,bpmp-host-proxy" device tree node define the clocks and resets
  that will be allowed to be used by the VMs.


### BPMP VMM guest

- Communicates the BPMP-host to the BPMP-guest through a IOMEM in the VMM/Qemu.
- The code is available in: https://github.com/vadika/qemu-bpmp/tree/v7.2.0-bpmp


### BPMP guest proxy

- Runs in the guest kernel. It intercepts tegra_bpmp_transfer call and routes 
  the request through proxies to the host kernel driver.
- Written as a builtin kernel module overlay in this repository.
- Enable it with the "*virtual-pa*" node in the bpmp node on the guest device tree
- The *virtual-pa* contains the QEMU assigned VPA (Virtual Physical Address) for 
  BPMP VMM guest.


### BPMP driver

The BPMP driver has small modifications intended to:
- Intercepts tegra_bpmp_transfer function to use the tegra_bpmp_transfer_redirect
  from the BPMP guest.
- Reads the *virtual-pa* node from the guest device tree to pass the BPMP VMM guest 
  VPA to the BPMP guest proxy module.

The modifications to the BPMP driver are included in the patch: 

    0003-bpmp-support-bpmp-virt.patch

## Installation steps

1. Get ready a development environment with Ubuntu 20.04 on your Nvidia Orin.

2. Download the Nvidia L4T Driver Package (BSP) version 35.2.1 from:
        
        https://developer.nvidia.com/embedded/jetson-linux-r3521

3. Extract the Nvidia L4T Driver Package (BSP):

        tar -xvf Jetson_Linux_R35.2.1_aarch64.tbz2 

4. Sync the source code to the tag *jetson_35.2.1*

        cd Linux_for_Tegra
        ./source_sync.sh -t jetson_35.2.1

5. Clone this repository to Linux_for_Tegra/sources/kernel

    cd sources/kernel
    git clone https://github.com/jpruiz84/bpmp-virt

6. Apply the patches from this repo with:

    cd Linux_for_Tegra/sources/kernel/kernel-5.10
    git apply ../bpmp-virt/*.patch
    

7. Add the bpmp-virt kernel overlay by adding the line "bpmp-virt" to the files 

        kernel-5.10/kernel-int-overlays.txt
        kernel-5.10/kernel-overlays.txt 

8. Add the following configuration lines to 
   Linux_for_Tegra/sources/kernel/kernel-5.10/arch/arm64/configs/defconfig

        CONFIG_VFIO_PLATFORM=y
        CONFIG_TEGRA_BPMP_GUEST_PROXY=y
        CONFIG_TEGRA_BPMP_HOST_PROXY=y

9. Compile the Linux kernel with the next commands

        cd Linux_for_Tegra/sources/kernel
        make -C kernel-5.10/ ARCH=arm64 O=../kernel_out -j12 defconfig
        make -C kernel-5.10/ ARCH=arm64 O=../kernel_out -j12 Image

    You will find the compiled kernel image on:

        kernel_out/arch/arm64/boot/Image 

    **IMPORTANT NOTE:** use this same image for host and kernel.

## UARTA passthrough instructions

This instructions describes the modifications on the device tree to passthrough
the UARTA that is BPMP dependent

1. For the host modify the uarta node in Linux_for_Tegra/sources/hardware/ 
   nvidia/soc/t23x/kernel-dts/tegra234-soc/tegra234-soc-uart.dtsi
   with the next content:

        uarta: serial@3100000 {
            compatible = "nvidia,tegra194-dummy";
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

    This places the UARTA alone in the IOMMU group TEGRA_SID_NISO1_SMMU_TEST.
    Also, this configuration disables the default nvidia,tegra194-hsuart driver
    by replacing it with a dummy driver.

2. For the host also add the bpmp_host_proxy node to Linux_for_Tegra/sources/
   hardware/nvidia/soc/t23x/kernel-dts/tegra234-soc/tegra234-soc-base.dtsi
   with the next content:

        bpmp_host_proxy: bpmp_host_proxy {
            compatible = "nvidia,bpmp-host-proxy";
            allowed-clocks = <TEGRA234_CLK_UARTA 
                            TEGRA234_CLK_PLLP_OUT0>;
            allowed-resets = <TEGRA234_RESET_UARTA>;				  
            status = "okay";
        };

    With this configuration we enable the bpmp-host in the host. Also, here 
    we inform to the bpmp-host which are the allowed resources (clocks and 
    resets) that can be used by the VMs. Copy these resources from the device
    tree node of the devices that you will passthrough.

3. If it is not there, remember to add the interrupts missing configurations to the
   node "*intc: interrupt-controller@f400000*" in the file Linux_for_Tegra/sources/
   hardware/nvidia/soc/t23x/kernel-dts/tegra234-soc/tegra234-soc-minimal.dtsi 

		interrupts = <GIC_PPI 9
			(GIC_CPU_MASK_SIMPLE(8) | IRQ_TYPE_LEVEL_HIGH)>;
		interrupt-parent = <&intc>;

4. Compile the device tree with the command:

        cd Linux_for_Tegra/sources/kernel
        make -C kernel-5.10/ ARCH=arm64 O=../kernel_out -j12 dtbs

    You will find the compiled device tree for Nvidia Jetson Orin AGX host on:

        kernel_out/arch/arm64/boot/dts/nvidia/tegra234-p3701-0000-p3737-0000.dtb


6. For the guest you will need to add to the guest's device tree root the bpmp
   with the Qemu bpmp guest VPA:

        bpmp: bpmp {
            compatible = "nvidia,tegra234-bpmp", "nvidia,tegra186-bpmp";
            virtual-pa = <0x0 0x090c0000>; 
            #clock-cells = <1>;
            #reset-cells = <1>;
            status = "okay";
        };

    Here you tell to the bpmp-guest which is the VPA (virtual-pa), that in 
    this case is 0x090c0000

8. For UARTA passthrough you will need to add the *uarta* node inside the 
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

            ...

9. Before running the VM you will need to bind the UARTA to the vfio-platform driver:

        echo vfio-platform > /sys/bus/platform/devices/3100000.serial/driver_override
        echo 3100000.serial > /sys/bus/platform/drivers/vfio-platform/bind

10. Also, you will need to allow the unsafe interrupts:

        echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts

11. Finally you can run your VM with the next Qemu command:


        /home/user/qemu-bpmp/build/qemu-system-aarch64 \
            -nographic \
            -machine virt,accel=kvm \
            -cpu host \
            -m 1G \
            -no-reboot \
            -kernel Image \
            -drive file=rootfs_ubuntu_nvidia_orin.img.raw,if=virtio,format=raw \
            -net user,hostfwd=tcp::2222-:22 -net nic \
            -device vfio-platform,host=3100000.serial \
            -dtb uarta.dtb \
            -append "rootwait root=/dev/vda console=ttyAMA0"

12. To test the UARTA you can send a *"123"* string with the next command from
    the VM:

      echo 123 > /dev/ttyTHS0

    The UARTA (or UART1 in the full package) in the Nvidia Jetson Orin AGX is 
    connected to the external  40-pin connector. You can connect a USB to UART 
    as follows:

        Nvidia Orin AGX      USB to UART
        40 pin connector       cable
        ----------------------------------
        6  (GND)              Black (GND)
        8  (UART1_TX)         Yellow (RX)
        10 (UART1_RX)         Orange (TX)

    Then you can get the output of what you sent on your PC from a serial
    terminal:

        picocom -b 9600 /dev/ttyUSB0
    
