################################################################################
## base image

FROM menci/archlinuxarm:base-devel AS base

RUN pacman -Sy --noconfirm \
    curl \
    wget \
    git \
    inetutils \
    python \
    python-pip \
    openssh

COPY install fish/* /root/dotfiles/
COPY fish/* /root/dotfiles/fish/

#RUN /root/dotfiles/install

WORKDIR /workspace

################################################################################
## zmk

FROM base as zmk

RUN pacman -Sy --noconfirm \
    dtc \
    libtool \
    ninja \
    cmake

RUN pip3 install west pyelftools

ENV ZSDK_VERSION=0.15.2
RUN mkdir -p ~/.local
RUN cd ~/.local && \
    wget -q "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}_linux-aarch64.tar.gz" && \
    tar xvf "zephyr-sdk-${ZSDK_VERSION}_linux-aarch64.tar.gz" && \
    cd zephyr-sdk-0.15.2 && \
    ./setup.sh && \
    rm "zephyr-sdk-${ZSDK_VERSION}_linux-aarch64.tar.gz" \


