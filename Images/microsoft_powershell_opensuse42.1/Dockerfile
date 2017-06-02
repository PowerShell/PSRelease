# Docker image file that describes an opensuse42.1 image with PowerShell installed

FROM microsoft/powershell:opensuse42.1
LABEL maintainer="PowerShell Team <powershellteam@hotmail.com>"

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
    && zypper --non-interactive clean --all

# Setup the locale
ENV LANG en_US.UTF-8
ENV LC_ALL $LANG
RUN localedef --charmap=UTF-8 --inputfile=en_US $LANG

COPY PowerShellPackage.ps1 /

# Use PowerShell as the default shell
ENTRYPOINT [ "powershell" ]
