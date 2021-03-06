#!/bin/bash

if [[ -n "${DEBUG}" ]]; then
  set -x
fi

for PARAM in STREAM_URL DATA_DIR STREAM_DELAY MAX_AGE; do
  if [[ -z "${!PARAM}" ]]; then
    echo "${PARAM} must be set"
    exit 1
  fi
done

BASE_URL="$(dirname "${STREAM_URL}")"
STREAM_DELAY_MINUTES=$(echo "${STREAM_DELAY} / 60" | bc -l)
MAX_AGE_MINUTES=$(echo "${MAX_AGE} / 60" | bc -l)
CURL_DEBUG_FLAG=$([[ -n "${DEBUG}" ]] && printf -- '-v' || printf -- '-s')
FIND_DEBUG_FLAGS=$([[ -n "${DEBUG}" ]] && printf -- '-print' || printf -- '')
LOCK_DIR="/tmp"

function get_index () {
  curl ${CURL_DEBUG_FLAG} --max-time 5 "${STREAM_URL}"
}

function list_ts_files () {
  local TEXT="${1}"

  echo "${TEXT}" | grep '.ts$'
}

function lock_file () {
  local INPUT="${1}"
  local HASH="$(echo -n "${INPUT}" | md5sum | cut -d' ' -f1)"

  echo "${LOCK_DIR}/${HASH}"
}

function download_ts_files () {
  local FILE_LIST="${1}"

  local IFS=$'\n'
  for TS_PATH in ${FILE_LIST}; do
    local SAVE_PATH="${DATA_DIR}/${TS_PATH}"
    local SAVE_DIR="$(dirname "${SAVE_PATH}")"

    mkdir -p "${SAVE_DIR}"
    if [[ ! -f "${SAVE_PATH}" || $(wc -c "${SAVE_PATH}" | cut -d' ' -f1) -lt 50000 ]]; then
      local TS_URL="${BASE_URL}/${TS_PATH}"
      local LOCK_FILE="$(lock_file "${TS_URL}")"

      flock -n "${LOCK_FILE}" curl ${CURL_DEBUG_FLAG} --max-time 15 ${TS_URL} -o "${SAVE_PATH}"
    fi
  done
}

function shift_date () {
  local ORIGINAL_DATE="${1}"
  local OFFSET="${2}"

  date '+%Y-%m-%dT%H:%M:%S.%3NZ' --utc --date="${ORIGINAL_DATE}+${OFFSET} seconds"
}

function shift_index_dates () {
  local TEXT="${1}"

  local IFS=$'\n'
  for LINE in ${TEXT}; do
    if [[ "${LINE}" =~ "EXT-X-PROGRAM-DATE-TIME" ]]; then
      local DATE=$(echo "${LINE}" | sed -E 's/^[^:]+://')
      local SHIFTED_DATE="$(shift_date "${DATE}" "${STREAM_DELAY}")"
      echo "#EXT-X-PROGRAM-DATE-TIME:${SHIFTED_DATE}"
    else
      echo "${LINE}"
    fi
  done
}

function write_index () {
  local TEXT="${1}"
  local TIMESTAMP=$(date +%Y-%m-%dT%H-%M-%S)

  echo "${TEXT}" >| "${DATA_DIR}/index-${TIMESTAMP}.m3u8"
}

function update_symlink () {
  local DELAYED_INDEX=$(find "${DATA_DIR}" -name 'index-*.m3u8' -mmin "-${STREAM_DELAY_MINUTES}" | sort | head -n 1)
  if [[ -n "$DELAYED_INDEX" ]]; then
    local INDEX_FILENAME="$(basename "${DELAYED_INDEX}")"
    ln -snf "${INDEX_FILENAME}" "${DATA_DIR}/index.m3u8"
  fi
}

function delete_old_files () {
  find "${DATA_DIR}" -depth -mindepth 1 -mmin "+${MAX_AGE_MINUTES}" \
    \( \( -name '*.m3u8' -o -name '*.ts' \) -o \( -type d -empty \) \) ${FIND_DEBUG_FLAGS} -delete
}

function main () {
  while true; do

    update_symlink
    delete_old_files &

    local INDEX_CONTENT="$(get_index)"
    local TS_FILES="$(list_ts_files "$INDEX_CONTENT")"
    if [[ -z "${TS_FILES}" ]]; then
      echo 'No .ts files found'
      continue
    fi

    local SHIFTED_INDEX="$(shift_index_dates "${INDEX_CONTENT}")"

    write_index "${SHIFTED_INDEX}"
    download_ts_files "${TS_FILES}" &

    sleep 2

  done
}

main
