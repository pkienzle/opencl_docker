# Using the latest long-term-support Ubuntu OS
FROM ubuntu:16.04

RUN apt-get update && apt-get install -y \
    apt-utils \
    unzip \
    tar \
    curl \
    xz-utils \
    alien \
    clinfo \
    ;

# Install Intel OpenCL drivers
# Based on the Intel OpenCL installation instructions and the Intel docker file
# in https://github.com/chihchun/opencl-docker
# This seems to work for the CPU only.  
ARG INTEL_DRIVER=opencl_runtime_16.1.1_x64_ubuntu_6.4.0.25.tgz
ARG INTEL_DRIVER_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/9019

#ADD http://registrationcenter-download.intel.com/akdlm/irc_nas/11396/SRB5.0_linux64.zip /tmp/intel-opencl-driver
RUN mkdir -p /tmp/opencl-driver-intel
WORKDIR /tmp/opencl-driver-intel
#COPY $INTEL_DRIVER /tmp/opencl-driver-intel/$INTEL_DRIVER
#RUN curl -O $INTEL_DRIVER_URL/$INTEL_DRIVER 
# SRB 5 uses a zip file; older drivers use .tgz
RUN echo INTEL_DRIVER is $INTEL_DRIVER; \
    curl -O $INTEL_DRIVER_URL/$INTEL_DRIVER; \
    if echo $INTEL_DRIVER | grep -q "[.]zip$"; then \
        unzip $INTEL_DRIVER; \
        mkdir fakeroot; \
        for f in intel-opencl-*.tar.xz; do tar -C fakeroot -Jxvf $f; done; \
        cp -R fakeroot/* /; \
        ldconfig; \
    else \
        tar -xzf $INTEL_DRIVER; \
        for i in $(basename $INTEL_DRIVER .tgz)/rpm/*.rpm; do alien --to-deb $i; done; \
        dpkg -i *.deb; \
        rm -rf $INTEL_DRIVER $(basename $INTEL_DRIVER .tgz) *.deb; \
        mkdir -p /etc/OpenCL/vendors; \
        echo /opt/intel/*/lib64/libintelocl.so > /etc/OpenCL/vendors/intel.icd; \
    fi; \
    rm -rf /tmp/opencl-driver-intel;

# For an intel GPU you can use apt-get to install the beignet-opencl-icd driver.  
# To see the HD device you also need to add "--device=/dev/dri" to the docker 
# run command.  With two GPUs beignet was confused and needed:
#      --device=/dev/dri/card1:/dev/dri/card0
#      --device=/dev/dri/renderD129:/dev/dri/renderD128
# Since beignet causes problems with the other drivers, this has been
# suppressed from the current docker build.
# The chihchun/intel-beignet container from dockerhub will work in this case.
#RUN apt-get update && apt-get install -y beignet-opencl-icd

# Install AMD Radeon drivers
# sonm/opencl is much smaller since it "pre-installs" the AMD libraries rather
# going through the vendor installer (100 MB vs 800 MB).  Similarly, installing
# alien, etc. so the intel installer can work adds 300+ MB.  Leave it this way
# for now since it should be easier to bump driver versions; also, it should
# be more trustworthy since the docker build relies on vendor binaries rather
# than unsigned object files from an unknown user.
# Docker run command needs --device=/dev/dri (and maybe --device=/dev/kfd)
ARG AMD_DRIVER=amdgpu-pro-18.10-572953.tar.xz
ARG AMD_DRIVER_URL=https://www2.ati.com/drivers/linux/ubuntu
RUN mkdir -p /tmp/opencl-driver-amd
WORKDIR /tmp/opencl-driver-amd
#COPY $AMD_DRIVER /tmp/opencl-driver-amd/$AMD_DRIVER
#RUN curl --referer $AMD_DRIVER_URL -O $AMD_DRIVER_URL/$AMD_DRIVER
RUN echo AMD_DRIVER is $AMD_DRIVER; \
    curl --referer $AMD_DRIVER_URL -O $AMD_DRIVER_URL/$AMD_DRIVER; \
    tar -Jxvf $AMD_DRIVER; \
    cd amdgpu-pro-*; \
    ./amdgpu-install; \
    apt-get install opencl-amdgpu-pro -y; \
    rm -rf /tmp/opencl-driver-amd;

#RUN apt-get install -y alien

# Install NVidia OpenCL drivers
# In order to run against nvidia GPU need the docker-ce package:
#   https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-ce
# then the nvidia-docker2 package:
#   https://github.com/NVIDIA/nvidia-docker
# The commands to compose the nvidia opencl configuration come from
# the nvidia docker containers in opencl/runtime/Dockerfile at:
#   https://gitlab.com/nvidia/opencl
# These are also hosted on docker hub and can be used as the base container:
#   https://hub.docker.com/r/nvidia/opencl/
# Docker run command needs "--runtime=nvidia"
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility

RUN rm -f /etc/OpenCL/vendors/mesa.icd

CMD clinfo
