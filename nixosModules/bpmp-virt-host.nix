# Copyright 2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ config, lib, ... }: {
  imports = [
    ./bpmp-virt-common.nix
  ];

  boot.kernelPatches = [
    {
      name = "BPMP virt enable host";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        TEGRA_BPMP_HOST_PROXY = yes;
      };
    }
  ];

  # Apply the device tree overlay
  hardware.deviceTree = {
    enable = true;
    name = "./bpmp-host-proxy.dts";
  };
}
