# Copyright 2023 TII (SSRC) and the Ghaf contributors
# SPDX-License-Identifier: Apache-2.0
{lib, ...}: {
  environment.systemPackages = [ pkgs.dtc ];
  boot.kernelPatches = [
    {
      name = "BPMP Driver patch";
      patch = ../0001-Virtual-BPMP-drivers.patch;
    }
    {
      name = "VFIO reset patch";
      patch = ../0002-vfio_platform-reset-required-false.patch;
    }
    {
      name = "BPMP support patch";
      patch = ../0003-bpmp-support-bpmp-virt.patch;
    }
    {
      name = "BPMP kernel configuration";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        CONFIG_HOTPLUG_PCI = yes;
        CONFIG_PCI_DEBUG = yes;
        CONFIG_PCI_HOST_GENERIC = yes;
        CONFIG_PCI_STUB = yes;
        CONFIG_VFIO = yes;
        CONFIG_VFIO_IOMMU_TYPE1 = yes;
        CONFIG_VIRTIO_MMIO = yes;
        CONFIG_VIRTIO_PCI = yes;
        CONFIG_HOTPLUG_PCI_ACPI = yes;
        CONFIG_PCI_HOST_COMMON = yes;
      };
    }
  ];
}
