#!/bin/sh

set -e

if [ -z "$B2_BUCKET" ]; then
  echo "B2_BUCKET is not set. Quitting."
  exit 1
fi

if [ -z "$B2_APPKEY_ID" ]; then
  echo "B2_APPKEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$B2_APPKEY" ]; then
  echo "B2_APPKEY is not set. Quitting."
  exit 1
fi

if [ -z "$SOURCE_DIR" ]; then
  echo "SOURCE_DIR is not set. Quitting."
  exit 1
fi

# optional: limit threads to reduce races (set B2_THREADS=1 in the workflow if desired)
B2_THREADS_FLAG=""
if [ -n "$B2_THREADS" ]; then
  B2_THREADS_FLAG="--threads $B2_THREADS"
fi

# ---- run ----
b2 authorize-account "${B2_APPKEY_ID}" "${B2_APPKEY}"

# run sync but don't let set -e kill the script before we inspect the error
set +e
OUT="$(
  b2 sync $B2_THREADS_FLAG --delete --replaceNewer --noProgress \
    "${SOURCE_DIR}" "${B2_BUCKET}" 2>&1
)"
RC=$?
set -e

# echo all CLI output to Actions log
printf '%s\n' "$OUT"

if [ $RC -ne 0 ]; then
  # benign race: old version already gone
  echo "$OUT" | grep -qi "File not present" && {
    echo "NOTE: Ignoring B2 'File not present' when deleting an old version."
  } || {
    echo "ERROR: b2 sync failed for a different reason. Exiting ($RC)."
    exit $RC
  }
fi
