# Copyright 2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  ...
}: {
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

  hardware.deviceTree.enable = true;
  # Apply the device tree overlay
  hardware.deviceTree.overlays = [
    {
      name = "bpmp-host-proxy";
      dtboFile = ./bpmp-host-proxy.dtbo;
      # dtsFile = ./bpmp-host-proxy.dts;
      # dtsText = ''
      #   /dts-v1/;
      #   / {
      #   compatible="nvidia,tegra186";
      #   bpmp_host_proxy: bpmp_host_proxy {
      #   				compatible = "nvidia,bpmp-host-proxy";
      #   				allowed-clocks = <155
      #                        102>;
      #   				allowed-reset = <100>;
      #           status = "okay";
      #       };
      #   };
      # '';
    }
  ];
}
