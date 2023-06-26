#!/usr/bin/env bash

#export BATS_NO_PARALLELIZE_ACROSS_FILES=1
export BATS_NUMBER_OF_PARALLEL_JOBS=1

bashcov --skip-uncovered ./test/bats/bin/bats test/test.bats

