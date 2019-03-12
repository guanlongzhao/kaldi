#!/bin/bash

# Copyright 2017 Guanlong Zhao
# Apache 2.0

n_split=50

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. utils/parse_options.sh || exit 1;

# Input
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <src-dir> <dst-dir>"
  echo "e.g.: $0 /export/data/arctic data/train"
  echo "options:"
  echo "  --n_split 50"
  exit 1
fi

src=$1 # for GZ: /home/guanlong/data/arctic
dst=$2 # for GZ: data/train

# Setting
mkdir -p $dst || exit 1;
[ ! -d $src ] && echo "$0: no such directory $src" && exit 1;
wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk
spk2gender=$dst/spk2gender; [[ -f $spk2gender ]] && rm $spk2gender

# Get wav.scp and utt2spk
# all spakers' root dirs
for reader_dir in $(find -L $src -mindepth 1 -maxdepth 1 -type d | sort); do
    reader=$(basename $reader_dir) # speaker's name, e.g., 'awb'
    wav_dir=$reader_dir/recordings # dir that contains wave files
    [ ! -d $wav_dir ] && echo "$0: expected dir $wav_dir to exist" && exit 1;
    # create wav.scp, mapping from utt_id to utt location
    find -L $wav_dir/ -iname "*.wav" | sort | xargs -I% basename % .wav | \
     awk -v "dir=$wav_dir" -v "reader=$reader" '{printf "%s_%s %s/%s.wav\n", reader,\
     $0, dir, $0}' >>$wav_scp || exit 1
    # create utt2spk
    find -L $wav_dir/ -iname "*.wav" | sort | xargs -I% basename % .wav | \
     awk -v "reader=$reader" '{printf "%s_%s %s\n", reader, $0, reader}' >>$utt2spk || exit 1
done

# Get spk2utt
spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1

# Get spk2gender
[ ! -f $src/spk2gender ] && echo "$0: expected file $src/spk2gender to exist" && exit 1;
cp $src/spk2gender $spk2gender

# Validation
utils/validate_data_dir.sh --no-feats --no-text $dst || exit 1;

# Data split
utils/split_data.sh --per-utt $dst $n_split

# Get MFCCs
splits=$n_split
# splits=1 # for debug
mkdir -p $dst/make_mfcc_log/
mkdir -p $dst/mfcc/
for part in $(seq $splits); do 
  steps/make_mfcc.sh --cmd utils/run.pl --mfcc-config ./conf/mfcc.conf --nj 4 --write-utt2num-frames true \
    $dst/split$n_split\utt/$part/ $dst/make_mfcc_log/$part $dst/mfcc/$part

# Get CMVN stats
  steps/compute_cmvn_stats.sh $dst/split$n_split\utt/$part/ $dst/make_mfcc_log/$part $dst/mfcc/$part
done