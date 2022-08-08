#!/bin/bash
set -e

./prepare.sh

./build_libv8.sh

./build_php_v8js.sh
