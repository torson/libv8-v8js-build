#!/bin/bash
# set -e

run_command() { echo -e "\n\n--> $(date) [$(basename ${0})]: Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) [$(basename ${0})]: $1" ; }

export MOUNT_PATH=/mount

## libv8 vars
#    > You can set multiple versions to LIBV8_BUILD_VERSIONS to build multiple versions (when testing version build compatibility with v8js extension)
#      This will then iterate through these versions, first build libv8 and then try to build v8js.
#      If v8js build fails it then continues with the next libv8 version. If v8js build succeedes the script then exits as the purpose is to find compatible version match.
#      Values should go from newest version to oldest version as one generally wants the latest compatible version
#      The purpose of this is to run this script and leave it running for hours - as building libv8 takes can take 1h or even much longer depending on your CPU power

# export LIBV8_BUILD_VERSIONS="12.4.204 12.3.105 12.2.281 12.1.285 12.0.267 11.9.172 11.8.173"
# 12.0.267 is the latest version that is compatible with latest (as of this writing) phpv8/v8js commit 1b521b3
export LIBV8_BUILD_VERSIONS="12.0.267"
export SKIP_BUILD_LIBV8=true

## php-v8js vars
export PHP_VERSION=8.3
export PHP_V8JS_REPO_GITHUB_USER=phpv8
export PHP_V8JS_REPO_GITHUB_REPO=v8js
export PHP_V8JS_REPO=https://github.com/${PHP_V8JS_REPO_GITHUB_USER}/${PHP_V8JS_REPO_GITHUB_REPO}
# doing checkout to commit instead of branch so we know exactly which commit the package was built from
# export PHP_V8JS_REPO_BRANCH=php8
export PHP_V8JS_REPO_COMMIT=1b521b3
export PHP_V8JS_VERSION=2.1.2.1
# adding also v8js repo and commitID to the package version
export PHP_V8JS_VERSION_SUFFIX=${PHP_V8JS_REPO_GITHUB_USER}-${PHP_V8JS_REPO_GITHUB_REPO}-${PHP_V8JS_REPO_COMMIT}

log "### Installing dependencies"
./prepare.sh

for LIBV8_VERSION in ${LIBV8_BUILD_VERSIONS} ; do
    export LIBV8_VERSION=${LIBV8_VERSION}
    log "### Building libv8 , LIBV8_VERSION=${LIBV8_VERSION}"
    ./build_libv8.sh

    log "### Building v8js extension , LIBV8_VERSION=${LIBV8_VERSION}"
    ./build_php_v8js.sh

    if [ "$?" = "0" ]; then
        log "INFO: Build finished successfully"
        exit
    else
        log "WARNING: Building v8js extension FAILED!"
    fi

done
