{...}: {
  nixpkgs.overlays = [(import ../../overlays/qemu)];

  boot.kernelPatches = [
    {
      name = "Added Configurations to Support Vda";
      patch = ./patches/0001-added-configurations-to-support-vda.patch;
    }
    {
      name = "Vfio_platform Reset Required False";
      patch = ./patches/0002-vfio_platform-reset-required-false.patch;
    }
    {
      name = "Bpmp Support Virtualization";
      patch = ./patches/0003-bpmp-support-bpmp-virt.patch;
    }
    {
      name = "Bpmp Virt Drivers";
      patch = ./patches/0004-bpmp-virt-drivers.patch;
    }
    {
      name = "Bpmp Overlay";
      patch = ./patches/0005-bpmp-overlay.patch;
    }
  ];

  boot.kernelParams = ["vfio_iommu_type1.allow_unsafe_interrupts=1"];
}
