# (Heroku-ish) Pebble Builder
A tool using [Docker](http://docker.io) and [Buildpacks](https://devcenter.heroku.com/articles/buildpacks) to produce a runnable docker image of a given application source.

## What does it do exactly?

It's a Docker container that takes an application source. The source is run through buildpacks, then if it's detected as a supported app it will be compiled into a released app located at /app inside the container. The container can then be commited as an image and run to start the app.

## Using Pebble Builder

First, you need Docker. Then you can pull the image from the public index:

	$ docker pull pebbles/pebblebuilder

When you run the container, it always expects a with your app source mounted at /pushed. So let's run it from a local app repo and produce a runnable image:

	$ id=$(docker run -v $currentdir:/pushed -i pebbles/pebblebuilder --skip-runit -- /builder/build.sh)
	$ docker wait $id
	$ docker commit $id $appname

We run pebblebuilder, wait for it to finish using the id it gave us, then commit the finished container as the app image. If we attached to the container with `docker attach` we could also see the build output as you would with Heroku:

	$ id=$(docker run -d -v $currentdir:/pushed -i pebbles/pebblebuilder --skip-runit -- /builder/build.sh)
	$ docker attach $id
	$ test $(docker wait $id) -eq 0
	$ docker commit $id $appname > /dev/null
	
The built image can then simply be run with no arguments to have runit run all services defined in the Procfile or the default services:

	$ docker run -i pebbles/mike
	
Or run a one time command in the image:

	$ docker run -i -t pebbles/mike run bundle exec rails c

## Caching

To speed up pebble building, it's best to mount a volume specific to your app at `/tmp/cache`. For example, if you wanted to keep the cache for this app on your host at `/tmp/app-cache`, you'd mount a read-write volume by running docker with this added `-v /tmp/app-cache:/tmp/cache:rw` option:

	docker run -v $currentdir:/pushed -v /tmp/app-cache:/tmp/cache:rw -i -a stdin -a stdout pebbles/pebblebuilder --skip-runit -- /builder/build.sh

## Buildpacks

As you can see, pebblebuilder supports a number of official and third-party Heroku buildpacks. You can change the buildpacks.txt file and rebuild the container to create a version that supports more/less buildpacks than we do here. You can also bind mount your own directory of buildpacks if you'd like:

	docker run -v $currentdir:/pushed  -v /my/buildpacks:/tmp/buildpacks:ro -i -a stdin -a stdout pebbles/pebblebuilder --skip-runit -- /builder/build.sh

## Base Environment

The Docker image here is based on [cedarish](https://github.com/pebblescape/cedarish), an image that emulates the Heroku Cedar stack environment to a degree. All buildpacks should have everything they need to run in this environment, but if something is missing it should be added upstream to cedarish.

## License

MIT
