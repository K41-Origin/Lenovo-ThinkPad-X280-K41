#!/usr/bin/env bash
# Conservative Caelestia log classifier. Prints one finding per line.
# Arguments: LOG_FILE SCHEME_FILE
k41_classify_caelestia_log() {
  local log_file=$1 scheme_file=$2 bluetooth_active=${3:-0} rtkit_installed=${4:-0}
  local filtered
  filtered="$(mktemp)" || return 2

  # Classify the scheme condition separately so a resolved startup warning
  # cannot be re-detected by the generic QML failure matcher.
  grep -Eiv 'Read of .+scheme\.json failed: File does not exist' "$log_file" >"$filtered" || :
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
  if [[ $bluetooth_active != 1 ]] && grep -Eiq 'org\.bluez' "$filtered"; then
    printf '%s\n' 'bluez-service-inactive'
  fi
  if [[ $rtkit_installed != 1 ]] && grep -Eiq 'RTKit' "$filtered"; then
    printf '%s\n' 'rtkit-package-missing'
  fi
  rm -f -- "$filtered"
}
