# Copyright 2022-2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0

/* Kernel change must be done here and in the default.nix file in this dir.
    E.g. for specific kernel version use: super.linuxPackages_6_1.callPackage
*/

{ self }: {
  bpmp-virt-overlay =  self: super: {
    bpmp-virt-kernel = super.linuxPackages_5_1.callPackage ./bpmp-virt-kernel.nix {};
  };
}