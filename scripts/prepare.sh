#!/usr/bin/env bash

function print_usage() {
    echo "Usage:"
    echo "prepare.env [options]"
    echo ""
    echo "options:"
    echo " -b --build <type>                 Build Type [Debug/DebugOptimized/ReleaseSymbols/Release/Production]"
    echo " -c --cmake-toolchain-file <file>  Specify toolchain file for cmake"
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
       THUNDER_TOOLCHAIN_FILE=-DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE},"
    fi
   
    cmake -Hsource/$1 -Bbuild/${1///} $THUNDER_TOOLCHAIN_FILE -DCMAKE_MODULE_PATH=${TOOLS_LOCATION} -DCMAKE_INSTALL_PREFIX=${TOOLS_LOCATION} -DGENERIC_CMAKE_MODULE_PATH=${TOOLS_LOCATION} &> $STDOUT
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
    if [ "x$BUILD_TYPE" = "x" ]
    then
    	BUILD_TYPE="Debug"
        read -e -p "Set Build type: " -i "$BUILD_TYPE" BUILD_TYPE
    fi
    
    if [ "x$ROOT_LOCATION" = "x" ]
    then
    	ROOT_LOCATION="${PWD}"
        read -e -p "Set root install location: " -i "$ROOT_LOCATION" ROOT_LOCATION
    fi
    
    if [ "x$INSTALL_LOCATION" = "x" ]
    then
    	INSTALL_LOCATION="${ROOT_LOCATION}/install"
        read -e -p "Set thunder install location: " -i "$INSTALL_LOCATION" INSTALL_LOCATION
    fi
    
    if [ "x$TOOLS_LOCATION" = "x" ]
    then
    	TOOLS_LOCATION="${ROOT_LOCATION}/host-tools"
        read -e -p "Set tools install location: " -i "$TOOLS_LOCATION" TOOLS_LOCATION
    fi
  
    if [ "x$TOOLCHAIN_FILE" = "x" ]
    then
        read -e -p "Use Toolchain File: " TOOLCHAIN_FILE
        TOOLCHAIN_FILE=${TOOLCHAIN_FILE:-N}
    fi
}

function write_workspace(){
    write_vscode_workspace
}

function write_vscode_workspace(){
    if [[ -f $TOOLCHAIN_FILE ]]
    then
        THUNDER_TOOLCHAIN_FILE="\"CMAKE_TOOLCHAIN_FILE\":\"${TOOLCHAIN_FILE}\""
    fi
    
    timestamp=`date +'%s'`
    
    tmpws="${timestamp}-Thunder.code-workspace"
    ws=${USER}-Thunder.code-workspace
    
    sed \
        -e "s|@THUNDER_TOOLCHAIN_FILE@|${THUNDER_TOOLCHAIN_FILE}|g" \
        -e "s|@THUNDER_INSTALL_LOCATION@|${INSTALL_LOCATION}|g" \
        -e "s|@THUNDER_TOOLS_LOCATION@|${TOOLS_LOCATION}|g" \
        -e "s|@THUNDER_BUILD_TYPE@|${BUILD_TYPE}|g" \
        -e "s|@THUNDER_PROJECT_ROOT_LOCATION@|${ROOT_LOCATION}|g" \
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
    
    show_env
}

function show_env(){
    echo "Cached build environment from .cache:"
    echo " - Type:                  ${BUILD_TYPE}"
    echo " - Project root location: ${ROOT_LOCATION}"
    echo " - Install location       ${INSTALL_LOCATION}"
    echo " - Host tools:            ${TOOLS_LOCATION}"
    if [[ -f $TOOLCHAIN_FILE ]]
    then
    echo " - CMake toolchain file:  ${TOOLCHAIN_FILE}"
    fi
} 


function main() {
    POSITIONAL=()
    INSTALL_ONLY="N"
    WRITE="N"
    
    # silence the install
    STDOUT="/dev/null"
    
    # Initialize variables
    BUILD_TYPE=""
    ROOT_LOCATION=""
    INSTALL_LOCATION=""
    TOOLS_LOCATION=""
    TOOLCHAIN_FILE=""
    
    # only if the path exists in sources dir
    PREINSTALL_COMPONENTS=(
    	Thunder/Tools 
    	libprovision
    	ThunderUI
    )
    
    if [[ -f .cache ]]
    then
        echo "Reading cached build environment"
        source .cache
    fi

    parse_args $@ && check_env && pre-install && write_workspace && write_cache

    #true
}

main $@
