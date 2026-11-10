#!/usr/bin/env bash
# Shared, side-effect-free helpers for the installer.
# Public functions: k41::log_info, k41::log_warn, k41::log_error.
# Callers must never pass passwords, keys, tokens, or other secrets to log helpers.

k41::log_info() {
  [[ $# -eq 1 ]] || {
    printf '%s\n' 'ERROR: k41::log_info expects one message argument.' >&2
    return 2
  }
  printf 'INFO: %s\n' "$1" >&2
}

k41::log_warn() {
  [[ $# -eq 1 ]] || {
    printf '%s\n' 'ERROR: k41::log_warn expects one message argument.' >&2
    return 2
  }
  printf 'WARN: %s\n' "$1" >&2
}

k41::log_error() {
  [[ $# -eq 1 ]] || {
    printf '%s\n' 'ERROR: k41::log_error expects one message argument.' >&2
    return 2
  }
  printf 'ERROR: %s\n' "$1" >&2
}
