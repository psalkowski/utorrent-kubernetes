FROM golang:1.9 as confd

ARG CONFD_VERSION=0.16.0

ADD https://github.com/kelseyhightower/confd/archive/v${CONFD_VERSION}.tar.gz /tmp/

RUN mkdir -p /go/src/github.com/kelseyhightower/confd && \
  cd /go/src/github.com/kelseyhightower/confd && \
  tar --strip-components=1 -zxf /tmp/v${CONFD_VERSION}.tar.gz && \
  go install github.com/kelseyhightower/confd && \
  rm -rf /tmp/v${CONFD_VERSION}.tar.gz

FROM ubuntu:18.04
LABEL Maintainer="Yuri L Chuk"

ARG CONFD_VERSION=0.16.0

#
# Create user and group for utorrent.
#
RUN set -eux; \
    echo '--> User Setup'; \
    groupadd --gid 1001 utorrent; \
    useradd --uid 1001 --gid utorrent --groups tty --home-dir /utorrent --create-home --shell /bin/bash utorrent;

COPY --from=confd /go/bin/confd /usr/local/bin/confd

#
# Install utorrent and all required dependencies.
#
RUN echo '--> Installing packages and utserver...'; \
    apt-get update; \
    apt-get install -qy curl sudo openssl libssl1.0.0 libssl-dev vim nfs-common; \
    curl -s http://download-new.utorrent.com/endpoint/utserver/os/linux-x64-ubuntu-13-04/track/beta/ | tar xzf - --strip-components 1 -C utorrent; \
    apt-get -y autoremove; \
    apt-get -y clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/cache/apt/*; \
    echo '--> Make dirs'; \
    mkdir -p \
        /utorrent/shared/download \
        /utorrent/shared/torrent \
        /utorrent/shared/done \
        /utorrent/settings \
        /utorrent/temp; \
    chown -R utorrent:utorrent /utorrent;


#
# Copy confd configs and templates
#
ADD --chown=utorrent:utorrent confd/ /etc/confd/

#
# Add utorrent init script.
#
ADD --chown=utorrent:utorrent utorrent.sh /
RUN set -eux; chmod +x /utorrent.sh; chmod +x /usr/local/bin/confd;

WORKDIR /utorrent

#
# Start utorrent.
#
ENTRYPOINT ["/utorrent.sh"]
CMD ["/utorrent/utserver", "-settingspath", "/utorrent/settings", "-configfile", "/utorrent/shared/utserver.conf", "-logfile", "/dev/stdout"]