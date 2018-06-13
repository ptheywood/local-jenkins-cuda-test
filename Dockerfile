FROM ubuntu:16.04
LABEL maintainer="p.heywood@sheffield.ac.uk"

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
    build-essential

CMD ["/bin/bash"]
WORKDIR /stage

RUN echo "test"
