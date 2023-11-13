{
  lib,
  pkgs,
  ...
}: {
  imports = [../bpmp-virt-common];

  boot.kernelPatches = [
    {
      name = "Bpmp virtualization host proxy device tree";
      patch = ./patches/0001-bpmp-host-proxy-dts.patch;
    }
    {
      name = "Bpmp virtualization host uarta device tree";
      patch = ./patches/bpmp-host-uarta-dts.patch;
    }
    {
      name = "Bpmp virtualization host kernel configuration";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        VFIO_PLATFORM = yes;
        TEGRA_BPMP_HOST_PROXY = yes;
      };
    }
  ];

  environment.systemPackages = with pkgs; [
    qemu
    dtc
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
}
