(prev: {
  qemu_kvm = prev.qemu_kvm.overrideAttrs (prev: {
    patches =
      prev.patches
      ++ [
        ./patches/0001-qemu-v8.0.5_bpmp-virt.patch
      ];
  });
})
