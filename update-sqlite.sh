#!/usr/bin/env bash

#apply patch file for this version of update
git apply Dockerfile.template-sqlite.patch

./update.sh "$@"
