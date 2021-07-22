#!/usr/bin/env bash
# set -x

function print_usage() {
    echo "Usage:"
    echo "$(basename "${0}") [options]"
    echo ""
    echo "options:"
    echo " -b --build <type>                 Build Type [Debug/DebugOptimized/ReleaseSymbols/Release/Production]"
    echo " -c --cmake-toolchain-file <file>  Specify toolchain file for cmake"
    echo " -d --debug-id <ssh id>            Location of a predefined rsa key for ssh"
    echo " -i --install-location <path>      Location to install binaries"
    echo " -l --log                          Log installation to file \"install-log\""
    echo " -o --only-install                 Only pre-install predefined components"
    echo " -r --root-location <path>         Location to use as a project root"
    echo " -t --tools-location <path>        Location to install the Thunder tools/generators"
    echo " -h --help                         Help"
}

function parse_args(){
    while [[ "$#" -gt 0 ]]; do
        case "${1}" in
            -b|--build-type)
              BUILD_TYPE="$2"
              shift # past value
              ;;
            -c|--cmake-toolchain-file)
              TOOLCHAIN_FILE="$2"
              shift # past value
              ;;
            -d|--debug-id)
              DEBUG_ID="$2"
              shift # past value
              ;;
            -i|--install-location)
              INSTALL_LOCATION="$2"
              shift # past value
              ;;
            -l|--log)
              STDOUT="install-log"
              ;;
            -o|--only-install)
              INSTALL_ONLY="Y"
              ;;
            -r|--root-location)
              ROOT_LOCATION="$2"
              shift # past value
              ;;
            -t|--tools-location)
              TOOLS_LOCATION="$2"
              shift # past value
              ;;
            -h|--help)
              print_usage
              false
              return
              ;;
            *)    # unknown option
              POSITIONAL+=("$1") # save it in an array for later
              ;;
        esac
        shift # next argument
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters

}

