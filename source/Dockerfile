FROM rockylinux:9

ARG ASTERISK_VERSION=20.19.0

WORKDIR /usr/src

# Base deps + dev tools (from VICIstack guide)
RUN dnf -y install epel-release && \
    dnf config-manager --set-enabled crb && \
    dnf -y update && dnf -y --allowerasing install \
    gcc gcc-c++ make \
    kernel-headers \
    ncurses-devel \
    libxml2-devel \
    sqlite-devel \
    openssl-devel \
    libuuid-devel \
    jansson-devel \
    libsrtp-devel \
    speex-devel \
    opus-devel \
    newt-devel \
    wget \
    curl \
    subversion \
    httpd \
    php \
    php-mysqlnd \
    php-gd \
    php-mbstring \
    php-xml \
    perl \
    perl-DBI \
    perl-DBD-MySQL \
    perl-Digest-SHA \
    perl-Digest-HMAC \
    perl-MIME-Base64 \
    perl-Time-HiRes \
    perl-Getopt-Long \
    perl-IO-Socket-SSL \
    perl-LWP-Protocol-https \
    perl-Net-SSLeay \
    sox \
    lame \
    bzip2 \
    patch \
    mariadb \
    net-tools \
    procps-ng \
    diffutils \
    screen \
    cronie \
    && dnf clean all

# Perl modules not available as RPM in EL9
RUN curl -L https://cpanmin.us -o /usr/bin/cpanm && chmod +x /usr/bin/cpanm && \
    cpanm -n Net::Telnet

# Build Asterisk from source (as per VICIstack guide)
RUN wget -q https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz && \
    tar xzf asterisk-${ASTERISK_VERSION}.tar.gz && \
    cd asterisk-${ASTERISK_VERSION} && \
    contrib/scripts/install_prereq install && \
    contrib/scripts/get_mp3_source.sh && \
    ./configure --with-pjproject-bundled --with-jansson-bundled && \
    make menuselect.makeopts && \
    menuselect/menuselect \
      --enable CORE-SOUNDS-EN-ULAW \
      --enable MOH-OPSOUND-ULAW \
      --enable EXTRA-SOUNDS-EN-ULAW \
      --enable res_snmp \
      --enable chan_sip \
      --enable res_ari \
      --enable res_ari_channels \
      --enable res_ari_bridges \
      --enable res_ari_recordings \
      --enable res_ari_playbacks \
      --enable res_ari_events \
      --enable res_ari_sounds \
      --enable res_ari_applications \
      --enable res_http_websocket \
      --enable app_audiosocket \
      --enable chan_audiosocket \
      menuselect.makeopts && \
    make -j1 third-party && \
    make -j$(nproc) all && \
    make include/asterisk/buildinfo.h && \
    make install && \
    make samples && \
    ldconfig && \
    cd / && rm -rf /usr/src/asterisk-*

# Timing + disable unnecessary modules for containers
RUN printf '[modules]\nautoload=yes\nload => res_timing_timerfd.so\nnoload => res_timing_dahdi.so\nnoload => chan_dahdi.so\nnoload => res_config_pgsql.so\nnoload => res_config_ldap.so\nnoload => cel_pgsql.so\nnoload => cdr_radius.so\nnoload => cel_radius.so\nnoload => chan_alsa.so\nnoload => res_phoneprov.so\nnoload => res_smdi.so\n' \
    > /etc/asterisk/modules.conf

# VICIdial AGI scripts + source from SVN
RUN mkdir -p /usr/src/astguiclient && \
    cd /usr/src/astguiclient && \
    svn checkout svn://svn.eflo.net:3690/agc_2-X/trunk

# Apache config
RUN sed -i 's/^upload_max_filesize.*/upload_max_filesize = 20M/' /etc/php.ini && \
    sed -i 's/^memory_limit.*/memory_limit = 256M/' /etc/php.ini && \
    echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf

# Recordings volume mount point
RUN mkdir -p /var/spool/asterisk/monitor

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 443 5060/udp 5060/tcp 10000-20000/udp

CMD ["/usr/local/bin/entrypoint.sh"]
