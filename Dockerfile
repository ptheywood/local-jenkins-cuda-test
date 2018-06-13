FROM nvidia/cuda:9.0-devel-ubuntu16.04
LABEL maintainer="p.heywood@sheffield.ac.uk"

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility

# Install some basic packages.
RUN apt-get update --fix-missing && apt-get install -y \
    bzip2 \
    ca-certificates \
    gcc \
    git \
    libc-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    wget \
    libevent-dev \
    build-essential \
    make 

CMD ["/bin/bash"]
WORKDIR /stage
