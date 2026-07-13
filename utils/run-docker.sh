#!/usr/bin/env bash
##===- utils/run-docker.sh - start docker container ----------*- Script -*-===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
##===----------------------------------------------------------------------===##
#
# Make it easier to run tests in a clean testing environment (the same as the
# nightly tests) to tease out implicit dependencies on your local environment.
#
# Assumes that you've got a working docker set up which your user is authorized
# to invoke. If you lack this, follow these guides:
# 1) https://docs.docker.com/engine/install/ubuntu/
# 2) https://docs.docker.com/engine/install/linux-postinstall/
#       "Manage Docker as a non-root user"
#       "Configure Docker to start on boot"
#
##===----------------------------------------------------------------------===##

CMD=${1:-"./utils/run-tests-docker.sh"}
VER=${2:-"v20"}
REPO_ROOT=$(cd "$(dirname "$BASH_SOURCE[0]")/.." && pwd)

# Bind-mount the caller's working directory too when it lives outside the
# CIRCT repo, so that commands operating on files outside the CIRCT tree
# (e.g. running firtool on a user project) can access them at the same
# absolute path inside the container.
CALLER_PWD="$PWD"
EXTRA_MOUNT=""
if [ "$CALLER_PWD" != "$REPO_ROOT" ] && [[ "$CALLER_PWD" != "$REPO_ROOT"/* ]]; then
  EXTRA_MOUNT="-v $CALLER_PWD:$CALLER_PWD"
fi

cd $REPO_ROOT
# Only allocate a TTY when stdin is actually a terminal. Running with `-t`
# from a non-interactive context (e.g. `make`) fails with "cannot attach
# stdin to a TTY-enabled container because stdin is not a terminal".
DOCKER_RUN_FLAGS="-i"
if [ -t 0 ]; then
  DOCKER_RUN_FLAGS="-it"
fi
docker run $DOCKER_RUN_FLAGS --rm -v $REPO_ROOT:$REPO_ROOT $EXTRA_MOUNT -u $UID:$(id -g) -w $REPO_ROOT \
  ghcr.io/circt/images/circt-integration-test:$VER $CMD
