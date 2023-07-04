# Copyright 2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{lib, ...}: {
  imports = [
    ./bpmp-virt-common.nix
  ];
  boot.kernelPatches = [
    {
      name = "BPMP virt enable guest";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        TEGRA_BPMP_GUEST_PROXY = yes;
      };
    }
  ];
}
