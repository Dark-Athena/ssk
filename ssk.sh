#!/usr/bin/env bash
# ssk.sh
# Generates an SSH key pair (if needed) and installs it on a remote host
# using ssh-copy-id.
#
# Usage:
#   ./ssk.sh
#   ./ssk.sh user@host:port
#   ./ssk.sh user@host
#   ./ssk.sh host:port
#   ./ssk.sh host
#
# Default user: root
# Default port: 22

set -euo pipefail

TARGET="${1:-}"

USER_NAME=""
HOST_ADDR=""
PORT="22"

parse_target() {
  local t="$1"

  [[ -z "$t" ]] && return 0

  # user@host:port
  if [[ "$t" =~ ^([^@]+)@([^:]+):([0-9]+)$ ]]; then
    USER_NAME="${BASH_REMATCH[1]}"
    HOST_ADDR="${BASH_REMATCH[2]}"
    PORT="${BASH_REMATCH[3]}"
    return 0
  fi

  # user@host
  if [[ "$t" =~ ^([^@]+)@([^:]+)$ ]]; then
    USER_NAME="${BASH_REMATCH[1]}"
    HOST_ADDR="${BASH_REMATCH[2]}"
    return 0
  fi

  # host:port
  if [[ "$t" =~ ^([^:]+):([0-9]+)$ ]]; then
    HOST_ADDR="${BASH_REMATCH[1]}"
    PORT="${BASH_REMATCH[2]}"
    return 0
  fi

  # host only
  if [[ "$t" =~ ^([^:@]+)$ ]]; then
    HOST_ADDR="${BASH_REMATCH[1]}"
    return 0
  fi

  echo "Invalid target format: $t" >&2
  echo "Use: user@host:port | user@host | host:port | host" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd ssh
require_cmd ssh-keygen
require_cmd ssh-copy-id

parse_target "$TARGET"

# Default user = root
if [[ -z "$USER_NAME" ]]; then
  USER_NAME="root"
fi

if [[ -z "$HOST_ADDR" ]]; then
  read -rp "Remote host (IP or DNS): " HOST_ADDR
fi

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"
PUB_PATH="$KEY_PATH.pub"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$KEY_PATH" || ! -f "$PUB_PATH" ]]; then
  echo "No SSH key found. Generating: $KEY_PATH"
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N ""
else
  echo "SSH key already exists: $KEY_PATH"
fi

echo
echo "Target: ${USER_NAME}@${HOST_ADDR}:${PORT}"
echo "Installing public key to remote host..."
echo "When prompted, enter remote password once."
echo

ssh-copy-id -i "$PUB_PATH" -p "$PORT" "${USER_NAME}@${HOST_ADDR}"

echo
echo "Done. Test passwordless login:"
echo "  ssh -p ${PORT} ${USER_NAME}@${HOST_ADDR}"
