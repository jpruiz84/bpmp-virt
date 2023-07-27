# Copyright 2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ config, lib, ... }:

let
  bpmpHostProxyOverlay = (final: prev: {
    bpmp_host_proxy = prev // {
      compatible = "nvidia,bpmp-host-proxy";
      allowed-clocks = [ "TEGRA234_CLK_UARTA" "TEGRA234_CLK_PLLP_OUT0" ];
      allowed-resets = [ "TEGRA234_RESET_UARTA" ];
      status = "okay";
    };
  });
in

{
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
  hardware.deviceTree.overlays = [ bpmpHostProxyOverlay ];

  # The rest of your NixOS configuration...
}