function cmake-install(){
    if [[ -f $TOOLCHAIN_FILE ]]
    then
       THUNDER_TOOLCHAIN=-DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}"    
    elif [[ -f "${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}g++" ]] && [[ -f "${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}gcc" ]]
    then
        THUNDER_TOOLCHAIN=' -DCMAKE_C_COMPILER="${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}gcc"'
        THUNDER_TOOLCHAIN+=' -DCMAKE_CXX_COMPILER="${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}g++"'
        THUNDER_TOOLCHAIN+=' -DCMAKE_PROGRAM_PATH="${BUILD_TOOLS_LOCATION}"'
        if [[ "x$SYS_ROOT" != "x" ]]
        then
            THUNDER_TOOLCHAIN+=' -DCMAKE_SYSROOT="${SYS_ROOT}"'
            THUNDER_TOOLCHAIN+=' -DCMAKE_FIND_ROOT_PATH="${SYS_ROOT}"'
        fi
    fi
   
    cmake -Hsource/$1 -Bbuild/${1///} $THUNDER_TOOLCHAIN -DCMAKE_MODULE_PATH=${TOOLS_LOCATION} -DCMAKE_INSTALL_PREFIX=${TOOLS_LOCATION} -DGENERIC_CMAKE_MODULE_PATH=${TOOLS_LOCATION} &> $STDOUT
    cmake --build build/${1///} --target install &> $STDOUT
}

function pre-install(){
    for c in "${PREINSTALL_COMPONENTS[@]}"
    do
    	if [[ -d source/$c ]]
    	then
    	   echo "Installing $c... "
    	   cmake-install $c
    	fi
    done
    
    if [ $INSTALL_ONLY = "Y" ]
    then
    	false
    fi
}

function check_env(){
    local DEFAULT=""

    if [ "x$BUILD_TYPE" = "x" ]
    then
    	DEFAULT="Debug"
        read -e -p "Set Build type [$DEFAULT]: " USER_INPUT
        BUILD_TYPE="${USER_INPUT:-$DEFAULT}"
    fi
    
    if [ "x$ROOT_LOCATION" = "x" ]
    then
    	DEFAULT="${PWD}"
        read -e -p "Project root location [$DEFAULT]: " USER_INPUT
        ROOT_LOCATION="${USER_INPUT:-$DEFAULT}"
    fi
    
    if [ "x$INSTALL_LOCATION" = "x" ]
    then
    	DEFAULT="${ROOT_LOCATION}/install"
        read -e -p "Thunder install location [$DEFAULT]: "  USER_INPUT
        INSTALL_LOCATION="${USER_INPUT:-$DEFAULT}"
    fi
    
    if [ "x$TOOLS_LOCATION" = "x" ]
    then
    	DEFAULT=${ROOT_LOCATION}/host-tools
        read -e -p "Thunder host tools install location[$DEFAULT]: " USER_INPUT
        TOOLS_LOCATION="${USER_INPUT:-$DEFAULT}"
    fi

    if [ "x$TOOLCHAIN_FILE" = "x" ]
    then
        DEFAULT="N"
        read -e -p "Use Toolchain File?: " USER_INPUT
        TOOLCHAIN_FILE="${USER_INPUT:-$DEFAULT}"
    fi

    if ! [[ -f TOOLCHAIN_FILE ]]
    then
        echo "No toolchain file."
        if [ "x$BUILD_TOOLS_LOCATION" = "x" ]
        then
            DEFAULT="/usr/bin/"
            read -e -p "toolchain build tools location [$DEFAULT]:"  USER_INPUT
            BUILD_TOOLS_LOCATION="${USER_INPUT:-$DEFAULT}"
        fi

        if [ "x$BUILD_TOOLS_PREFIX" = "xNOT_SET" ]
        then
            DEFAULT=""
            read -e -p "build tools prefix [$DEFAULT]: "  USER_INPUT
            BUILD_TOOLS_PREFIX="${USER_INPUT:-$DEFAULT}"
        fi
    fi

    check_tools

    if ! [ -f "$DEBUG_ID" ]
    then
        ssh-keygen -q -t rsa -b 4096 -C "thunder@debug.access" -N "" -f "$ROOT_LOCATION/thunder-debug-access"
        DEBUG_ID="$ROOT_LOCATION/thunder-debug-access"
        echo "Generated Debug SSH ID \'$ROOT_LOCATION/thunder-debug-access\'"
    fi

}

function sanitize_dir {
    if [[ -d $1 ]]
    then
        local dir=$(realpath "$1")
        dir+=/
        echo $dir
    fi
}

function check_tools {
    local EXPECTED_TOOLS=(
    	gcc 
    	g++
    	gdb
    )

    for TOOL in "${EXPECTED_TOOLS[@]}"
    do
        VERSION=$(${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}${TOOL} --version)

        if [[ "x${VERSION}" = "x" ]]
        then
            echo ""
            echo "ERROR: Missing $TOOL."
            echo ""
            false
        else
            echo ""
            echo "Found ${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}${TOOL}."
            echo "${VERSION}."
            echo ""
        fi
    done

    SYS_ROOT=$(${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}gcc -print-sysroot)

    IFS='-' read -r TARGET_ARCH LEFTOVER <<< $(${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}gcc -dumpmachine)
    echo "TARGET_ARCH ${TARGET_ARCH}"
}

function write_workspace(){
    THUNDER_TOOLCHAIN=""
    THUNDER_INSTALL_TARGET_PREFIX=""
    
    if [[ -f $TOOLCHAIN_FILE ]]
    then
        THUNDER_TOOLCHAIN="\"CMAKE_TOOLCHAIN_FILE\":\"${TOOLCHAIN_FILE}\","
    elif [[ -f "${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}g++" ]] && 
         [[ -f "${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}gcc" ]]
    then
        THUNDER_TOOLCHAIN="\"CMAKE_C_COMPILER\":\"${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}gcc\","
        THUNDER_TOOLCHAIN+="\"CMAKE_CXX_COMPILER\":\"${BUILD_TOOLS_LOCATION}${BUILD_TOOLS_PREFIX}g++\","
        THUNDER_TOOLCHAIN+="\"CMAKE_PROGRAM_PATH\": \"${BUILD_TOOLS_LOCATION}\","
        if [[ "x$SYS_ROOT" != "x" ]]
        then
            THUNDER_TOOLCHAIN+="\"CMAKE_SYSROOT\": \"${SYS_ROOT}\","
            THUNDER_TOOLCHAIN+="\"CMAKE_FIND_ROOT_PATH\": \"${SYS_ROOT}\","
        else
            THUNDER_INSTALL_TARGET_PREFIX="$INSTALL_LOCATION"
        fi
    fi

    write_vscode_workspace
}

function write_vscode_workspace(){
    local timestamp=`date +'%s'`
    local tmpws="${timestamp}-Thunder.code-workspace"
    local ws=${USER}-Thunder.code-workspace
    
    sed \
        -e "s|@THUNDER_TOOLCHAIN@|${THUNDER_TOOLCHAIN}|g" \
        -e "s|@THUNDER_INSTALL_LOCATION@|${INSTALL_LOCATION}|g" \
        -e "s|@THUNDER_INSTALL_TARGET_PREFIX@|${THUNDER_INSTALL_TARGET_PREFIX}|g" \
        -e "s|@THUNDER_TOOLS_LOCATION@|${TOOLS_LOCATION}|g" \
        -e "s|@THUNDER_BUILD_TYPE@|${BUILD_TYPE}|g" \
        -e "s|@THUNDER_PROJECT_ROOT_LOCATION@|${ROOT_LOCATION}|g" \
        -e "s|@BUILD_TOOLS_PREFIX@|${BUILD_TOOLS_PREFIX}|g" \
        -e "s|@BUILD_TOOLS_LOCATION@|${BUILD_TOOLS_LOCATION}|g" \
        -e "s|@SYS_ROOT@|${SYS_ROOT}|g" \
        -e "s|@THUNDER_DEBUG_ID@|${DEBUG_ID}|g" \
        source/workspaces/Thunder.code-workspace > ${tmpws}

    if [[ -f ${ws} ]]
    then
    	DIFF=`diff ${ws} ${tmpws}`
        
        if [[ "x${DIFF}" != "x" ]]
        then
           diff -Nau --color ${ws} ${tmpws}
           echo "Found existing workspace [${ws}]"
           read  -p "Overwrite this workspace? (y/N) " WRITE
           WRITE=${WRITE:-N}
        fi
    else
    	WRITE=Y
    fi
    
    case $WRITE in  
        y|Y)
            echo "Writing ${ws}" 
	    cp ${tmpws} ${ws}
            ;; 
        *) 
            echo "Keeping existing workspace ${ws}." 
            ;; 
    esac
    
    rm ${tmpws}
}

