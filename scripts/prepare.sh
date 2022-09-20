#!/usr/bin/env bash
# set -x
log_levels=(MESSAGE ERROR INFO DEBUG)

function print_usage() {
    echo "Usage:"
    echo "$(basename "${0}") [options]"
    echo ""
    echo "Options:"
    echo " -b --build <type>                 Build Type [Debug/DebugOptimized/ReleaseSymbols/Release/Production]"
    echo " -c --cmake-toolchain-file <file>  Specify toolchain file for cmake"
    echo " -d --debug-id <ssh id>            Location of a predefined rsa key for ssh"
    echo " -i --install-location <path>      Location to install binaries"
    echo " -l --log <file>                   Log to <file>"
    echo " -o --only-install                 Only pre-install predefined components"
    echo " -r --root-location <path>         Location to use as a project root"
    echo " -t --tools-location <path>        Location to install the Thunder tools/generators"
    echo ""
    echo "Script options"
    echo " -V                                Print log on screen, add more V's to increase level"
    echo " -C --clear-cache                  Clear the cache for a fresh start"
    echo " -S --show-environment             Show the current environment from cache"
    echo " -h --help                         Show this message"
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
              LOG="$2"
              if [[ -n "${LOG}" ]]
              then
                echo "Run $(date)" > $LOG
              fi
              shift
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
            -V*)
              local ulevel="${1//[^V]}"

              ((VERBOSE=VERBOSE+${#ulevel}))

              if [[ ${VERBOSE} -gt ${#log_levels[@]} ]]
              then
                ((VERBOSE=${#log_levels[@]}-1))
              fi
              ;;
            -C|--clear-cache)
              if [[ -f .cache ]]
              then
                rm .cache
                reset-cache
              fi
              ;;
            -R|--read-cache)
              show_env
              false
              return
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

    log DEBUG "Verbosity set to "${log_levels[${VERBOSE}]}""
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

    log DEBUG "CMake Install\n - source dir: '${1}'\n - build dir '${2}'\n - install prefix: '${3}'"

    build_output=`sh -c "cmake \
        -S ${1} -B ${2} \
        --no-warn-unused-cli \
        ${THUNDER_TOOLCHAIN} \
        -DCMAKE_MODULE_PATH=${TOOLS_LOCATION} \
        -DCMAKE_INSTALL_PREFIX=${3} \
        -DGENERIC_CMAKE_MODULE_PATH=${TOOLS_LOCATION}" 2>&1`
    log INFO "${build_output}"

    install_output=`cmake --build ${2} --target install 2>&1`
    log INFO "${install_output}"
}

function pre-install(){
    # only if the path exists in sources dir
    # <path>:<build dir>:<install location>
    PREINSTALL_COMPONENTS=(
    	"Thunder/Tools:ThunderTools:${TOOLS_LOCATION}"
    	"libprovision:libprovision:${INSTALL_LOCATION}"
    	"ThunderUI:ThunderUI:${INSTALL_LOCATION}"
    )

    for entry in "${PREINSTALL_COMPONENTS[@]}"
    do
        IFS=':' read -r source_dir build_dir dest_dir <<< ${entry}

    	if [[ -d source/$source_dir ]]
    	then
    	   log MESSAGE "Installing ${source_dir} to $dest_dir... "
    	   cmake-install "source/${source_dir}" "build/${build_dir}" "${dest_dir}"
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
        read -e -p "Build type [$DEFAULT]: " USER_INPUT
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
        read -e -p "Thunder host tools install location [$DEFAULT]: " USER_INPUT
        TOOLS_LOCATION="${USER_INPUT:-$DEFAULT}"
    fi

    if [ "x$TOOLCHAIN_FILE" = "x" ]
    then
        DEFAULT="N"
        read -e -p "Toolchain File (optional): " USER_INPUT
        TOOLCHAIN_FILE="${USER_INPUT:-$DEFAULT}"
    fi

    if [[ -f $TOOLCHAIN_FILE ]]
    then
        log MESSAGE "read $TOOLCHAIN_FILE"
        local build="/tmp/thunder_setup_$(date +'%s')"
        local script=$(realpath ${0})
        local script_root=$(dirname ${script})

        mkdir $build

        cmake-install "$script_root/cmake" "$build" "$build"

        if [[ -f "$build/cmake-environment" ]]
        then
            source "$build/cmake-environment"

            local prefix=$(basename "${_CXX_COMPILER}")
            local tool="${prefix##*-}"

            BUILD_TOOLS_LOCATION=$(dirname "${_CXX_COMPILER}")
            BUILD_TOOLS_PREFIX="${prefix%${tool}}"

            log DEBUG "BUILD_TOOLS_LOCATION: ${BUILD_TOOLS_LOCATION}"
            log DEBUG "BUILD_TOOLS_PREFIX: ${BUILD_TOOLS_PREFIX}"

            check_tools
        else
            BUILD_TOOLS_LOCATION="<NOT_FOUND>"
            BUILD_TOOLS_PREFIX="<NOT_FOUND>"
            SYS_ROOT="<NOT_FOUND>"
        fi

        rm -rf "$build"
    else
        if [ "x$BUILD_TOOLS_LOCATION" = "x" ]
        then
            DEFAULT="/usr/bin/"
            read -e -p "Build tools location [$DEFAULT]:"  USER_INPUT
            BUILD_TOOLS_LOCATION="${USER_INPUT:-$DEFAULT}"
        fi

        if [ "x$BUILD_TOOLS_PREFIX" = "xNOT_SET" ]
        then
            DEFAULT=""
            read -e -p "Build tools prefix [$DEFAULT]: "  USER_INPUT
            BUILD_TOOLS_PREFIX="${USER_INPUT:-$DEFAULT}"
        fi

        check_tools
    fi

    if ! [ -f "$DEBUG_ID" ]
    then
        ssh-keygen -q -t ed25519 -C "thunder@debug.access" -N "" -f "$ROOT_LOCATION/thunder-debug-access"
        DEBUG_ID="$ROOT_LOCATION/thunder-debug-access"
        log MESSAGE "Generated Debug SSH ID '$ROOT_LOCATION/thunder-debug-access'"
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
        VERSION=$(${BUILD_TOOLS_LOCATION}/${BUILD_TOOLS_PREFIX}${TOOL} --version)

        if [[ "x${VERSION}" = "x" ]]
        then
            log ERROR "Missing $TOOL.\n"
            false
        else
            log INFO "Found ${BUILD_TOOLS_LOCATION}/${BUILD_TOOLS_PREFIX}${TOOL}.\n${VERSION}.\n"
        fi
    done

    local TOOL_GCC="${BUILD_TOOLS_LOCATION}/${BUILD_TOOLS_PREFIX}gcc"

    SYS_ROOT=$(${TOOL_GCC} -print-sysroot)
    log DEBUG "SYS_ROOT ${SYS_ROOT}"
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
    local tf=Thunder.code-workspace
    local timestamp=`date +'%s'`
    local tmpws="${timestamp}-${tf}"
    local ws=${USER}-${tf}

    local template=`find -name ${tf}`

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
        ${template} > ${tmpws}

    if [[ -f ${ws} ]]
    then
    	DIFF=`diff ${ws} ${tmpws}`

        if [[ "x${DIFF}" != "x" ]]
        then
           diff -Nau --color ${ws} ${tmpws}
           log MESSAGE "Found existing workspace [${ws}]"
           read  -p "Overwrite this workspace? (y/N) " WRITE
           WRITE=${WRITE:-N}
        fi
    else
    	WRITE=Y
    fi

    case $WRITE in
        y|Y)
            log MESSAGE "Writing ${ws}"
            cp ${tmpws} ${ws}
            ;;
        *)
            log MESSAGE "Keeping existing workspace ${ws}."
            ;;
    esac

    rm ${tmpws}
}

function write_cache() {
    log DEBUG "Writing build environment cache"

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
        log DEBUG "Reading cached build environment"
        source .cache
    fi
}

function show_env(){
    read_cache

    local message="Build environment:\n"
    message+=" - Type:                  ${BUILD_TYPE}\n"
    message+=" - Project root location: ${ROOT_LOCATION}\n"
    message+=" - Install location       ${INSTALL_LOCATION}\n"
    message+=" - Thunder tools:         ${TOOLS_LOCATION}\n"
    if [ "x$DEBUG_ID" != "x" ]
    then
        message+=" - Debug id:              ${DEBUG_ID}\n"
        message+="   usage on target:\n"
        message+="   ssh-copy-id -i  ${DEBUG_ID}.pub <user>@<target-ip>\n"
        message+="   ssh <user>@<target-ip> 'mkdir -p $HOME/.ssh && ln -vsf /etc/dropbear/authorized_keys $HOME/.ssh/authorized_keys'\n"
    fi
    if [[ -f $TOOLCHAIN_FILE ]]
    then
    message+=" - CMake toolchain file:  ${TOOLCHAIN_FILE}\n"
    fi
    if [[ -d $BUILD_TOOLS_LOCATION ]]
    then
    message+=" - Tools location:        ${BUILD_TOOLS_LOCATION}\n"
    message+=" - Tools prefix:          ${BUILD_TOOLS_PREFIX}\n"
    fi

    log MESSAGE "${message}"
}

function log() {
    local level=-1

    for l in "${!log_levels[@]}"
    do
        if [[ "${log_levels[$l]}" == "${1^^}" ]]
        then
            level=$l
        fi
    done

    if [[ $level -ge 0 ]]
    then
        shift # past value

        if [[ $level -le $VERBOSE ]]
        then
            echo -e "${@}"
        fi

        if [[ -n "${LOG}" ]]
        then
            echo -e "${@}\n" >> "${LOG}"
        fi
    fi
}

function reset-cache() {
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
}

function main() {
    POSITIONAL=()
    INSTALL_ONLY="N"
    WRITE="N"
    VERBOSE=1
    LOG=""

    read_cache

    parse_args $@ && check_env && pre-install && write_workspace && write_cache
}

# Initialize global variables
DEBUG_ID=""
BUILD_TOOLS_LOCATION=""
BUILD_TOOLS_PREFIX="NOT_SET"
BUILD_TYPE=""
ROOT_LOCATION=""
INSTALL_LOCATION=""
TOOLS_LOCATION=""
TOOLCHAIN_FILE=""
SYS_ROOT=""

main $@
