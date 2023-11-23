{lib, ...}: {
  imports = [../bpmp-virt-common];

  boot.kernelPatches = [
    {
      name = "BPMP virt enable guest";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        VFIO_PLATFORM = yes;
        TEGRA_BPMP_GUEST_PROXY = yes;
      };
    }
  ];

  hardware.deviceTree = {
    enable = true;
    name = "bpmp-guest.dtb";
  };
}
