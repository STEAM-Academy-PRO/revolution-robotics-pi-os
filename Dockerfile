ARG BASE_IMAGE=debian:bullseye
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        git vim parted \
        quilt coreutils qemu-user-static debootstrap zerofree zip dosfstools \
        libarchive-tools libcap2-bin rsync grep udev xz-utils curl xxd file kmod bc\
        binfmt-support ca-certificates qemu-utils kpartx fdisk gpg pigz\
        python3 python3-pip python3-venv python3-dev\
    && rm -rf /var/lib/apt/lists/*

COPY . /pi-gen/

VOLUME [ "/pi-gen/work", "/pi-gen/deploy"]
