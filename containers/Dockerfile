################################################################################
## base image

FROM archlinux:base AS base

RUN pacman -Sy --noconfirm \
    curl \
    wget \
    git \
    base-devel \
    python \
    python-pip

COPY install fish/* /root/dotfiles/
COPY fish/* /root/dotfiles/fish/

RUN /root/dotfiles/install

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

ENV ZSDK_VERSION=0.12.4
RUN wget -q "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-toolchain-arm-${ZSDK_VERSION}-x86_64-linux-setup.run" && \
    sh "zephyr-toolchain-arm-${ZSDK_VERSION}-x86_64-linux-setup.run" --quiet -- -d ~/.local/zephyr-sdk-${ZSDK_VERSION} && \
    rm "zephyr-toolchain-arm-${ZSDK_VERSION}-x86_64-linux-setup.run"

