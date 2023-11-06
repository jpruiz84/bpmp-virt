{
  lib,
  pkgs,
  ...
}: {
  imports = [../bpmp-virt-common];

  boot.kernelPatches = [
    {
      name = "Bpmp virtualization host proxy device tree";
      patch = ./patches/bpmp-host-proxy-dts.patch;
    }
    # FIXME: This patch doesn't wortk as is.
    # {
    #   name = "Bpmp virtualization host uarta device tree";
    #   patch = ./patches/bpmp-host-uarta-dts.patch;
    # }
    {
      name = "Bpmp virtualization host kernel configuration";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        VFIO_PLATFORM = yes;
        TEGRA_BPMP_HOST_PROXY = yes;
      };
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
}
