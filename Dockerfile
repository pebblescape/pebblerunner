FROM pebbles/cedarish
MAINTAINER krisrang "mail@rang.ee"

ADD ./builder/ /tmp/builder
RUN mkdir -p /tmp/buildpacks && cd /tmp/buildpacks && xargs -L 1 git clone --depth=1 < /tmp/builder/buildpacks.txt

VOLUME ["/pushed"]
VOLUME ["/etc/container_environment"]
CMD ["--skip-startup-files", "--quiet", "--skip-runit", "--", "/tmp/builder/build.sh"]
ENTRYPOINT ["/sbin/my_init"]
