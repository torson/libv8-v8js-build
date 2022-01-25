This builds V8 and php-v8js on Ubuntu 20.04.

Modify the versions to your needs in `build_libv8.sh` and `build_php_v8js.sh`:
```
LIBV8_VERSION
PHP_VERSION
PHP_V8JS_VERSION
```

There might be more recent forks of v8js repo, check in `build_php_v8js.sh` above `git clone` line.

# Build the docker image
```
docker build -t libv8-u2004 .
```

# Start the container and build V8 and php-v8js
```
docker run --rm -it -v $(pwd):/mount -w /mount libv8-u2004 bash

./build.sh
```

