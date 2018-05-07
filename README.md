# opencl_docker
Yet another OpenCL docker container, this for AMD, NVidia, and Intel CPU

The intel driver will work directly.  AMD and NVidia are Linux only and 
require special docker startup procedures to make the GPU devices available.  

The requirement for a Linux host is a limitation of the docker implementation
(<https://stackoverflow.com/a/46367989>); maybe it can be made to work later.

**Docker Install**

If you are using the NVidia drivers you will need the official docker-ce
package and the NVidia runtime package.  The AMD and Intel drivers can use 
the version of docker that comes with your system.

**Docker Configure**

On linux systems DNS lookup was failing, so you may need to find
the DNS IP addresses with:

    $ nmcli dev show | grep 'IP4.DNS'

and add them to docker using the following in /etc/docker/daemon.json:

    {
        "dns": ["first ip", "second ip"],
        ...
    }

You may need to force a docker daemon restart before this works:

    $ sudo pkill docker

Note that the nvidia runtime configuration is also in /etc/docker/daemon.json
so you may need some fiddling after installing it.

**NVidia**

In order to get a working NVidia container you need to install the nvidia
runtime into your host docker configuration.  This can be done using
the nvidia-docker2 package from the NVidia PPA (perosnal package archive).  
See the following for details:

    https://github.com/NVIDIA/nvidia-docker

As of this writing the nvidia-docker2 package depends on the docker-ce package 
from the docker PPA, so you may need to install that as well:

    https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-ce

The docker run command reuires and additional argument "--runtime=nvidia" to
connect the container to the hardware.

The Dockerfile for NVidia is relatively simple; presumably the bulk of the
configuration work is hidden in the NVidia runtime.

Note: probably need to set up the NVidia drivers on the host before any other
step, and probably needs to be done using the propriety drivers from NVidia.
The test machine was already set up so the specifics are not included here.

Test with:

    docker run --runtime=nvidia pkienzle/opencl_docker clinfo

You may need to add the user to video group as part of your installation
if your container is not running as root.

**AMD Radeon**

The AMD drivers may need to be installed on the host in order to run GPGPU 
from a docker container.  This container hasn't been tested without.

The open source ROCm drivers did not work from the container as of this 
writing, so the amdgpu-pro drivers were used instead.

The AMD drivers need some startup options for the container to see the GPU:

    docker run --device=/dev/dri pkienzle/opencl clinfo

For your application, you may need to add the user to video group as part 
of your installation if your container is not running as root. (Note: may
also need --device=/dev/kfd but works fine without it on an R9 Nano).

**Intel**

The intel drivers are included in the container.  The CPU device shows up on
a machine with Intel CPU.

    docker run pkienzle/opencl_docker clinfo

The official Intel drivers do not recognize the Intel GPU from within the
container. The open source beignet driver on Ubuntu is able to see it if 
the /dev/dri device is forwarded to the docker container.  It is not 
included in this container because it interferes with the other drivers 
on the system.  There are intel-beignet containers on docker hub that work,
such as:

    docker run --device=/dev/dri chihchun/intel-beignet clinfo

Beignet was having trouble with two different GPUs on the same system,
and needed to remap the Intel device to the first position:

    docker run \
        --device=/dev/dri/card1:/dev/dri/card0 \
        --device=/dev/dri/renderD129:/dev/dri/renderD128 \
        chihchun/intel-beignet clinfo

You may need to add the user to video group as part of your installation
if your container is not running as root.
