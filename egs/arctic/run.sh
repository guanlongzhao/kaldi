#!/bin/bash

# Copyright 2017 Guanlong Zhao
# Apache 2.0

# This is to generate log-posteriors as features

n_split=50

# Prepare data
./data_prep.sh --n_split $n_split ~/data/arctic/ ./data/test

# Get log-posteriors
# one speaker
./make_posteriors.sh --nj 10 ./data/test/split$n_split\utt/1 ./data/test/split$n_split\utt/1/post \
 ./exp/nnet7a_960_gpu ./data/test/split$n_split\utt/1/post ./exp/dump_post_log/1

# another speaker
./make_posteriors.sh --nj 10 ./data/test/split$n_split\utt/9 ./data/test/split$n_split\utt/9/post \
./exp/nnet7a_960_gpu ./data/test/split$n_split\utt/9/post ./exp/dump_post_log/9

# another speaker
./make_posteriors.sh --nj 10 ./data/test/split$n_split\utt/38 ./data/test/split$n_split\utt/38/post \
./exp/nnet7a_960_gpu ./data/test/split$n_split\utt/38/post ./exp/dump_post_log/38