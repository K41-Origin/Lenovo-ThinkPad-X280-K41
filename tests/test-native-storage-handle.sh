#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

cc -std=c11 -O2 -Wall -Wextra -Werror -Wpedantic \
  "$ROOT/native/storage-handle.c" -o "$tmp/storage-handle"

"$tmp/storage-handle" --help >/dev/null
if "$tmp/storage-handle" >/dev/null 2>&1; then
  echo "FAIL: missing argument was accepted" >&2
  exit 1
fi
if "$tmp/storage-handle" /tmp/not-a-device >/dev/null 2>&1; then
  echo "FAIL: non-/dev path was accepted" >&2
  exit 1
fi
if "$tmp/storage-handle" '/dev/../../tmp/not-a-device' >/dev/null 2>&1; then
  echo "FAIL: traversal path was accepted" >&2
  exit 1
fi
if "$tmp/storage-handle" '/dev/name with spaces' >/dev/null 2>&1; then
  echo "FAIL: unsafe path characters were accepted" >&2
  exit 1
fi

echo "PASS: native helper compiles cleanly and rejects invalid CLI paths"
echo "NOT TESTED: block-device acquisition, O_EXCL contention, ioctls, diskseq, FD lifetime, and hot-unplug"
