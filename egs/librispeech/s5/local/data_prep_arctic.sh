#!/bin/bash

# Copyright 2017-2019 Guanlong Zhao
# Apache 2.0

# The expected organization is,
# speaker_id/
#	/recordings
#   /ortho_transcripts
#	/spk2gender (file)

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh # source the path.
. parse_options.sh || exit 1;

# Input
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <src-dir> <dst-dir>"
  echo "e.g.: $0 /export/data/speaker data/speaker"
  exit 1
fi

src=$1 # for GZ: /home/guanlong/data/speaker, where the input files are
dst=$2 # for GZ: ./data/speaker, where to put the output

# Setting
mkdir -p $dst || exit 1;
[ ! -d $src ] && echo "$0: no such directory $src" && exit 1;
wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk
spk2gender=$dst/spk2gender; [[ -f $spk2gender ]] && rm $spk2gender

# Get wav.scp, utt2spk, and text
reader_dir=$src
reader=$(basename $reader_dir) # speaker's name, e.g., 'awb'
wav_dir=$reader_dir/recordings # dir that contains wave files
[ ! -d $wav_dir ] && echo "$0: expected dir $wav_dir to exist" && exit 1;
lab_dir=$reader_dir/ortho_transcripts # dir that contains transcription files
[ ! -d $lab_dir ] && echo "$0: expected dir $lab_dir to exist" && exit 1;
# create wav.scp, mapping from utt_id to utt location
find -L $wav_dir/ -iname "*.wav" | sort | xargs -I% basename % .wav | \
awk -v "dir=$wav_dir" -v "reader=$reader" '{printf "%s_%s %s/%s.wav\n", reader,\
$0, dir, $0}' >>$wav_scp || exit 1
# create utt2spk
find -L $wav_dir/ -iname "*.wav" | sort | xargs -I% basename % .wav | \
awk -v "reader=$reader" '{printf "%s_%s %s\n", reader, $0, reader}' >>$utt2spk || exit 1
# create text
for lab in ${lab_dir}/*.lab; do
  filename="$(basename $lab)"
  filepath="$(dirname $lab)"
  (
    printf "${reader}_${filename%.*} "
    cat "$lab" | awk '{print toupper($0)}'
  ) >>$trans
done

# Get spk2utt
spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1

# Get spk2gender
[ ! -f $src/spk2gender ] && echo "$0: expected file $src/spk2gender to exist" && exit 1;
cp $src/spk2gender $spk2gender

# Some verification
ntrans=$(wc -l <$trans)
nutt2spk=$(wc -l <$utt2spk)
! [ "$ntrans" -eq "$nutt2spk" ] && \
  echo "Inconsistent #transcripts($ntrans) and #utt2spk($nutt2spk)" && exit 1;

utils/data/get_utt2dur.sh $dst 1>&2 || exit 1

utils/validate_data_dir.sh --no-feats $dst || exit 1;

echo "$0: successfully prepared data in $dst"

exit 0
