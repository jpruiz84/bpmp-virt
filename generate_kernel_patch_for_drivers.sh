#!/usr/bin/env bash

set -euo pipefail

[[ ! -d linux-tegra-5.10 ]] && git clone https://github.com/OE4T/linux-tegra-5.10 --branch oe4t-patches-l4t-r35.3.ga --single-branch linux-tegra-5.10

pushd linux-tegra-5.10
  git reset --hard
  git clean -xdf

  cp -Rv ../drivers/bpmp-{guest,host}-proxy ./drivers/
  cat ../drivers/Kconfig >> drivers/Kconfig
  cat ../drivers/Makefile >> drivers/Makefile

  git add .
  git commit -m "Virtual BPMP drivers"
  git format-patch -k -1 -o ..
popd
