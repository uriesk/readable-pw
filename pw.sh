#!/bin/sh

# amount of passwords to create
PW_AMOUNT=15
# amount of words
WORD_AMOUNT=2
# minimum length of a word
WORD_LEN_MIN=7
# max length of a word
WORD_LEN_MAX=11
# seperator set (random char will be chosen as seperator)
SEPERATORS="_.:_ "
# end char set
START_CHAR_SET=""
# start char set
END_CHAR_SET="0123456789"
# chars to exclude
EXCLUDED_CHARS=""
# colored output ("y" means yes, otherwise no)
COLORED="y"
# sort by rarest n-gram
SORT="y"
# second seperator set
# file consisting of lines with "[trigram] [occurances]"
# downloaded from
TRIGRAM_FILE="./english_trigrams.txt"

L="\e[34m"
LG="\e[36m"
EC="\e[0m"

[ -f "${TRIGRAM_FILE}" ] || {
  echo "Download a trigram file, unpack it and edit this script to set its filename"
  echo "http://practicalcryptography.com/cryptanalysis/letter-frequencies-various-languages/"
  exit 1
}

# calculate sum of weights of all trigrams
TOTAL_WEIGHT=0
for i in `cat "${TRIGRAM_FILE}" | sed 's/.* //'`; do
  TOTAL_WEIGHT=$(($TOTAL_WEIGHT+$i))
done

# get all needed trigrams at once and store in one large string
get_all_trigrams () {
  TMP_TRIGRAMS=""
  TMP_WORD_LENGTHS=""
  TMP_RAREST_TRIGRAM=""

  local TRIGRAMS_AMOUNT=0
  # calculate lengths of words and needed amount of trigrams
  local CNT=${WORD_AMOUNT}
  while [ ${CNT} -gt 0 ]; do
    local LEN=`shuf --random-source /dev/urandom -i "${WORD_LEN_MIN}-${WORD_LEN_MAX}" -n 1`
    TMP_WORD_LENGTHS="${TMP_WORD_LENGTHS}${LEN},"

    TRIGRAMS_AMOUNT=$(($TRIGRAMS_AMOUNT+$LEN/3))
    if [ $(($LEN%3)) -gt 0 ]; then
      TRIGRAMS_AMOUNT=$(($TRIGRAMS_AMOUNT+1))
    fi

    CNT=$(($CNT-1))
  done

  WEIGHTS=`shuf --random-source /dev/urandom -i "1-${TOTAL_WEIGHT}" -n ${TRIGRAMS_AMOUNT} | sort -h | tr '\n' ','`
  CNT=0
  while read -r line; do
    CNT=$(($CNT+${line#* }))
    while [ ${WEIGHTS%%,*} -le ${CNT} ]; do
      TMP_TRIGRAMS="${TMP_TRIGRAMS}${line% *},"
      WEIGHTS=${WEIGHTS#*,}
      if [ -z ${WEIGHTS} ]; then
        TMP_RAREST_TRIGRAM=`echo $line | sed 's/ /\//'`
        # shuffle order
        TMP_TRIGRAMS=`echo ${TMP_TRIGRAMS} | tr ',' '\n' | grep . | shuf --random-source /dev/urandom | tr '\n' ','`
        return
      fi
    done
  done < "${TRIGRAM_FILE}"
}

# generate one word out of trigrams string TMP_TRIGRAMS with length TMP_WORD_LENGTHS
generate_word () {
  TMP_WORD=""

  local WORD_LENGTH=${TMP_WORD_LENGTHS%%,*}
  if [ "${WORD_LENGTH}" ]; then
    TMP_WORD_LENGTHS=${TMP_WORD_LENGTHS#*,}

    local LEN=${WORD_LENGTH}
    while [ ${LEN} -gt 0 ]; do
      LEN=$(($LEN-3))
      TMP_WORD="${TMP_WORD}${TMP_TRIGRAMS%%,*}"
      TMP_TRIGRAMS=${TMP_TRIGRAMS#*,}
    done
    # cut and captial only first letter
    TMP_WORD="`echo ${TMP_WORD} | cut -c1 | tr '[a-z]' '[A-Z]'``echo ${TMP_WORD} | cut -c2-${WORD_LENGTH} | tr '[A-Z]' '[a-z]'`"
  fi
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

# generate one password
generate_password () {
  while true; do
    TMP_PASSWORD=""

    get_random_char "${SEPERATORS}"
    local SEPERATOR=${TMP_CHAR}

    get_random_char "${START_CHAR_SET}"
    if [ "${TMP_CHAR}" ]; then
      TMP_PASSWORD="${TMP_CHAR}"
    fi

    get_all_trigrams
    generate_word
    TMP_PASSWORD="${TMP_PASSWORD}${TMP_WORD}"
    generate_word
    while [ "${TMP_WORD}" ]; do
      TMP_PASSWORD="${TMP_PASSWORD}${SEPERATOR}${TMP_WORD}"
      generate_word
    done

    get_random_char "${END_CHAR_SET}"
    if [ "${TMP_CHAR}" ]; then
     TMP_PASSWORD="${TMP_PASSWORD}${SEPERATOR}${TMP_CHAR}"
    fi

    if [ -z "${EXCLUDED_CHARS}" ] || echo "${TMP_PASSWORD}" | sed "/[${EXCLUDED_CHARS}]/q1" >/dev/null; then
      return
    fi
  done
}

# generate and print all passwords
generate_passwords () {
  while [ ${PW_AMOUNT} -gt 0 ]; do
    generate_password
    LEN=${#TMP_PASSWORD}
    #pad password for output
    TMP_PASSWORD=`awk -- "BEGIN {print substr (\"$TMP_PASSWORD                          \", 1, $(($WORD_LEN_MAX*$WORD_AMOUNT+2)))}"`
    if [ "${COLORED}" = "y" ]; then
      printf "${TMP_PASSWORD} \t${L}length: ${LG}${LEN} \t${L}rarest n-gram: ${LG}${TMP_RAREST_TRIGRAM}${EC}\n"
    else
      printf "${TMP_PASSWORD} \tlength: ${LEN} \trarest n-gram: ${TMP_RAREST_TRIGRAM}\n"
    fi
    PW_AMOUNT=$(($PW_AMOUNT-1))
  done
}

if [ "${SORT}" = "y" ]; then
  generate_passwords | sort -t'/' -n -k2
else
  generate_passwords
fi
