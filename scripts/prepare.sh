#!/usr/bin/env bash
#. environment
#
#-DCMAKE_TOOLCHAIN_FILE="/media/bram/Projects/build-env/buildroot-rpi/output/host/usr/share/buildroot/toolchainfile.cmake"
export THUNDER_INSTALL_ROOT=$PWD/install
export LD_LIBRARY_PATH="$THUNDER_INSTALL_ROOT/install/usr/lib:$LD_LIBRARY_PATH"
export PATH="$THUNDER_INSTALL_ROOT/install/usr/bin;$THUNDER_INSTALL_ROOT/install/usr/sbin:$PATH"

echo "THUNDER_INSTALL_ROOT $THUNDER_INSTALL_ROOT"

cmake -Hsource/Tools -Bbuild/ThunderTools  -DCMAKE_MODULE_PATH=${THUNDER_INSTALL_ROOT}/tools -DCMAKE_INSTALL_PREFIX=${THUNDER_INSTALL_ROOT}/usr -DGENERIC_CMAKE_MODULE_PATH=${THUNDER_INSTALL_ROOT}/tools
cmake --build build/ThunderTools --target install