#!/bin/bash

echo "-----> Building runner"
docker build -t pebbles/pebblerunner .

echo "-----> Building app image"
id=$(docker run -d -v /vagrant/sample:/pushed -v /tmp/app-cache:/tmp/cache:rw -i pebbles/pebblerunner build)
docker attach $id
test $(docker wait $id) -eq 0
docker commit $id app > /dev/null

echo "-----> Cleanup"
docker rm $id > /dev/null
