FROM pebbles/cedarish
MAINTAINER krisrang "mail@rang.ee"

ADD ./scripts/ /scripts
RUN mkdir -p /tmp/buildpacks && cd /tmp/buildpacks && xargs -L 1 git clone --depth=1 < /scripts/buildpacks.txt
RUN useradd app

ENTRYPOINT ["/scripts/run"]
