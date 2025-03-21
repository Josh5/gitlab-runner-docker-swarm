# Releases:
#   https://hub.docker.com/_/docker/tags
FROM docker:26

LABEL maintainer="Josh.5 <jsunnex@gmail.com>"

RUN \
    echo "**** Install entrypoint dependencies ****" \
        && apk add --no-cache \
        bash \
        coreutils \
        tini \
        wget \
    && \
    echo

COPY overlay/ /

ENV \
    GENERAL_RUNNER_NAME=1 \
    GENERAL_CONCURRENCY=1 \
    DOCKER_IMAGE=docker \
    KEEP_ALIVE=true

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
CMD []
