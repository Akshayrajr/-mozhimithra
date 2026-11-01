#!/bin/sh
set -eu

data_dir="${PIPER_DATA_DIR:-/voices}"
voice_list="${PIPER_VOICES:-ar_JO-kareem-medium,de_DE-thorsten-medium,en_US-lessac-medium,es_ES-sharvard-medium,fr_FR-siwis-medium,hi_IN-rohan-medium,ml_IN-meera-medium,te_IN-maya-medium,zh_CN-huayan-medium}"
default_voice="${PIPER_DEFAULT_VOICE:-en_US-lessac-medium}"
mkdir -p "$data_dir"

old_ifs="$IFS"
IFS=','
set -- $voice_list
IFS="$old_ifs"

found_default=false
for voice in "$@"; do
  case "$voice" in
    *[!A-Za-z0-9_-]*|'')
      echo "Invalid Piper voice identifier." >&2
      exit 1
      ;;
  esac
  if [ "$voice" = "$default_voice" ]; then
    found_default=true
  fi
  python -m piper.download_voices --data-dir "$data_dir" "$voice"
done

if [ "$found_default" != true ]; then
  echo "PIPER_DEFAULT_VOICE must be included in PIPER_VOICES." >&2
  exit 1
fi

exec python -m piper.http_server \
  --host 0.0.0.0 \
  --port 5000 \
  --data-dir "$data_dir" \
  -m "$default_voice"
