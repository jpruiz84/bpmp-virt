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
- Intercepts the tegra_bpmp_transfer function to use the tegra_bpmp_transfer_redirect
  from the BPMP guest.
- Reads the *virtual-pa* node from the guest device tree to pass the BPMP VMM guest 
  VPA to the BPMP guest proxy module.

The modifications to the BPMP driver are included in the patch: 

    0001-bpmp-support-bpmp-virt.patch


# Installation for Nvidia JetPack 36.2

1. Get ready a development environment with Ubuntu 22.04 on your Nvidia Orin.

2. Download the Nvidia L4T Driver Package (BSP) version 36.21:
        
        wget https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v2.0/release/jetson_linux_r36.2.0_aarch64.tbz2

3. Extract the Nvidia L4T Driver Package (BSP):

        sudo tar xpf jetson_linux_r36.2.0_aarch64.tbz2

4. Sync the source code:

        cd Linux_for_Tegra
        ./source_sync.sh -t jetson_36.2

5. Clone this repository to Linux_for_Tegra/sources/kernel

        cd source/kernel
        git clone git@github.com:jpruiz84/bpmp-virt.git

6. Create the symbolic links:

        cd ./kernel-jammy-src/drivers/firmware/tegra
        ln -s ../../../../bpmp-virt/drivers/bpmp-guest-proxy ./bpmp-guest-proxy
        ln -s ../../../../bpmp-virt/drivers/bpmp-host-proxy ./bpmp-host-proxy


6. Apply the patches from this repo with:

        cd Linux_for_Tegra/sources/kernel/kernel-5.10
        git apply ../bpmp-virt/*.patch
    

8. Add the kernel configurations:

        CONFIG_TEGRA_BPMP_GUEST_PROXY=y
        CONFIG_TEGRA_BPMP_HOST_PROXY=y



## Device tree


1. For the host, add the bpmp_host_proxy node:

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

    **Note:** you can also define the allowed power domains that are needed
    by some devices like the GPU:

          allowed-power-domains = <TEGRA234_POWER_DOMAIN_DISP
                    TEGRA234_POWER_DOMAIN_GPU>;  



2. For the guest you will need to add to the guest's device tree root the bpmp
   with the Qemu bpmp guest VPA:

        bpmp: bpmp {
            compatible = "nvidia,tegra234-bpmp", "nvidia,tegra186-bpmp";
            virtual-pa = <0x0 0x090c0000>; 
            #clock-cells = <1>;
            #reset-cells = <1>;
            #power-domain-cells = <1>;
            status = "okay";
        };

    Here you tell to the bpmp-guest which is the VPA (virtual-pa), that in 
    this case is 0x090c0000




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

    Also, you will need to add the alias for the uarta node.

        aliases {
          serial0 = &uarta;
        }; 

8. Compile the amended guest Device Tree:

		dtc -Idts -Odtb virt.dts -o virt.dtb

9. Also, you will need to allow unsafe interrupts, either type as sudo

		echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts

	or add this kernel boot parameter in /boot/extlinux/extlinux.conf

		vfio_iommu_type1.allow_unsafe_interrupts=1

	After reboot, you can check the status with

		cat /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts

	or with

		modinfo vfio_iommu_type1

10. Before running the VM you will need to bind the UARTA to the vfio-platform driver:

        echo vfio-platform > /sys/bus/platform/devices/3100000.serial/driver_override
        echo 3100000.serial > /sys/bus/platform/drivers/vfio-platform/bind

	You can check if binding is successful with:

		ls -l /sys/bus/platform/drivers/vfio-platform/3100000.serial

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
    
