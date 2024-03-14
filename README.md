This builds V8 and php-v8js on Ubuntu 20.04 Focal or 22.04 Jammy, depending which docker image you use .

Modify the versions to your needs in `build.sh`:
```
LIBV8_BUILD_VERSIONS
PHP_VERSION
PHP_V8JS_REPO
PHP_V8JS_REPO_COMMIT
PHP_V8JS_VERSION
```

There might be more recent forks of v8js repo: https://github.com/phpv8/v8js/forks . There's a convenient page showing how many commits ahead or behind the forks are from the base repo : https://useful-forks.github.io/?repo=phpv8/v8js . You need to add your Github Account access token to the page (upper right corner) as Github rate-limits anonymous API requests.

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
./build.sh
```

The result are 2 .deb files, example:
```
libv8/libv8_12.0.267-jammy_amd64.deb
v8js/php8.3-v8js_2.1.2-phpv8-v8js-1b521b3-libv8-12.0.267-jammy_amd64.deb
```
