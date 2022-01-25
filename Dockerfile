# Ubuntu 20.04
# https://hub.docker.com/_/ubuntu?tab=tags
FROM ubuntu:focal-20220105

# set this to prevent warnings: debconf TERM is not set, so the dialog frontend is not usable
ARG DEBIAN_FRONTEND=noninteractive

RUN echo "upgrade all packages" && \
    apt-get update && \
    apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade && \
    echo "install basic packages" && \
    apt-get -y install \
            ca-certificates \
            less \
            lsb-release \
            openssl \
            software-properties-common \
            vim-tiny \
            tzdata

RUN echo "Dependencies for building v8" && \
    apt-get -y install \
            build-essential \
            curl \
            git \
            python \
            libglib2.0-dev \
            libtinfo5 \
            patchelf \
            gettext-base

RUN echo "Dependencies for building php-v8js" && \
    apt-get -y install \
            checkinstall \
            re2c