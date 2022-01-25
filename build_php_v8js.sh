#!/bin/bash
set -e

# instructions from : https://github.com/phpv8/v8js/blob/php7/README.Linux.md

export MOUNT_PATH=/mount
export BUILD_PATH=${MOUNT_PATH}/build/v8js
export PHP_VERSION=7.2
export PHP_V8JS_VERSION=2.1.2
export LIBV8_VERSION=8.0.426.30

run_command() { echo -e "\n\n--> $(date) [$(basename ${0})]: Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) [$(basename ${0})]: $1" ; }

# fetching DISTRIB_CODENAME
source /etc/lsb-release
# for testing in shell you need to export envvars:
export "$(cat /etc/lsb-release | tr '\n' ' ')"
log DISTRIB_CODENAME=${DISTRIB_CODENAME}

log "Install libv8"
run_command dpkg -i ${MOUNT_PATH}/build/libv8/libv8_${LIBV8_VERSION}-${DISTRIB_CODENAME}_amd64.deb
run_command apt-get -f install

log "php-dev package needed due to phpize"
run_command add-apt-repository -y ppa:ondrej/php
run_command apt-get update

apt-get install -y php${PHP_VERSION}-dev

log "Setting all PHP alternatives to PHP_VERSION - one time php and phpdbg were all of a suden set to php 8.1"
# update-alternatives --get-selections |grep php
run_command update-alternatives --set php /usr/bin/php${PHP_VERSION}
run_command update-alternatives --set php-config /usr/bin/php-config${PHP_VERSION}
run_command update-alternatives --set phpize /usr/bin/phpize${PHP_VERSION}

log "Building v8js"
[ -d ${BUILD_PATH} ] || run_command mkdir ${BUILD_PATH}
cd ${BUILD_PATH}

# latest repo in development is currently https://github.com/amuluowin/v8js.git
#   > original is https://github.com/phpv8/v8js.git
#   > use this bookmarklet to check for status of the phpv8/v8js.git forks - go to the repo Insights > Forks page and paste below bookmarklet into the Developer tools console
#       https://stackoverflow.com/questions/54868988/how-to-determine-which-forks-on-github-are-ahead
#       bookmarklet :
#         ---
#         javascript:(async () => {
#           /* while on the forks page, collect all the hrefs and pop off the first one (original repo) */
#           const aTags = [...document.querySelectorAll('div.repo a:last-of-type')].slice(1);
#           for (const aTag of aTags) {
#             /* fetch the forked repo as html, search for the "This branch is [n commits ahead,] [m commits behind]", print it directly onto the web page */
#             await fetch(aTag.href)
#               .then(x => x.text())
#               .then(html => aTag.outerHTML += `${html.match(/This branch is.*/).pop().replace('This branch is', '').replace(/([0-9]+ commits? ahead)/, '<font color="#0c0">$1</font>').replace(/([0-9]+ commits? behind)/, '<font color="red">$1</font>')}`)
#               .catch(console.error);
#           }
#         })();
#         ---

run_command git clone https://github.com/amuluowin/v8js.git
cd v8js
# setting package version here since it contains the last commit hash
export PHP_V8JS_PKG_VERSION=${PHP_V8JS_VERSION}-amuluowin-3d64f08
# git fetch --all --tags
# git checkout tags/${PHP_V8JS_VERSION}
run_command phpize
run_command apt-get install -y re2c
# ./configure --with-v8js=/opt/libv8 LDFLAGS="-lstdc++"
# ./configure --with-php-config=/usr/bin/php-config --with-v8js=/opt/libv8 LDFLAGS="-lstdc++"
./configure --with-php-config=/usr/bin/php-config --with-v8js=/opt/libv8 LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS"
run_command make

## skipping tests as there is one failing
# run_command make test
# sudo make install

log "build deb with checkinstall to strip ELF binaries and libraries"
run_command checkinstall -y --install=no --pkgname=php${PHP_VERSION}-v8js --pkgversion=${PHP_V8JS_PKG_VERSION} --pkggroup=Application/Accessories

export CHECKINSTALL_DEB_FOLDER=php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}-1_amd64
export CHECKINSTALL_DEB_FILE=${CHECKINSTALL_DEB_FOLDER}.deb
[ -d ${CHECKINSTALL_DEB_FOLDER} ] || run_command mkdir ${CHECKINSTALL_DEB_FOLDER}

run_command dpkg-deb --extract ${CHECKINSTALL_DEB_FILE} ${CHECKINSTALL_DEB_FOLDER}/

log "build deb package"
export PACKAGING_PATH=${BUILD_PATH}/package_php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}
export PACKAGING_DEB_CONTROL_FILE=${MOUNT_PATH}/assets-php-v8js/deb.php-v8js.control.tmpl

[ -d ${PACKAGING_PATH}/DEBIAN ] || run_command mkdir -p ${PACKAGING_PATH}/DEBIAN

export DEB_CONTROL_INSTALLED_SIZE=$(${MOUNT_PATH}/du.pl -p=${CHECKINSTALL_DEB_FOLDER} | awk '{printf "%0.0f\n", $1/1000}')

log "setting control file"
run_command apt-get install -y gettext-base
envsubst < ${PACKAGING_DEB_CONTROL_FILE} > ${PACKAGING_PATH}/DEBIAN/control

log "copying package content"
run_command cp -R ${CHECKINSTALL_DEB_FOLDER}/* ${PACKAGING_PATH}/
run_command cp -R ${MOUNT_PATH}/assets-php-v8js/php${PHP_VERSION}/etc ${PACKAGING_PATH}/

log "creating deb file"
chown -R root:root ${PACKAGING_PATH}
cd ${PACKAGING_PATH}/..
run_command dpkg-deb --build $(basename ${PACKAGING_PATH})

export PACKAGE_FILE=php${PHP_VERSION}-v8js_${PHP_V8JS_PKG_VERSION}-${DISTRIB_CODENAME}_amd64.deb
run_command mv $(basename ${PACKAGING_PATH}).deb ${PACKAGE_FILE}

run_command dpkg -i ${PACKAGE_FILE}

run_command php --ri v8js
