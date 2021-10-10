Rakudo Nightly & Faster CI
rakudo-nightly--faster-ci
programming, rakudo

This article is going to walk through using a docker image to CI little modules on Circle CI and Travis CI - tl;dr just copy the appropriate config files for your choice of CI and modify for system dependencies.

The major benefit of using the image is speed and an ancillary benefit is the module can be tested against the latest rakudo build plus regression tested against whatever tags you find in the tonyodell/rakudo-nightly repo.

## docker

In the event that you're unfamiliar with docker: docker falls somewhere between a jail and virtual machine.  You don't really need to know much about docker to follow along and the options used to make certain things work a certain way will be explained the situations below.

For the rest of the tutorial we'll use (this repo)[https://hub.docker.com/r/tonyodell/rakudo-nightly] for rakudo nightly.

## travis ci

```yaml
language: minimal

services: docker

before_install:
- docker pull tonyodell/rakudo-nightly:latest

script:
- docker run
  -v $(pwd):/tmp/test:rw
  -w /tmp/test
  tonyodell/rakudo-nightly:latest
  bash -c 'apt update; apt install -y ca-certificates; zef install -v --deps-only . && zef test .'
```

## language: minimal

Usually in travis-ci we'd use `language: perl6` as it's been available for quite some time.  Because we're using a prefab image and don't want to build rakudo on every CI cycle, we don't need much on the host so we'll stick with the minimal image.

## services: docker

Let Travis know we want to use docker on this run.

## before_install: [ docker pull .. ]

Pull down a recent image of rakudo-nightly so we can test inside of the container later.  If you need a specific version of rakudo-nightly then this is the first of two places to change the tag.  Multiple versions can be pulled here; perhaps testing against a nightly and a known supported release.

## script: [ docker run .. ]

>    ... -v $(pwd):/tmp/test:rw ...

This will mount the current directory as `/tmp/test` read/writeable to the container.  The `$(pwd)` works in this case as Travis takes care of putting us into the repository's checkout directory before we get to this point.

>    ... -w /tmp/test ...

Sets the working directory for whatever it is we're about to do, in this case we're doing this here so we don't need to `cd` anywhere or use long paths once we start testing.

>    ... tonyodell/rakudo-nightly:latest bash -c ...

This is the second place to change the tag if you want to use a specific nightly for testing.  Check out the repo under the *Docker* heading above for a list of available tags.

The rest of this is fairly straightforward.  Update `apt`, install the ca-certificates package so curl can store the ca certs while updating zef mirrors (if you need system level dependencies like libcsv or whatever else then this is the place to install them), install the dependencies in the `META6.json` for the module, and then test the module.

It's as easy as that, now your Travis test builds should take far less time.  The Bench module ran CI in a little over a minute compared to around five and a half minutes.  It ran in 50s when fully optimized for that module.

## Circle CI

```yaml
version: 2
jobs:
  build:
    docker:
      - image: tonyodell/rakudo-nightly:latest

    working_directory: ~

    steps:
      - checkout
      - run:
          name: install build deps
          command: |
              apt install -y libsqlite3-dev
              zef install --deps-only .
      - run:
          name: test
          command: |
              zef test .
```

Circle CI is a little more straight forward because it runs the checkout and commands directly inside of your container.  The example above is letting circle know that you'd like to use the rakudo-nightly to test, installing dependencies using apt (because this image is based upon Ubuntu), installing dependencies, and then finally testing your module.

If you have questions, find anything broken, or would like more topics covered around testing modules with travis or circle (or ??) with docker, feel free to hit me up in freenode#perl6 @tony-o
