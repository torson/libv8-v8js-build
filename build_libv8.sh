#!/bin/bash
set -e

# instructions from : https://github.com/phpv8/v8js/blob/php7/README.Linux.md

# export LIBV8_VERSION=6.5.257
export LIBV8_VERSION=8.0.426.30     # 8.0.426.30 is used in README.Linux.md

export MOUNT_PATH=/mount
export BUILD_PATH=${MOUNT_PATH}/build/libv8

run_command() { echo -e "\n\n--> $(date) [$(basename ${0})]: Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) [$(basename ${0})]: $1" ; }

[ -d ${BUILD_PATH} ] || run_command mkdir -p ${BUILD_PATH}
cd ${BUILD_PATH}

# Install required dependencies
run_command apt-get -y update
run_command apt-get install -y build-essential curl git python libglib2.0-dev libtinfo5

# Install depot_tools first (needed for source checkout)
run_command git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=`pwd`/depot_tools:"$PATH"

# Download v8
run_command fetch v8
cd v8

# (optional) If you'd like to build a certain version:
run_command git checkout ${LIBV8_VERSION}
run_command gclient sync

# Setup GN
run_command tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false

# Build
run_command ninja -C out.gn/x64.release/

# copy build artifacts
cd ..
[ -d build/${LIBV8_VERSION}/lib ] || run_command mkdir -p build/${LIBV8_VERSION}/lib
[ -d build/${LIBV8_VERSION}/include ] || run_command mkdir -p build/${LIBV8_VERSION}/include

run_command cp v8/out.gn/x64.release/lib*.so v8/out.gn/x64.release/*_blob.bin v8/out.gn/x64.release/icudtl.dat build/${LIBV8_VERSION}/lib/
run_command cp -R v8/include/* build/${LIBV8_VERSION}/include/

# set RPATH on the installed libraries, so the library loader finds the dependencies
run_command apt-get install patchelf
for A in build/${LIBV8_VERSION}/lib/*.so; do echo $A ; patchelf --set-rpath '$ORIGIN' $A; done

# build deb package
# fetching DISTRIB_CODENAME
source /etc/lsb-release
# for testing in shell you need to export envvars:
export "$(cat /etc/lsb-release | tr '\n' ' ')"
PACKAGING_PATH=${BUILD_PATH}/package_libv8_${LIBV8_VERSION}
PACKAGING_DEB_CONTROL_FILE=${MOUNT_PATH}/assets-libv8/deb.libv8.control.tmpl

[ -d ${PACKAGING_PATH}/DEBIAN ${PACKAGING_PATH}/opt/libv8 ] || run_command mkdir -p ${PACKAGING_PATH}/DEBIAN ${PACKAGING_PATH}/opt/libv8

# populating envvars for deb control file
cd ${MOUNT_PATH}
export DEB_CONTROL_INSTALLED_SIZE=$(./du.pl -p=${BUILD_PATH}/build/${LIBV8_VERSION} | awk '{printf "%0.0f\n", $1/1000}')
export DEB_CONTROL_DEPENDS_LIBC_NAME=libc6
export DEB_CONTROL_DEPENDS_LIBC_VERSION=$(dpkg -l | grep ${DEB_CONTROL_DEPENDS_LIBC_NAME} | head -n 1 | awk '{print $3}' | sed -r 's/-.+//')
export DEB_CONTROL_DEPENDS_LIBGCC_NAME=libgcc-s1
export DEB_CONTROL_DEPENDS_LIBGCC_VERSION=$(dpkg -l | grep ${DEB_CONTROL_DEPENDS_LIBGCC_NAME} | head -n 1 | awk '{print $3}' | sed -r 's/-.+//')
export DEB_CONTROL_DEPENDS_LIBSTDCPP_NAME=libstdc++6
export DEB_CONTROL_DEPENDS_LIBSTDCPP_VERSION=$(dpkg -l | grep ${DEB_CONTROL_DEPENDS_LIBSTDCPP_NAME} | head -n 1 | awk '{print $3}' | sed -r 's/-.+//')

# setting control file
run_command apt-get install -y gettext-base
envsubst < ${PACKAGING_DEB_CONTROL_FILE} > ${PACKAGING_PATH}/DEBIAN/control

# copying package content
run_command cp -R ${BUILD_PATH}/build/${LIBV8_VERSION}/* ${PACKAGING_PATH}/opt/libv8/

# creating deb file
chown -R root:root ${PACKAGING_PATH}
cd ${PACKAGING_PATH}/..
run_command dpkg-deb --build $(basename ${PACKAGING_PATH})

PACKAGE_FILE=libv8_${LIBV8_VERSION}-${DISTRIB_CODENAME}_amd64.deb
run_command mv $(basename ${PACKAGING_PATH}).deb ${PACKAGE_FILE}

run_command dpkg -i ${PACKAGE_FILE}