function write_cache() {
    echo "Writing build environment cache"
    
    echo "#GENERATED FILE, DO NOT EDIT" > .cache
    echo "BUILD_TYPE=\"$BUILD_TYPE\"" >> .cache
    echo "ROOT_LOCATION=\"$ROOT_LOCATION\"" >> .cache
    echo "INSTALL_LOCATION=\"$INSTALL_LOCATION\"" >> .cache
    echo "TOOLS_LOCATION=\"$TOOLS_LOCATION\"" >> .cache
    echo "TOOLCHAIN_FILE=\"$TOOLCHAIN_FILE\"" >> .cache
    echo "BUILD_TOOLS_PREFIX=\"$BUILD_TOOLS_PREFIX\"" >> .cache
    echo "BUILD_TOOLS_LOCATION=\"$BUILD_TOOLS_LOCATION\"" >> .cache
    echo "DEBUG_ID=\"$DEBUG_ID\"" >> .cache

    show_env
}

function read_cache() {
    if [[ -f .cache ]]
    then
        echo "Reading cached build environment"
        source .cache
    fi
}

function show_env(){
    read_cache

    echo "Build environment:"
    echo " - Type:                  ${BUILD_TYPE}"
    echo " - Project root location: ${ROOT_LOCATION}"
    echo " - Install location       ${INSTALL_LOCATION}"
    echo " - Thunder tools:         ${TOOLS_LOCATION}"
    if [ "x$DEBUG_ID" != "x" ]
    then
        echo " - Debug id:              ${DEBUG_ID}"
        echo "   usage on target:"
        echo "   ssh-copy-id -i  ${DEBUG_ID}.pub <user>@<target-ip>"
    fi
    if [[ -f $TOOLCHAIN_FILE ]]
    then
    echo " - CMake toolchain file:  ${TOOLCHAIN_FILE}"
    fi
    if [[ -d $BUILD_TOOLS_LOCATION ]]
    then
    echo " - Toolchain location:    ${BUILD_TOOLS_LOCATION}"
    echo " - Toolchain prefix:      ${BUILD_TOOLS_PREFIX}"
    fi
} 


function main() {
    POSITIONAL=()
    INSTALL_ONLY="N"
    WRITE="N"
    
    # silence the install
    STDOUT="/dev/null"
    
    # Initialize variables
    DEBUG_ID=""
    BUILD_TOOLS_LOCATION=""
    BUILD_TOOLS_PREFIX="NOT_SET"
    BUILD_TYPE=""
    ROOT_LOCATION=""
    INSTALL_LOCATION=""
    TOOLS_LOCATION=""
    TOOLCHAIN_FILE=""
    SYS_ROOT=""
    
    # only if the path exists in sources dir
    PREINSTALL_COMPONENTS=(
    	Thunder/Tools 
    	libprovision
    	ThunderUI
    )
    
    read_cache

    parse_args $@ && check_env && pre-install && write_workspace && write_cache

    #true
}

main $@
