
image ?= opencl_$(USER)
IMAGE ?= $(image)

# Intel OpenCL 2.0
#INTEL_DRIVER=SRB5.0_linux64.zip
#INTEL_DRIVER_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/11396

# Intel OpenCL 1.2 16.1.2
#INTEL_DRIVER=opencl_runtime_16.1.2_x64_rh_6.4.0.37.tgz
#INTEL_DRIVER_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/12556

# Intel OpenCL 1.2 16.1.1
INTEL_DRIVER=opencl_runtime_16.1.1_x64_ubuntu_6.4.0.25.tgz
INTEL_DRIVER_URL=http://registrationcenter-download.intel.com/akdlm/irc_nas/9019

# AMDGPU-PRO
# TODO: this should be replaced by the ROCm drivers...
#AMD_DRIVER = amdgpu-pro-17.40-492261.tar.xz
AMD_DRIVER=amdgpu-pro-18.10-572953.tar.xz
AMD_DRIVER_URL=https://www2.ati.com/drivers/linux/ubuntu

# Specify the type of gpu (amd, nvidia, intel).
# This defines the run options needed for the docker container to access the
# GPU resources on the (Linux) host.  The nvidia container needs a special
# nvidia runtime installed, which depends on the docker-ce package from docker
# rather than the base docker package in debian/ubuntu.
# Note: Intel beignet gets confused by multiple cards... may need relabel
# the card and renderer as shown in the comment below.  This option can be
# specified using RUN_OPTS="..." on the call to Make.
NVIDIA_OPTS = --runtime=nvidia
#AMD_OPTS = --device=/dev/kfd --device=/dev/dri --group-add video
AMD_OPTS = --device=/dev/dri
INTEL_OPTS = --device=/dev/dri
#INTEL_OPTS = --device=/dev/dri/card1:/dev/dri/card0 --device=/dev/dri/renderD129:/dev/dri/renderD128
gpu ?= none
ifeq ($(gpu), amd)
	RUN_OPTS = $(AMD_OPTS)
else ifeq ($(gpu), nvidia)
	RUN_OPTS = $(NVIDIA_OPTS)
else ifeq ($(gpu), intel)
	RUN_OPTS = $(INTEL_OPTS)
endif

.PHONY: stop build run clean fetch

all: build run

stop:
	# Stop the container if it is running
	-docker container ls | grep -q $(IMAGE) && docker stop -t 0 $(IMAGE)
	# Remove the container if it exists
	-docker container ls -a | grep -q $(IMAGE) && docker container rm $(IMAGE)

clean: stop
	# Remove the image if it exists
	-docker image ls | grep -q $(IMAGE) && docker image rm $(IMAGE)

# Make build depend on fetch if you want to cache the drivers locally; need
# to update the docker file appropriately.
#build: fetch
build:
	# Build or update the image ("make clean build" to build without cache)
	docker build . -t $(IMAGE) \
		--build-arg INTEL_DRIVER_URL=$(INTEL_DRIVER_URL) \
		--build-arg AMD_DRIVER_URL=$(AMD_DRIVER_URL) \
		--build-arg INTEL_DRIVER=$(INTEL_DRIVER) \
		--build-arg AMD_DRIVER=$(AMD_DRIVER)

run: stop
	# Run the container
	docker run $(RUN_OPTS) --name $(IMAGE) $(IMAGE)

bash: stop
	# Run the container interactive
	docker run $(RUN_OPTS) --interactive --tty --name $(IMAGE) $(IMAGE) bash

attach:
	# Attach to running container
	docker exec --interactive --tty $(IMAGE) bash

fetch: $(AMD_DRIVER) $(INTEL_DRIVER)

$(AMD_DRIVER):
	# AMD requires referer to be ati.com in order to download
	#wget --referer https://www2.ati.com $(AMD_DRIVER_URL)
	curl --referer https://www2.ati.com -O $(AMD_DRIVER_URL)/$(AMD_DRIVER)

$(INTEL_DRIVER):
	#wget $(INTEL_DRIVER_URL)
	curl -O $(INTEL_DRIVER_URL)/$(INTEL_DRIVER)
