FROM pebbles/cedarish
MAINTAINER krisrang "mail@rang.ee"

ADD ./builder/ /builder
ADD ./run/ /run
RUN mkdir -p /tmp/buildpacks && cd /tmp/buildpacks && xargs -L 1 git clone --depth=1 < /builder/buildpacks.txt

VOLUME ["/pushed"]
ENTRYPOINT ["/sbin/my_init"]
