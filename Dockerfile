FROM ubuntu:22.04 as ubuntu_updated

LABEL maintainer "Thierry Delafontaine <delafontaineth@pm.me>"
ENV DEBIAN_FRONTEND noninteractive

RUN dpkg --add-architecture i386; apt-get update; apt-get install -y -qq apt-utils; apt-get upgrade -y; apt-get install -y -qq locales; locale-gen en_US.UTF-8

# Install base requirements
RUN apt-get install -y -qq \
  sudo \
  gosu \
  vim \
  tmux \
  xz-utils \
  wget \
  unzip \
  dbus-x11 \
  libpci3 \
  curl \
  git \
  xorg \
  software-properties-common \
  libtinfo5 \
  default-jre \
  libnss3 \
  libgtk2.0-0 \
  libswt-gtk-4-java \
  iproute2 \
  gcc \
  g++ \
  net-tools \
  libncurses5-dev \
  zlib1g:i386 \
  zlib1g \
  libssl-dev \
  flex \
  bison \
  libselinux1 \
  xterm \
  autoconf \
  libtool \
  texinfo \
  zlib1g-dev \
  gcc-multilib \
  build-essential \
  screen \
  pax \
  gawk \
  python3 \
  python3-pexpect \
  python3-pip \
  python3-git \
  python3-jinja2 \
  debianutils \
  iputils-ping \
  libegl1-mesa \
  libsdl1.2-dev \
  pylint \
  cpio \
  rsync \
  bc ; \
  apt-get autoclean; apt-get autoremove

RUN add-apt-repository -y -n ppa:mozillateam/ppa; \
  apt-get update; \
  apt-get install -y -qq firefox-esr; \
  ln -s $(which firefox-esr) /usr/bin/firefox

RUN printf 'Name: dash/sh\nTemplate: dash/sh\nValue: false\nOwners: dash\nFlags: seen' > /tmp/debconf_dash.db; \
  DEBCONF_DB_OVERRIDE='File{/tmp/debconf_dash.db}' dpkg-reconfigure -fnoninteractive dash; \
  rm /tmp/debconf_dash.db

FROM ubuntu_updated as copy_files

ENV DEBIAN_FRONTEND noninteractive

ARG XLNX_VIVADO_VERSION=2023.2
ARG XLNX_VIVADO_INSTALLER=FPGAs_AdaptiveSoCs_Unified_2023.2_1013_2256_Lin64.bin
ARG XLNX_VIVADO_AUTH_FILE=wi_authentication_key
ARG XLNX_VIVADO_BATCH_CONFIG_FILE=install_config.txt
ARG XLNX_VIVADO_BATCH_CONFIG_FILE_PETALINUX=install_config_petalinux.txt

ENV XLNX_INSTALL_LOCATION=/tools/Xilinx

ENV XLNX_BOARDS_FOLDER ${XLNX_INSTALL_LOCATION}/Vivado/${XLNX_VIVADO_VERSION}/data/xhub/boards/XilinxBoardStore/boards/Xilinx

COPY ${XLNX_VIVADO_INSTALLER} /tmp/${XLNX_VIVADO_INSTALLER}
COPY ${XLNX_VIVADO_BATCH_CONFIG_FILE} /tmp/${XLNX_VIVADO_BATCH_CONFIG_FILE}
COPY ${XLNX_VIVADO_BATCH_CONFIG_FILE_PETALINUX} /tmp/${XLNX_VIVADO_BATCH_CONFIG_FILE_PETALINUX}
COPY ${XLNX_VIVADO_AUTH_FILE} /root/.Xilinx/wi_authentication_key
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh; \
  chmod +x /tmp/${XLNX_VIVADO_INSTALLER}


RUN mkdir -p ${XLNX_INSTALL_LOCATION}/PetaLinux
RUN useradd -ms /bin/bash xilinx; \
  chown -R xilinx:xilinx /tools

FROM copy_files as xilinx_tools

ENV DEBIAN_FRONTEND noninteractive

ARG XLNX_VIVADO_BATCH_CONFIG_FILE_PETALINUX=install_config_petalinux.txt
ARG XLNX_VIVADO_BATCH_CONFIG_FILE=install_config.txt

ARG XLNX_VIVADO_INSTALLER=FPGAs_AdaptiveSoCs_Unified_2023.2_1013_2256_Lin64.bin
ARG XLNX_VIVADO_VERSION=2023.2
ARG PETALINUX_PLATFORMS=arm

ENV XLNX_INSTALL_LOCATION=/tools/Xilinx

# Install PetaLinux installer
RUN /tmp/${XLNX_VIVADO_INSTALLER} -- \
  --agree XilinxEULA,3rdPartyEULA \
  --batch Install \
  --config /tmp/${XLNX_VIVADO_BATCH_CONFIG_FILE_PETALINUX}

USER xilinx
WORKDIR /tmp

RUN /tmp/PetaLinux/${XLNX_VIVADO_VERSION}/bin/petalinux-v${XLNX_VIVADO_VERSION}-final-installer.run \
  --skip_license \
  --dir ${XLNX_INSTALL_LOCATION}/PetaLinux/${XLNX_VIVADO_VERSION} \
  --platform "${PETALINUX_PLATFORMS}"

USER root
RUN rm -rf /tmp/PetaLinux/

RUN /tmp/${XLNX_VIVADO_INSTALLER} -- \
  --agree XilinxEULA,3rdPartyEULA \
  --batch Install \
  --config /tmp/${XLNX_VIVADO_BATCH_CONFIG_FILE}

RUN  rm -rf /tmp/* /root/.Xilinx/${XLNX_VIVADO_AUTH_FILE}

FROM xilinx_tools as setup_environment
ENV DEBIAN_FRONTEND noninteractive
ENV XLNX_INSTALL_LOCATION=/tools/Xilinx

# Set up the work environment

RUN mkdir -p ${HOME}/projects ${XLNX_BOARDS_FOLDER}
COPY boards/ /tmp/boards/
RUN unzip /tmp/boards/\*.zip -d ${XLNX_BOARDS_FOLDER}/
RUN ln -s ${XLNX_BOARDS_FOLDER}/pynq-z2/A.0 ${XLNX_BOARDS_FOLDER}/A.0
RUN ls -la ${XLNX_BOARDS_FOLDER}/A.0
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash", "-c", "source ${XLNX_INSTALL_LOCATION}/Vivado/${XLNX_VIVADO_VERSION}/settings64.sh;source ${XLNX_INSTALL_LOCATION}/PetaLinux/${XLNX_VIVADO_VERSION}/settings.sh;export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${XLNX_INSTALL_LOCATION}/Vivado/${XLNX_VIVADO_VERSION}/lib/lnx64.o/;/bin/bash"]

# vim: ft=dockerfile tw=0 ts=2
