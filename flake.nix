# Copyright 2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{
  description = ''
    The BPMP (Boot and Power Management Processor) virtualization allows the
    virtual machines (VMs) to access the BPMP resources (such as specific
    devices' clocks and resets) in order to passthrough platform devices where the
    drivers requires control of resets and clock configurations.

    - Host module: `bpmp-virt.nixosModules.bpmp-virt-host`

    This module enables boot and power management processor (BPMP)
    virtualization on the host.

    - Guest module: `bpmp-virt.nixosModules.bpmp-virt-guest`

    This module enables boot and power management processor (BPMP)
    virtualization on the guest.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    systems = with flake-utils.lib.system; [
      x86_64-linux
      aarch64-linux
    ];
  in
    flake-utils.lib.eachSystem systems (system: {
      formatter = nixpkgs.legacyPackages.${system}.alejandra;
    })
    // {
      nixosModules = {
        bpmp-virt-host = ./modules/bpmp-virt-host;
        bpmp-virt-guest = ./modules/bpmp-virt-guest;
      };
    };
}
