#!/usr/bin/env bash

function prepare() {
    #-DCMAKE_TOOLCHAIN_FILE="/media/bram/Projects/build-env/buildroot-rpi/output/host/usr/share/buildroot/toolchainfile.cmake"
    export THUNDER_PROJECT_ROOT_LOCATION="${PWD}"
    export THUNDER_BUILD_TYPE="Debug"
    export THUNDER_TOOLS_LOCATION="${THUNDER_PROJECT_ROOT_LOCATION}/host-tools"

    export LD_LIBRARY_PATH="${THUNDER_PROJECT_ROOT_LOCATION}/install/usr/lib:${LD_LIBRARY_PATH}"
    export PATH="${THUNDER_PROJECT_ROOT_LOCATION}/install/usr/bin:${THUNDER_PROJECT_ROOT_LOCATION}/install/usr/sbin:${PATH}"

    # install host tooling
    cmake -Hsource/Tools -Bbuild/ThunderHostTools  -DCMAKE_MODULE_PATH=${THUNDER_TOOLS_LOCATION} -DCMAKE_INSTALL_PREFIX=${THUNDER_TOOLS_LOCATION} -DGENERIC_CMAKE_MODULE_PATH=${THUNDER_TOOLS_LOCATION}
    cmake --build build/ThunderHostTools --target install

    echo "Build environment:"
    echo " - Type:                 ${THUNDER_BUILD_TYPE}"
    echo " - Project root:         ${THUNDER_PROJECT_ROOT_LOCATION}"
    echo " - Host tools:           ${THUNDER_TOOLS_LOCATION}"
}

[[ $_ != $0 ]] && prepare || echo "OOOOOPS... You're running this script, but it should be 'sourced'. Exiting now."
