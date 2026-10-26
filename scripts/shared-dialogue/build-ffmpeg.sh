#!/usr/bin/env bash
set -euo pipefail
export PATH="$(/usr/bin/cygpath -u "$SD_VC_BIN"):/usr/bin:$PATH"
source_dir=$(cygpath -u "$1")
build_dir=$(cygpath -u "$2")
prefix=$(cygpath -m "$3")
make=$(cygpath -u "$4")
jobs=$5
cd "$build_dir"
recipe_hash=$(sha256sum "$0" | cut -d' ' -f1)
if [[ ! -f recipe.sha256 || $(cat recipe.sha256) != "$recipe_hash" ]]; then
bash ./configure --toolchain=msvc --arch=x86_64 --target-os=win64 \
    --prefix="$prefix" --enable-shared --disable-static --disable-autodetect \
    --enable-zlib --extra-cflags="-I$prefix/include" --extra-ldflags="-LIBPATH:$prefix/lib" \
    --disable-programs --disable-doc --disable-debug --disable-network \
    --disable-avdevice --disable-avfilter --disable-postproc \
    --disable-encoders --disable-muxers --disable-hwaccels --disable-x86asm \
    --disable-gpl --disable-version3 --disable-nonfree
printf '%s\n' "$recipe_hash" > recipe.sha256
fi
"$make" -r -j"$jobs" SHELL="$SD_SHELL"
"$make" -r install SHELL="$SD_SHELL"
