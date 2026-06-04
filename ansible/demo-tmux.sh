#!/bin/bash
# Start a tmux session with SSH connections to all three FreeIPA demo VMs.
# Run from anywhere — paths are resolved relative to this script's location.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="$SCRIPT_DIR/keys/demokey"
SSH="ssh -i $KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SESSION="freeipa-demo"

if ! [ -f "$KEY" ]; then
  echo "SSH key not found: $KEY"
  exit 1
fi

# Reattach if session already exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

# Window 1 — server (created with the session)
tmux new-session  -d -s "$SESSION" -n "ipaserver"
tmux send-keys    -t "$SESSION:ipaserver"  "$SSH demo@192.168.122.10" Enter

# Window 2 — client 1
tmux new-window   -t "$SESSION" -n "ipaclient1"
tmux send-keys    -t "$SESSION:ipaclient1" "$SSH demo@192.168.122.11" Enter

# Window 3 — client 2
tmux new-window   -t "$SESSION" -n "ipaclient2"
tmux send-keys    -t "$SESSION:ipaclient2" "$SSH demo@192.168.122.12" Enter

# Start on the server window
tmux select-window -t "$SESSION:ipaserver"

tmux attach-session -t "$SESSION"
