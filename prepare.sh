#!/bin/bash
set -e

run_command() { echo -e "\n\n--> $(date) : Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) : $1" ; }

if [ ! -f /system_prepare.done ]; then

    export ARG DEBIAN_FRONTEND=noninteractive

    log "Upgrade all packages"
        run_command apt-get update
        run_command apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade

    log "Install basic packages"
        run_command apt-get -y install \
            ca-certificates \
            less \
            lsb-release \
            openssl \
            software-properties-common \
            vim-tiny \
            tzdata \
            gettext-base

    log "Dependencies for building v8"
        run_command apt-get -y install \
            build-essential \
            curl \
            git \
            libglib2.0-dev \
            libtinfo5 \
            patchelf

        source /etc/lsb-release
        if [ "$(echo ${DISTRIB_RELEASE} | tr -d .)" -eq "2004" ]; then
            # 20.04 Focal
            run_command apt-get -y install \
                    python2 python-is-python2
        elif [ "$(echo ${DISTRIB_RELEASE} | tr -d .)" -eq "2204" ]; then
            # 22.04 Jammy
            run_command apt-get -y install \
                    python2
            # manualy creating default python executable pointing to python2
            run_command ln -sf python2 /usr/bin/python
        fi

    log "Dependencies for building php-v8js"
        run_command apt-get -y install \
            checkinstall \
            re2c

        log "php-dev package needed due to phpize"
        run_command add-apt-repository -y ppa:ondrej/php
        run_command apt-get update
        run_command apt-get install -y php${PHP_VERSION}-dev

        log "Setting all PHP alternatives to PHP_VERSION - one time php and phpdbg were all of a suden set to php 8.1"
        # update-alternatives --get-selections |grep php
        run_command update-alternatives --set php /usr/bin/php${PHP_VERSION}
        run_command update-alternatives --set php-config /usr/bin/php-config${PHP_VERSION}
        run_command update-alternatives --set phpize /usr/bin/phpize${PHP_VERSION}

    run_command touch /system_prepare.done
fi
