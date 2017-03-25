# Docker image file that describes an opensuse42.1 image with PowerShell installed

# TODO: Once we have an opensuse 42.1 container with powershell installed in the microsoft repo use it

FROM opensuse:42.1
LABEL maintainer Travis Plunk <travis.plunk@microsoft.com>

ARG POWERSHELL_VERSION=6.0.0_alpha.17
ARG POWERSHELL_RELEASE=v6.0.0-alpha.17
ARG FORK=PowerShell
ARG POWERSHELL_PACKAGE=powershell-$POWERSHELL_VERSION-1.suse.42.1.x86_64.rpm

# temporary url until we have an official release
ARG POWERSHELL_PACKAGE_URL=https://github.com/TravisEz13/PowerShell/releases/download/v6.0.0-alpha.17/powershell-6.0.0_alpha.9_893_gcd2d3ea-1.suse.42.1.x86_64.rpm
# TODO update the above line to the line below
# ARG POWERSHELL_PACKAGE_URL=https://github.com/$FORK/PowerShell/releases/download/$POWERSHELL_RELEASE/$POWERSHELL_PACKAGE

# TODO: install powershell from Microsoft RPM Repo

# Update, Install packages to generate localedef and CURL which is used by RPM
# add the Microsoft key as trusted to install packgages using RPM
# Install PowerShell then clean up
RUN zypper --non-interactive update --skip-interactive \
    && zypper --non-interactive install \
        ca-certificates \
        curl \
        fuse \
        git \
        glibc \
        glibc-i18ndata \
        glibc-i18ndata \
        glibc-locale \
        glibc-locale \
        libgcc_s1 \
        libicu \
        libstdc++6 \
        libunwind \
        ncurses-utils \
        openssl \
        ossp-uuid \
        python \
        which \
    && rpm --import https://packages.microsoft.com/keys/microsoft.asc \
    && zypper --non-interactive install $POWERSHELL_PACKAGE_URL \
    && zypper --non-interactive clean --all

# Setup the locale
ENV LANG en_US.UTF-8
ENV LC_ALL $LANG
RUN localedef --charmap=UTF-8 --inputfile=en_US $LANG

COPY PowerShellPackage.ps1 /

# Use PowerShell as the default shell
ENTRYPOINT [ "powershell" ]
