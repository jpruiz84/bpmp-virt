{
  config,
  lib,
  pkgs,
  ...
}: {
  boot.kernelPatches = [
    {
      name = "Added Configurations to Support Vda";
      patch = ./0001-added-configurations-to-support-vda.patch;
    }
    {
      name = "Vfio_platform Reset Required False";
      patch = ./0002-vfio_platform-reset-required-false.patch;
    }
    {
      name = "Bpmp Support Virtualization";
      patch = ./0003-bpmp-support-bpmp-virt.patch;
    }
    {
      name = "Bpmp Virt Drivers";
      patch = ./0004-bpmp-virt-drivers.patch;
    }
    {
      name = "Bpmp Host Proxy Dts";
      patch = ./0005-bpmp-host-proxy-dts.patch;
    }
  ];

  systemd.services.bindUARTA = {
    description = "Bind UARTA to the vfio-platform driver";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c "echo vfio-platform > /sys/bus/platform/devices/3100000.serial/driver_override"
        ${pkgs.bash}/bin/bash -c "echo 3100000.serial > /sys/bus/platform/drivers/vfio-platform/bind"
      '';
    };
  };

  systemd.services.allowUnsafeInterrupts = {
    description = "Allow unsafe interrupts for vfio";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts'";
    };
  };
}
