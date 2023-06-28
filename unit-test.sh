#!/usr/bin/env bash
set -euo pipefail
#export BATS_NO_PARALLELIZE_ACROSS_FILES=1
export BATS_NUMBER_OF_PARALLEL_JOBS=1
rm -rf test/test-output/*
./test/bats/bin/bats "test/test.bats" -T --gather-test-outputs-in "test/test-output" --print-output-on-failure

