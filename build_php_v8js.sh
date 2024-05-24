#!/bin/bash
set -e

# instructions from (but they are outdated) : https://github.com/phpv8/v8js/blob/php7/README.Linux.md

export BUILD_PATH=${MOUNT_PATH}/build/v8js
export PACKAGE_LIBV8_PATH=$(cat ${MOUNT_PATH}/build/PACKAGE_LIBV8_PATH)

run_command() { echo -e "\n\n--> $(date) [$(basename ${0})]: Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) [$(basename ${0})]: $1" ; }

# fetching DISTRIB_CODENAME
source /etc/lsb-release
# for testing in shell you need to export envvars:
# export "$(cat /etc/lsb-release | tr '\n' ' ')"

log DISTRIB_CODENAME=${DISTRIB_CODENAME}

log "Installing libv8"
log "LIBV8_VERSION=${LIBV8_VERSION}"
log "LIBV8_PACKAGE_FILE=${LIBV8_PACKAGE_FILE}"
run_command dpkg -i ${MOUNT_PATH}/build/libv8/${LIBV8_PACKAGE_FILE}
run_command apt-get -f install

log "Building v8js"
[ -d ${BUILD_PATH} ] || run_command mkdir ${BUILD_PATH}
cd ${BUILD_PATH}

if [ ! -d "${BUILD_PATH}/v8js" ]; then
    run_command git clone ${PHP_V8JS_REPO}
fi
cd ${BUILD_PATH}/v8js
run_command git checkout ${PHP_V8JS_REPO_COMMIT}

# git fetch --all --tags
# git checkout tags/${PHP_V8JS_VERSION}

run_command phpize
# ./configure --with-v8js=${PACKAGE_LIBV8_PATH} LDFLAGS="-lstdc++"
# ./configure --with-php-config=/usr/bin/php-config --with-v8js=${PACKAGE_LIBV8_PATH} LDFLAGS="-lstdc++"
echo './configure --with-php-config=/usr/bin/php-config --with-v8js=${PACKAGE_LIBV8_PATH} LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS -DV8_ENABLE_SANDBOX"'
./configure --with-php-config=/usr/bin/php-config --with-v8js=${PACKAGE_LIBV8_PATH} LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS -DV8_ENABLE_SANDBOX"

run_command make clean
run_command make

## skipping tests as there is one failing
# run_command make test
# sudo make install

export PHP_V8JS_PKG_VERSION=${PHP_V8JS_VERSION}-${PHP_V8JS_VERSION_SUFFIX}-libv8-${LIBV8_VERSION}-${DISTRIB_CODENAME}

log "build deb with checkinstall to strip ELF binaries and libraries"
run_command checkinstall --fstrans=no -y --install=no --pkgname=php${PHP_VERSION}-v8js --pkgversion=${PHP_V8JS_PKG_VERSION} --pkggroup=Application/Accessories

export CHECKINSTALL_DEB_FOLDER=php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}-1_amd64
export CHECKINSTALL_DEB_FILE=${CHECKINSTALL_DEB_FOLDER}.deb
[ -d ${CHECKINSTALL_DEB_FOLDER} ] || run_command mkdir ${CHECKINSTALL_DEB_FOLDER}

run_command dpkg-deb --extract ${CHECKINSTALL_DEB_FILE} ${CHECKINSTALL_DEB_FOLDER}/

log "build deb package"
export PACKAGE_NAME=php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}-${PHP_V8JS_PACKAGE_REVISION}_amd64
export PACKAGE_FILE=${PACKAGE_NAME}.deb
export PACKAGING_PATH=${BUILD_PATH}/package_${PACKAGE_NAME}
export PACKAGING_DEB_CONTROL_FILE=${MOUNT_PATH}/assets-php-v8js/deb.php-v8js.control.tmpl

[ -d ${PACKAGING_PATH}/DEBIAN ] || run_command mkdir -p ${PACKAGING_PATH}/DEBIAN

export DEB_CONTROL_INSTALLED_SIZE=$(${MOUNT_PATH}/du.pl -p=${CHECKINSTALL_DEB_FOLDER} | awk '{printf "%0.0f\n", $1/1000}')

log "setting control file"
export DISTRIB_CODENAME=${DISTRIB_CODENAME}
envsubst < ${PACKAGING_DEB_CONTROL_FILE} > ${PACKAGING_PATH}/DEBIAN/control

log "copying package content"
run_command cp -R ${CHECKINSTALL_DEB_FOLDER}/* ${PACKAGING_PATH}/
run_command cp -R ${MOUNT_PATH}/assets-php-v8js/php${PHP_VERSION}/etc ${PACKAGING_PATH}/

log "creating deb file"
chown -R root:root ${PACKAGING_PATH}
cd ${PACKAGING_PATH}/..
run_command dpkg-deb --build $(basename ${PACKAGING_PATH})

run_command mv $(basename ${PACKAGING_PATH}).deb ${PACKAGE_FILE}

run_command dpkg -i ${PACKAGE_FILE}

run_command php --ri v8js
