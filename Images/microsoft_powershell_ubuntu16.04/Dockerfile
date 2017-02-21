# Docker image file that describes an Ubuntu16.04 image with PowerShell installed from Microsoft APT Repo

FROM ubuntu:xenial
MAINTAINER Raghu Shantha <raghus@microsoft.com>

# Setup the locale
ENV LANG en_US.UTF-8
ENV LC_ALL $LANG
RUN locale-gen $LANG && update-locale

# Install dependencies and clean up
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
	apt-utils \
	apt-utils \
        libc6 \
        libcurl3 \
        ca-certificates \
        libgcc1 \
        libicu55 \
        libssl1.0.0 \
        libstdc++6 \
        libtinfo5 \
        libunwind8 \
        libuuid1 \
	libcroco3 \
	libgraphite2-3 \
        zlib1g \
        curl \
        git \
	apt-transport-https \
    && rm -rf /var/lib/apt/lists/*
    
# Import the public repository GPG keys for Microsoft
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
	
# Register the Microsoft Ubuntu 14.04 repository
RUN curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | tee /etc/apt/sources.list.d/microsoft.list

# Install powershell from Microsoft Repo
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
	powershell

COPY PowerShellPackage.ps1 /

# Use PowerShell as the default shell
ENTRYPOINT [ "powershell" ]
