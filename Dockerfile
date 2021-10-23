FROM ghcr.io/linuxserver/baseimage-alpine:3.14 as binbuilder

RUN \
  echo "**** install build packages ****" && \
  apk add \
    curl \
    git \
    go

RUN \
  echo "**** build nestool ****" && \
  mkdir -p /build-out/usr/local/bin && \
  git clone https://github.com/Kreeblah/NES20Tool.git && \
  cd NES20Tool && \
  go build && \
  mv NES20Tool /build-out/usr/local/bin

RUN \
  echo "**** grab binmerge ****" && \
  BINMERGE_RELEASE=$(curl -sX GET "https://api.github.com/repos/putnam/binmerge/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -o \
    /tmp/binmerge.tar.gz -L \
    "https://github.com/putnam/binmerge/archive/${BINMERGE_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/binmerge.tar.gz -C \
    /tmp/ --strip-components=1 && \
  chmod +x /tmp/binmerge && \
  mv /tmp/binmerge /build-out/usr/local/bin

FROM ghcr.io/linuxserver/baseimage-alpine:3.14 as nodebuilder

ARG EMULATORJS_RELEASE

RUN \
  echo "**** install build packages ****" && \
  apk add \
    curl \
    nodejs \
    npm

RUN \
  echo "**** grab emulatorjs ****" && \
  mkdir /emulatorjs && \
  if [ -z ${EMULATORJS_RELEASE+x} ]; then \
    EMULATORJS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/emulatorjs/releases/latest" \
      | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
    /tmp/emulatorjs.tar.gz -L \
    "https://github.com/linuxserver/emulatorjs/archive/${EMULATORJS_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/emulatorjs.tar.gz -C \
    /emulatorjs/ --strip-components=1

RUN \
  echo "**** grab emulatorjs blobs ****" && \
  curl -o \
    /tmp/emulatorjs-blob.tar.gz -L \
    "https://github.com/ethanaobrien/emulatorjs/archive/main.tar.gz" && \
  tar xf \
    /tmp/emulatorjs-blob.tar.gz -C \
    /emulatorjs/frontend/ --strip-components=1

RUN \
  echo "**** build emulatorjs ****" && \
  cd /emulatorjs && \
  npm install

# runtime stage
FROM ghcr.io/linuxserver/baseimage-alpine:3.14

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    file \
    go-ipfs \
    nginx \
    nodejs \
    p7zip \
    python3 && \
  mkdir /data && \
  apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    mame-tools && \
  echo "**** cleanup ****" && \
  rm -rf \
    /tmp/*

# add local files and files from buildstage
COPY --from=binbuilder /build-out/ /
COPY --from=nodebuilder /emulatorjs/ /emulatorjs/
COPY root/ /

# ports
EXPOSE 80 3000
