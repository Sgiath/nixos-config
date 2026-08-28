#!/usr/bin/env bash

set -euo pipefail

watcher=${1:-./system-failure-watcher.sh}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == has-session ]]; then
  [[ ${MOCK_TMUX_SESSION_RUNNING:-1} == 1 ]]
  exit
fi
printf '%q ' "$@" >>"$MOCK_TMUX_LOG"
printf '\n' >>"$MOCK_TMUX_LOG"
EOF
chmod +x "$tmp/tmux"

cat >"$tmp/omp" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
chmod +x "$tmp/omp"

export SYSTEM_FAILURE_WATCHER_TMUX="$tmp/tmux"
export SYSTEM_FAILURE_WATCHER_OMP="$tmp/omp"
export SYSTEM_FAILURE_WATCHER_JQ=jq
export SYSTEM_FAILURE_WATCHER_DEDUPE_SECONDS=300
export SYSTEM_FAILURE_WATCHER_WORKING_DIRECTORY=/home/sgiath/nixos
export MOCK_TMUX_LOG="$tmp/tmux.log"

unit_event=$(jq -cn \
  --arg uid "$UID" \
  '{MESSAGE_ID:"d9b373ed55a64feb8242e02dbe79a49c",USER_UNIT:"example.service",_UID:$uid}')
printf '%s\n%s\n' "$unit_event" "$unit_event" | "$watcher" --stdin

[[ $(wc -l <"$MOCK_TMUX_LOG") -eq 1 ]]
[[ $(<"$MOCK_TMUX_LOG") == *"failed-example.service"* ]]
[[ $(<"$MOCK_TMUX_LOG") == *"systemctl\\ --user\\ status\\ example.service"* ]]

: >"$MOCK_TMUX_LOG"
system_unit_event=$(jq -cn \
  '{MESSAGE_ID:"d9b373ed55a64feb8242e02dbe79a49c",UNIT:"system-example.service",_UID:"0"}')
printf '%s\n' "$system_unit_event" | "$watcher" --stdin
[[ $(wc -l <"$MOCK_TMUX_LOG") -eq 1 ]]
[[ $(<"$MOCK_TMUX_LOG") == *"systemctl\\ status\\ system-example.service"* ]]
[[ $(<"$MOCK_TMUX_LOG") != *"systemctl\\ --user"* ]]

: >"$MOCK_TMUX_LOG"
crash_event=$(jq -cn \
  --arg uid "$UID" \
  '{
    MESSAGE_ID:"fc2e22bc6ee647b6b90729ab34a250b1",
    _UID:$uid,
    COREDUMP_COMM:"bad app; touch /tmp/not-run",
    COREDUMP_PID:"4242",
    COREDUMP_EXE:"/tmp/bad app; touch /tmp/not-run",
    COREDUMP_SIGNAL_NAME:"SIGSEGV",
    COREDUMP_USER_UNIT:"app-test.scope"
  }')
printf '%s\n' "$crash_event" | "$watcher" --stdin

[[ $(wc -l <"$MOCK_TMUX_LOG") -eq 1 ]]
[[ $(<"$MOCK_TMUX_LOG") == *"failed-not-run"* ]]
[[ $(<"$MOCK_TMUX_LOG") == *"coredumpctl\\ info\\ 4242"* ]]
[[ ! -e /tmp/not-run ]]

: >"$MOCK_TMUX_LOG"
other_uid_event=$(jq -cn \
  --arg uid "$((UID + 1))" \
  '{MESSAGE_ID:"fc2e22bc6ee647b6b90729ab34a250b1",_UID:$uid,COREDUMP_PID:"77",COREDUMP_EXE:"/bin/false"}')
service_crash_event=$(jq -cn \
  --arg uid "$UID" \
  '{MESSAGE_ID:"fc2e22bc6ee647b6b90729ab34a250b1",_UID:$uid,COREDUMP_PID:"78",COREDUMP_EXE:"/bin/false",COREDUMP_USER_UNIT:"example.service"}')
scope_failure_event=$(jq -cn \
  --arg uid "$UID" \
  '{MESSAGE_ID:"d9b373ed55a64feb8242e02dbe79a49c",USER_UNIT:"app-test.scope",_UID:$uid}')
printf '%s\n%s\n%s\n' "$other_uid_event" "$service_crash_event" "$scope_failure_event" | "$watcher" --stdin
[[ ! -s $MOCK_TMUX_LOG ]]

export MOCK_TMUX_SESSION_RUNNING=0
printf '%s\n' "$unit_event" | "$watcher" --stdin
[[ ! -s $MOCK_TMUX_LOG ]]

printf 'system-failure-watcher tests passed\n'
