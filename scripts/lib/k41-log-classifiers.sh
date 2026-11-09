#!/usr/bin/env bash
# Conservative Caelestia log classifier. Prints one finding per line.
# Arguments: LOG_FILE SCHEME_FILE
k41_classify_caelestia_log() {
  local log_file=$1 scheme_file=$2
  local filtered
  filtered="$(mktemp)" || return 2
  if [[ -s $scheme_file ]]; then
    # Ignore only the exact stale startup warning for the scheme that now exists.
    grep -Eiv 'Read of .+scheme\.json failed: File does not exist' "$log_file" >"$filtered" || :
  else
    cp -- "$log_file" "$filtered"
  fi
  # A missing .face is an optional avatar resource, not a shell failure.
  sed -E '/Source file does not exist.*\.face([[:space:]]|$)/Id' "$filtered" >"$filtered.tmp"
  mv -- "$filtered.tmp" "$filtered"

  if [[ ! -s $scheme_file ]] &&
     grep -Eiq 'Read of .+scheme\.json failed: File does not exist' "$log_file"; then
    printf '%s\n' 'scheme-missing'
  fi
  if grep -Eiq '(^|[[:space:]])(fatal|critical):|QML.*(Error|failed)|failed to load.*(QML|plugin|module)|TypeError:|ReferenceError:' "$filtered"; then
    printf '%s\n' 'runtime-error'
  fi
  if grep -Eiq 'Source file does not exist' "$filtered"; then
    printf '%s\n' 'missing-resource'
  fi
  rm -f -- "$filtered"
}
