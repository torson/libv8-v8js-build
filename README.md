This builds V8 and php-v8js on Ubuntu 20.04 Focal or 22.04 Jammy, depending which docker image you use .

Modify the versions to your needs in `build_libv8.sh` and `build_php_v8js.sh`:
```
LIBV8_VERSION
PHP_VERSION
PHP_V8JS_VERSION
```

There might be more recent forks of v8js repo, check in `build_php_v8js.sh` above `git clone` line.

# Steps

### 1. Start and get into the Ubuntu docker container.
This will mount the current path. All files are going to be created inside folder `build`.
With using `--rm` the container and all it's content (but not the mounted current path) will be removed after you exit.

```
# 20.04 Focal
docker run --rm -it -v $(pwd):/mount -w /mount ubuntu:focal

# 22.04 Jammy
docker run --rm -it -v $(pwd):/mount -w /mount ubuntu:jammy
```

### 2. Inside the container run:

```
./prepare.sh
./build.sh
```

The result are 2 .deb files:
```
build/libv8/libv8_8.0.426.30-DISTRIB_amd64.deb
build/v8js/php7.2-v8js_2.1.2-amuluowin-3d64f08-DISTRIB_amd64.deb
```
