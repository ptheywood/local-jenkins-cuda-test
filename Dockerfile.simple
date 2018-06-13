FROM ubuntu:16.04
LABEL maintainer="nfliu@cs.washington.edu"

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

# Install Miniconda.
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh
RUN wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
RUN /bin/bash ~/miniconda.sh -b -p /opt/conda
RUN rm ~/miniconda.sh

# Modify our PATH environment variable to 
# include our Miniconda install
ENV PATH /opt/conda/bin:$PATH

# Take the container Python version as an argument 
# (default is 3.5), and install that version.
ARG PYTHON_VERSION=3.5
RUN conda install -q python=${PYTHON_VERSION}

COPY . .

# Print the last commit message in this repository.
RUN git log -1
