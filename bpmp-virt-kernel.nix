# Copyright 2022-2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{ kernel, ... }:
kernel.override {
  kernelPatches = [
	{
		name = "VFIO reset patch";
		patch = ./0002-vfio_platform-reset-required-false.patch;
  	}
	{
		name = "BPMP support patch";
		patch = ./0003-vfio_platform-reset-required-false.patch;
  	}
  ];

  extraConfig = ''
    CONFIG_HOTPLUG_PCI=y
	CONFIG_PCI_DEBUG=y
	CONFIG_PCI_HOST_GENERIC=y
	CONFIG_PCI_STUB=y
	CONFIG_VFIO=y
	CONFIG_VFIO_IOMMU_TYPE1=y
	CONFIG_VIRTIO_MMIO=y
	CONFIG_VIRTIO_PCI=y
	CONFIG_HOTPLUG_PCI_ACPI=y
	CONFIG_PCI_HOST_COMMON=y
  '';
}