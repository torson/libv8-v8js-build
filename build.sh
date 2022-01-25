#!/bin/bash
set -e

./build_libv8.sh

./build_php_v8js.sh
