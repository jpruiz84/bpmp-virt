IMG=$1
FS=$2

qemu-system-aarch64 \
    -nographic \
    -machine virt,accel=kvm \
    -cpu host \
    -m 1G \
    -no-reboot \
    -kernel $IMG \
    -drive file=$FS,if=virtio,format=qcow2 \
    -net user,hostfwd=tcp::2222-:22 -net nic \
    # -device vfio-platform,host=3100000.serial \
    # -dtb virt.dtb \
    -append "rootwait root=/dev/vda console=ttyAMA0"
