(final: prev: {
  qemu = prev.qemu.overrideAttrs (_final: prev: {
    patches =
      prev.patches
      ++ [
        ./patches/0001-qemu-v8.0.5_bpmp-virt.patch
      ];
  });
})
