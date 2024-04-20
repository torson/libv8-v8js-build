#!/bin/bash
set -e

# instructions from : https://github.com/phpv8/v8js/blob/php7/README.Linux.md
# v8 repo : https://github.com/v8/v8 , get the version branch here

## this is set in build.sh
# export LIBV8_VERSION=12.0.267

export BUILD_PATH=${MOUNT_PATH}/build/libv8
export PACKAGE_LIBV8_PATH=/opt/libv8-${LIBV8_VERSION}

# storing PACKAGE_LIBV8_PATH so that build_php_v8js.sh will use it
echo ${PACKAGE_LIBV8_PATH} > ${MOUNT_PATH}/build/PACKAGE_LIBV8_PATH

run_command() { echo -e "\n\n--> $(date) [$(basename ${0})]: Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) [$(basename ${0})]: $1" ; }

[ -d ${BUILD_PATH} ] || run_command mkdir -p ${BUILD_PATH}
cd ${BUILD_PATH}

# need to set safe.directory due to running in docker with a folder mapping
git config --global --add safe.directory '*'

# # Install required dependencies
# run_command apt-get -y update
# run_command apt-get install -y build-essential curl git python libglib2.0-dev libtinfo5

log "LIBV8_VERSION=${LIBV8_VERSION}"
log "PACKAGE_LIBV8_PATH=${PACKAGE_LIBV8_PATH}"
log "SKIP_BUILD_LIBV8=${SKIP_BUILD_LIBV8}"

if [ "${SKIP_BUILD_LIBV8}" != "true" ]; then
    # Install depot_tools first (needed for source checkout)
    if [ ! -d depot_tools ]; then
        run_command git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    fi
    export PATH=`pwd`/depot_tools:"$PATH"

    # Download v8
    if [ ! -d v8 ]; then
        run_command fetch v8
    fi

    if [ -d ${BUILD_PATH}/build/${LIBV8_VERSION} ]; then
        log "INFO: Folder ${BUILD_PATH}/build/${LIBV8_VERSION} already exists, seems this version was already built. Otherwise manually remove this folder. Continuing with next version..."
        exit
    fi

    cd ${BUILD_PATH}/v8
    if [ -d out.gn ]; then
        log "Removing folder out.gn - previous build content"
        rm -Rf out.gn
    fi

    # (optional) If you'd like to build a certain version:
    run_command git checkout ${LIBV8_VERSION}
    run_command gclient sync -D

    # Setup GN
    run_command tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

    # Build
    run_command ninja -C out.gn/x64.release/

    # copy build artifacts
    cd ${BUILD_PATH}
    [ -d build/${LIBV8_VERSION}/lib ] || run_command mkdir -p build/${LIBV8_VERSION}/lib
    [ -d build/${LIBV8_VERSION}/include ] || run_command mkdir -p build/${LIBV8_VERSION}/include

    run_command cp v8/out.gn/x64.release/lib*.so v8/out.gn/x64.release/*_blob.bin v8/out.gn/x64.release/icudtl.dat build/${LIBV8_VERSION}/lib/
    run_command cp -R v8/include/* build/${LIBV8_VERSION}/include/

    # set RPATH on the installed libraries, so the library loader finds the dependencies
    for A in build/${LIBV8_VERSION}/lib/*.so; do echo $A ; patchelf --set-rpath '$ORIGIN' $A; done
fi

# build deb package
# fetching DISTRIB_CODENAME
source /etc/lsb-release
# for testing in shell you need to export envvars:
export "$(cat /etc/lsb-release | tr '\n' ' ')"
PACKAGING_PATH=${BUILD_PATH}/package_libv8_${LIBV8_VERSION}
PACKAGING_DEB_CONTROL_FILE=${MOUNT_PATH}/assets-libv8/deb.libv8.control.tmpl

[ -d ${PACKAGING_PATH}/DEBIAN ] || run_command mkdir -p ${PACKAGING_PATH}/DEBIAN
[ -d ${PACKAGING_PATH}${PACKAGE_LIBV8_PATH} ] || run_command mkdir -p ${PACKAGING_PATH}${PACKAGE_LIBV8_PATH}

# populating envvars for deb control file
#  > adjust DEB_CONTROL_DEPENDS_*_NAME package names based on the packages used in the specific Ubuntu distribution
cd ${MOUNT_PATH}
# adding version to package name so we can have multiple packages installed - and with that multiple PHP versions, v8js compiled with different libv8 versions
export DEB_CONTROL_PACKAGE_NAME=libv8-${LIBV8_VERSION}
export DEB_CONTROL_INSTALLED_SIZE=$(./du.pl -p=${BUILD_PATH}/build/${LIBV8_VERSION} | awk '{printf "%0.0f\n", $1/1000}')
export DEB_CONTROL_DEPENDS_LIBC_NAME=libc6
export DEB_CONTROL_DEPENDS_LIBC_VERSION=$(dpkg -l | grep ${DEB_CONTROL_DEPENDS_LIBC_NAME} | head -n 1 | awk '{print $3}' | sed -r 's/-.+//')
export DEB_CONTROL_DEPENDS_LIBGCC_NAME=libgcc-s1
export DEB_CONTROL_DEPENDS_LIBGCC_VERSION=$(dpkg -l | grep ${DEB_CONTROL_DEPENDS_LIBGCC_NAME} | head -n 1 | awk '{print $3}' | sed -r 's/-.+//')
export DEB_CONTROL_DEPENDS_LIBSTDCPP_NAME=libstdc++6
export DEB_CONTROL_DEPENDS_LIBSTDCPP_VERSION=$(dpkg -l | grep ${DEB_CONTROL_DEPENDS_LIBSTDCPP_NAME} | head -n 1 | awk '{print $3}' | sed -r 's/-.+//')

# setting control file
export DISTRIB_CODENAME=${DISTRIB_CODENAME}
envsubst < ${PACKAGING_DEB_CONTROL_FILE} > ${PACKAGING_PATH}/DEBIAN/control

# copying package content
run_command cp -R ${BUILD_PATH}/build/${LIBV8_VERSION}/* ${PACKAGING_PATH}${PACKAGE_LIBV8_PATH}/

# creating deb file
chown -R root:root ${PACKAGING_PATH}
cd ${PACKAGING_PATH}/..
run_command dpkg-deb --build $(basename ${PACKAGING_PATH})

PACKAGE_FILE=libv8_${LIBV8_VERSION}-${DISTRIB_CODENAME}_amd64.deb
run_command mv $(basename ${PACKAGING_PATH}).deb ${PACKAGE_FILE}

# installing the last version built
# run_command dpkg -i ${PACKAGE_FILE}
