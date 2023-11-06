(prev: {
  qemu_kvm = prev.qemu_kvm.overrideAttrs (prev: {
    patches =
      prev.patches
      ++ [
        # FIXME: This patch doesn't work with the qemu version from Nixpkgs.
        ./patches/qemu-v8.1.0_bpmp-virt.patch
      ];
  });
})
