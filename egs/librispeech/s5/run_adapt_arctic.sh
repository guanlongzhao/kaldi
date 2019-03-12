#!/bin/bash

# Copyright 2019 Guanlong Zhao
# Apache 2.0

# cd $KALDI_ROOT/egs/librispeech/s5
# Change to the root of your speaker
data=/media/guanlong/DATA1/GDriveTAMU/PSI-Lab/corpora/arctic/rms
sdir=exp/nnet7a_960_gpu
dir=/media/guanlong/DATA1/exp/am-adapt/exp/nnet7a_960_arctic_gpu_tune

. ./cmd.sh # Change to run.pl
. ./path.sh

# Get all sentences available
local/data_prep_arctic.sh $data data/all_arctic

# Split the train and test set
utils/subset_data_dir.sh --first data/all_arctic 1032 data/train_arctic
utils/subset_data_dir.sh --last data/all_arctic 100 data/test_arctic

# Extract mfccs
mfccdir=mfcc
for part in train_arctic test_arctic; do
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 4 data/$part exp/make_mfcc/$part $mfccdir
  steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
done

# Do initial decoding before adaptation
for test in train_arctic test_arctic; do
  steps/nnet2/decode.sh --nj 1 --cmd "$decode_cmd" \
    exp/tri6b/graph_tgsmall data/$test $dir/decode_tgsmall_$test || exit 1;
  steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
    data/$test $dir/decode_{tgsmall,tgmed}_$test || exit 1;
  steps/lmrescore_const_arpa.sh \
    --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
    data/$test $dir/decode_{tgsmall,tglarge}_$test || exit 1;
  
  # Get best WER
  for x in $dir/decode_tgsmall_$test; do 
    [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
  done
  for x in $dir/decode_tgmed_$test; do 
    [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
  done
  for x in $dir/decode_tglarge_$test; do 
    [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
  done
done

# When using data from RMS
# Test set (100 utts)
# tgsmall: WER 4.77 [ 42 / 880, 7 ins, 3 del, 32 sub ] exp/nnet7a_960_gpu/decode_tgsmall_test_arctic/wer_12_0.5
# tgmed: WER 3.75 [ 33 / 880, 6 ins, 2 del, 25 sub ] exp/nnet7a_960_gpu/decode_tgmed_test_arctic/wer_11_0.5
# tglarge: WER 2.50 [ 22 / 880, 7 ins, 2 del, 13 sub ] exp/nnet7a_960_gpu/decode_tglarge_test_arctic/wer_12_1.0
# Training set (1032 utts)
# tgsmall: WER 7.81 [ 717 / 9177, 88 ins, 70 del, 559 sub ] exp/nnet7a_960_gpu/decode_tgsmall_train_arctic/wer_12_0.5
# tgmed: WER 6.66 [ 611 / 9177, 76 ins, 62 del, 473 sub ] exp/nnet7a_960_gpu/decode_tgmed_train_arctic/wer_13_0.5
# tglarge: WER 4.23 [ 388 / 9177, 68 ins, 35 del, 285 sub ] exp/nnet7a_960_gpu/decode_tglarge_train_arctic/wer_12_1.0

# Get alignment
steps/align_fmllr.sh --nj 1 --cmd "$train_cmd" \
  data/train_arctic data/lang_test_tglarge exp/tri6b exp/tri6b_align_arctic_tglarge

# Prepare retraining egs
echo "$0: calling get_egs.sh"
samples_per_iter=400
num_jobs_nnet=4
get_egs_stage=0
cmd=run.pl
io_opts="--max-jobs-run 15"
steps/nnet2/get_egs.sh \
    --samples-per-iter $samples_per_iter \
    --num-jobs-nnet $num_jobs_nnet --stage $get_egs_stage \
    --cmd "$cmd" --io-opts "$io_opts" \
    data/train_arctic data/lang_test_tglarge exp/tri6b_align_arctic_tglarge $dir || exit 1;

# Train more
num_threads=1 # this enables us to use GPU code if we have just one thread.
steps/nnet2/train_more.sh --num-epochs 10 --num-threads $num_threads \
    --learning-rate-factor 0.2 \
    $sdir/final.mdl $dir/egs $dir

# Test after speaker adaptive training
steps/nnet2/decode.sh --nj 1 --cmd "$decode_cmd" \
    --transform-dir exp/tri6b_align_arctic \
    exp/tri6b/graph_tgsmall data/$test $dir/decode_tgsmall_$test