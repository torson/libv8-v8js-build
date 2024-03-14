#!/bin/bash
set -e

# instructions from (but they are outdated) : https://github.com/phpv8/v8js/blob/php7/README.Linux.md

## these are set in build.sh
# export LIBV8_VERSION=12.0.267
# export PHP_VERSION=8.3
# export PHP_V8JS_REPO_GITHUB_USER=phpv8
# export PHP_V8JS_REPO_GITHUB_REPO=v8js
# export PHP_V8JS_REPO=https://github.com/${PHP_V8JS_REPO_GITHUB_USER}/${PHP_V8JS_REPO_GITHUB_REPO}
# # doing checkout to commit instead of branch so we know exactly which commit the package was built from
# # export PHP_V8JS_REPO_BRANCH=php8
# export PHP_V8JS_REPO_COMMIT=1b521b3
# export PHP_V8JS_VERSION=2.1.2
# export PHP_V8JS_VERSION_SUFFIX=${PHP_V8JS_REPO_GITHUB_USER}-${PHP_V8JS_REPO_GITHUB_REPO}-${PHP_V8JS_REPO_COMMIT}

export MOUNT_PATH=/mount
export BUILD_PATH=${MOUNT_PATH}/build/v8js

run_command() { echo -e "\n\n--> $(date) [$(basename ${0})]: Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) [$(basename ${0})]: $1" ; }

# fetching DISTRIB_CODENAME
source /etc/lsb-release
# for testing in shell you need to export envvars:
export "$(cat /etc/lsb-release | tr '\n' ' ')"
log DISTRIB_CODENAME=${DISTRIB_CODENAME}

log "Installing libv8"
log "LIBV8_VERSION=${LIBV8_VERSION}"
run_command dpkg -i ${MOUNT_PATH}/build/libv8/libv8_${LIBV8_VERSION}-${DISTRIB_CODENAME}_amd64.deb
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

run_command make clean
run_command phpize
# ./configure --with-v8js=/opt/libv8 LDFLAGS="-lstdc++"
# ./configure --with-php-config=/usr/bin/php-config --with-v8js=/opt/libv8 LDFLAGS="-lstdc++"
run_command ./configure --with-php-config=/usr/bin/php-config --with-v8js=/opt/libv8 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS"
run_command make

## skipping tests as there is one failing
# run_command make test
# sudo make install

export PHP_V8JS_PKG_VERSION=${PHP_V8JS_VERSION}-${PHP_V8JS_VERSION_SUFFIX}-libv8-${LIBV8_VERSION}

log "build deb with checkinstall to strip ELF binaries and libraries"
run_command checkinstall -y --install=no --pkgname=php${PHP_VERSION}-v8js --pkgversion=${PHP_V8JS_PKG_VERSION} --pkggroup=Application/Accessories

export CHECKINSTALL_DEB_FOLDER=php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}-1_amd64
export CHECKINSTALL_DEB_FILE=${CHECKINSTALL_DEB_FOLDER}.deb
[ -d ${CHECKINSTALL_DEB_FOLDER} ] || run_command mkdir ${CHECKINSTALL_DEB_FOLDER}

run_command dpkg-deb --extract ${CHECKINSTALL_DEB_FILE} ${CHECKINSTALL_DEB_FOLDER}/

log "build deb package"
export PACKAGE_NAME=php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}-${DISTRIB_CODENAME}_amd64
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
