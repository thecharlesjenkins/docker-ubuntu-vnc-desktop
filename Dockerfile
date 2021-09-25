# Built with arch: arm64 flavor: lxde image: ubuntu:20.04
#
################################################################################
# base system
################################################################################
FROM ubuntu:20.04 as system

RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list;

# built-in packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt update \
    && apt install -y --no-install-recommends apt-utils software-properties-common curl apache2-utils \
    && apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        supervisor nginx sudo net-tools zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*
# install debs error if combine together
RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        xvfb x11vnc \
        vim-tiny firefox ttf-ubuntu-font-family ttf-wqy-zenhei  \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*
# Additional packages require ~600MB
# libreoffice  pinta language-pack-zh-hant language-pack-gnome-zh-hant firefox-locale-zh-hant libreoffice-l10n-zh-tw

# tini to fix subreap
ARG TINI_VERSION=v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
RUN chmod +x /bin/tini

# ffmpeg
RUN apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /usr/local/ffmpeg \
    && ln -s /usr/bin/ffmpeg /usr/local/ffmpeg/ffmpeg

# install packages
RUN apt-get update && apt-get install -q -y --no-install-recommends \
    dirmngr \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu focal main" > /etc/apt/sources.list.d/ros1-latest.list

# setup keys
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt update \
    && apt install -y terminator

RUN mkdir -p /home/padowan/training_ws/src

# install ROS Foxy
RUN apt update && apt install -y locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && export LANG=en_US.UTF-8

RUN apt update && apt install -y curl gnupg2 lsb-release \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key  -o /usr/share/keyrings/ros-archive-keyring.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

RUN apt update \
    && apt install -y ros-foxy-desktop \
    && apt install -y ros-foxy-ros-base

RUN apt update && apt install -y git

# RUN apt update && apt install -y wget && wget -qO - https://stslaptstorage.z13.web.core.windows.net/pubkey.txt | sudo apt-key add -
# RUN apt-add-repository "deb https://stslaptstorage.z13.web.core.windows.net/ focal main"
# # RUN apt install -y ros-foxy-stsl-desktop

RUN cd /home/padowan/ && git clone https://github.com/RoboJackets/stsl.git
RUN apt install -y python3-rosdep
RUN /bin/bash -c "source /opt/ros/foxy/setup.bash" && cd /home/padowan/stsl && apt-get update && rosdep init --rosdistro=foxy && rosdep update --rosdistro=foxy && rosdep install --from-paths . --ignore-src -y --skip-keys="libgpiod2 libgpiod-dev"
RUN /bin/bash -c "source /opt/ros/foxy/setup.bash" && cd /home/padowan/stsl && colcon build --packages-skip traini_onboard_interface

RUN cd /home/padowan/training_ws/src && git clone https://github.com/RoboJackets/software-training.git
RUN apt install -y python3-colcon-common-extensions

# Install sublime
RUN wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add - \
    && apt-get install -y apt-transport-https \
    && echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list \
    && apt-get update && apt-get install -y sublime-text

RUN apt install -y gedit

# Add desktop shortcuts
COPY desktop/ /home/padowan/Desktop

################################################################################
# builder
################################################################################
FROM ubuntu:20.04 as builder



################################################################################
# merge
################################################################################
FROM system
LABEL maintainer="fcwu.tw@gmail.com"

COPY rootfs /

EXPOSE 80
WORKDIR /root
ENV HOME=/home/ubuntu \
    SHELL=/bin/bash
ENTRYPOINT ["/startup.sh"]
