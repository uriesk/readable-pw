#!/bin/sh

# amount of words
WORD_AMOUNT=2
# minimum length of a word
WORD_LEN_MIN=8
# max length of a word
WORD_LEN_MAX=11
# seperator set (random char will be chosen as seperator)
SEPERATORS="_.:_ "
# end char set
START_CHAR_SET=""
# start char set
END_CHAR_SET="0123456789"
# second seperator set
# file consisting of lines with "[trigram] [occurances]"
# downloaded from
TRIGRAM_FILE="./english_trigrams.txt"

[ -f "${TRIGRAM_FILE}" ] || {
  echo "Download a trigram file, unpack it and edit this script to set its filename"
  echo "http://practicalcryptography.com/cryptanalysis/letter-frequencies-various-languages"
  exit 1
}

# calculate sum of weights of all trigrams
TOTAL_WEIGHT=0
for i in `cat "${TRIGRAM_FILE}" | sed 's/.* //'`; do
  TOTAL_WEIGHT=$(($TOTAL_WEIGHT+$i))
done

# calculate how many trigrams per word will be needed
TRIGRAMS_PER_WORD=$(($WORD_LEN_MAX/3))
if [ $(($WORD_LEN_MAX%3)) -gt 0 ]; then
  TRIGRAMS_PER_WORD=$(($TRIGRAMS_PER_WORD+1))
fi

# get all needed trigrams at once and store in one large string
get_all_trigrams () {
  TMP_TRIGRAMS=""

  WEIGHTS=`shuf --random-source /dev/urandom -i "1-${TOTAL_WEIGHT}" -n $(($TRIGRAMS_PER_WORD*$WORD_AMOUNT)) | sort -h | tr '\n' ','`
  CNT=0
  while read -r line; do
    CNT=$(($CNT+${line#* }))
    while [ ${WEIGHTS%%,*} -le ${CNT} ]; do
      TMP_TRIGRAMS="${TMP_TRIGRAMS}${line% *},"
      WEIGHTS=${WEIGHTS#*,}
      if [ -z ${WEIGHTS} ]; then
        return
      fi
    done
  done < "${TRIGRAM_FILE}"
}

# generate one word out of trigrams string
generate_word () {
  TMP_WORD=""

  local CNT="${TRIGRAMS_PER_WORD}"
  while [ ${CNT} -gt 0 ]; do
    TMP_WORD="${TMP_WORD}${TMP_TRIGRAMS%%,*}"
    TMP_TRIGRAMS=${TMP_TRIGRAMS#*,}
    CNT=$((CNT-1))
  done

  # cut and captial only first letter
  local LEN=`shuf --random-source /dev/urandom -i "${WORD_LEN_MIN}-${WORD_LEN_MAX}" -n 1`
  TMP_WORD="`echo ${TMP_WORD} | cut -c1 | tr '[a-z]' '[A-Z]'``echo ${TMP_WORD} | cut -c2-$LEN | tr '[A-Z]' '[a-z]'`"
}

# get random char from string
get_random_char () {
  if [ -z $1 ]; then
    TMP_CHAR=""
    return
  fi
  local POS=`shuf --random-source /dev/urandom -i "1-${#1}" -n 1`
  TMP_CHAR=`awk -- "BEGIN {print substr (\"$1\", ${POS}, 1)}"`
}

generate_password () {
  get_random_char "${SEPERATORS}"
  local SEPERATOR=${TMP_CHAR}
  get_random_char "${START_CHAR_SET}"
  TMP_PASSWORD=""
  if [ "${TMP_CHAR}" ]; then
    TMP_PASSWORD="${TMP_CHAR}"
  fi

  get_all_trigrams

  while true; do
    generate_word
    TMP_PASSWORD="${TMP_PASSWORD}${TMP_WORD}"

    WORD_AMOUNT=$(($WORD_AMOUNT-1))
    if [ ${WORD_AMOUNT} -gt 0 ]; then
      TMP_PASSWORD="${TMP_PASSWORD}${SEPERATOR}"
    else
      get_random_char "${END_CHAR_SET}"
      if [ "${TMP_CHAR}" ]; then
       TMP_PASSWORD="${TMP_PASSWORD}${SEPERATOR}${TMP_CHAR}"
      fi
      return
    fi
  done
}

generate_password
echo "${TMP_PASSWORD}"
echo "length: ${#TMP_PASSWORD} chars"
