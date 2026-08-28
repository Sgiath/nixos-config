#!/usr/bin/env bash

set -uo pipefail

readonly COREDUMP_MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1
readonly UNIT_FAILED_MESSAGE_ID=d9b373ed55a64feb8242e02dbe79a49c
readonly dedupe_seconds=${SYSTEM_FAILURE_WATCHER_DEDUPE_SECONDS:-300}
readonly session=${SYSTEM_FAILURE_WATCHER_TMUX_SESSION:-nixos}
readonly working_directory=${SYSTEM_FAILURE_WATCHER_WORKING_DIRECTORY:-$HOME/nixos}
readonly tmux_bin=${SYSTEM_FAILURE_WATCHER_TMUX:-tmux}
readonly omp_bin=${SYSTEM_FAILURE_WATCHER_OMP:-omp}
readonly journalctl_bin=${SYSTEM_FAILURE_WATCHER_JOURNALCTL:-journalctl}
readonly jq_bin=${SYSTEM_FAILURE_WATCHER_JQ:-jq}

declare -A last_dispatched

log() {
  printf 'system-failure-watcher: %s\n' "$*" >&2
}

dispatch() {
  local key=$1 window_label=$2 prompt=$3
  local now=${EPOCHSECONDS:-0}
  local last=${last_dispatched[$key]:-0}

  if ((now - last < dedupe_seconds)); then
    log "deduplicated $key"
    return 0
  fi

  if ! "$tmux_bin" has-session -t "$session:" 2>/dev/null; then
    log "tmux session '$session' is not running; skipped $key"
    return 0
  fi

  window_label=${window_label//[^a-zA-Z0-9_.-]/-}
  window_label=${window_label:0:40}
  [[ -n $window_label ]] || window_label=unknown

  if "$tmux_bin" new-window -d -t "$session:" -c "$working_directory" \
    -n "failed-$window_label" "$omp_bin" "$prompt"; then
    last_dispatched[$key]=$now
    log "opened tmux window for $key"
  else
    log "failed to open tmux window for $key"
    return 1
  fi
}

handle_coredump() {
  local entry=$1 uid comm pid exe signal unit name prompt

  IFS=$'\t' read -r uid comm pid exe signal unit < <(
    "$jq_bin" -r '
      def field: if . == null or . == "" then "-" else . end;
      [
        (._UID | field),
        (.COREDUMP_COMM | field),
        (.COREDUMP_PID | field),
        (.COREDUMP_EXE | field),
        (.COREDUMP_SIGNAL_NAME | field),
        ((.COREDUMP_USER_UNIT // .COREDUMP_UNIT) | field)
      ] | @tsv
    ' <<<"$entry" 2>/dev/null
  )

  [[ $uid =~ ^[0-9]+$ && $uid -eq $UID ]] || return 0
  [[ $pid =~ ^[0-9]+$ ]] || return 0

  # A failed service produces its own unit event. Let that event own the
  # diagnosis rather than opening a second window for the same failure.
  [[ $unit == *.service ]] && return 0

  name=$comm
  [[ $exe == /* ]] && name=${exe##*/}
  name=${name##*/}
  [[ -n $name && $name != "-" && $name != "." && $name != ".." ]] || name=unknown

  prompt="Investigate the application crash for '$name' on this host. The recorded PID is $pid, the executable is '$exe', and the signal is '$signal'. Start with 'coredumpctl info $pid' and inspect the matching journal entries and stack trace. Establish the root cause and fix it in this NixOS repository when the failure is configuration-owned. Do not merely suppress the crash or restart the application. If the fault is upstream, collect enough evidence for a useful upstream report."

  dispatch "crash:$exe" "$name" "$prompt"
}

handle_unit_failure() {
  local entry=$1 unit user_unit uid scope prompt

  IFS=$'\t' read -r unit user_unit uid < <(
    "$jq_bin" -r '
      def field: if . == null or . == "" then "-" else . end;
      [(.UNIT | field), (.USER_UNIT | field), (._UID | field)] | @tsv
    ' <<<"$entry" 2>/dev/null
  )

  if [[ $unit != "-" ]]; then
    scope=system
  elif [[ $user_unit != "-" && $uid =~ ^[0-9]+$ && $uid -eq $UID ]]; then
    scope=user
    unit=$user_unit
  else
    return 0
  fi

  [[ $unit == *.service ]] || return 0
  [[ $unit != system-failure-watcher.service ]] || return 0

  if [[ $scope == user ]]; then
    prompt="Investigate the failed systemd user service '$unit' on this host. Start with 'systemctl --user status $unit' and 'journalctl --user -u $unit -b --no-pager'. Establish the root cause and fix it in this NixOS repository when the service is configuration-owned. Do not merely restart the service, reset its failed state, or suppress the error."
  else
    prompt="Investigate the failed systemd system service '$unit' on this host. Start with 'systemctl status $unit' and 'journalctl -u $unit -b --no-pager'. Establish the root cause and fix it in this NixOS repository when the service is configuration-owned. Do not merely restart the service, reset its failed state, or suppress the error."
  fi

  dispatch "service:$scope:$unit" "$unit" "$prompt"
}

consume() {
  local entry message_id

  while IFS= read -r entry; do
    message_id=$("$jq_bin" -r '.MESSAGE_ID // ""' <<<"$entry" 2>/dev/null) || continue

    case "$message_id" in
      "$COREDUMP_MESSAGE_ID") handle_coredump "$entry" ;;
      "$UNIT_FAILED_MESSAGE_ID") handle_unit_failure "$entry" ;;
    esac
  done
}

case ${1:-} in
  --stdin)
    consume
    ;;
  "")
    log "watching service failures and application crashes for tmux session '$session'"
    "$journalctl_bin" --follow --lines=0 --output=json \
      "MESSAGE_ID=$COREDUMP_MESSAGE_ID" \
      "MESSAGE_ID=$UNIT_FAILED_MESSAGE_ID" | consume
    ;;
  *)
    printf 'usage: system-failure-watcher [--stdin]\n' >&2
    exit 2
    ;;
esac
