# Docker image file that describes an opensuse13.2 image with PowerShell installed
# TODO: install powershell from Microsoft APT Repo

FROM travisez13/powershell:opensuse13.2
LABEL maintaner Travis Plunk <travis.plunk@microsoft.com>

# Install dependencies and clean up
RUN zypper --non-interactive update --skip-interactive \
    && zypper --non-interactive install \
        ca-certificates \
        curl \
        fuse \
        git \
        glibc \
        glibc-i18ndata \
        glibc-locale \
        libgcc_s1 \
        libicu \
        libsdtc++6 \
        libstdc_s1 \
        libunwind \
        openssl \
        python \
        ossp-uuid \
        which \
    && zypper --non-interactive clean --all

# Setup the locale
ENV LANG en_US.UTF-8
ENV LC_ALL $LANG
RUN localedef --charmap=UTF-8 --inputfile=en_US $LANG

COPY PowerShellPackage.ps1 /

# Use PowerShell as the default shell
ENTRYPOINT [ "powershell" ]
