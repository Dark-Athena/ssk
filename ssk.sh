#!/usr/bin/env bash
# ssk.sh
# SSH key installer with host management.
#
# Usage:
#   ./ssk.sh                              - interactive host selection
#   ./ssk.sh user@host:port               - connect to host
#   ./ssk.sh --id N                       - connect to Nth saved host
#   ./ssk.sh list                         - list saved hosts
#   ./ssk.sh list rename <old> <new>      - rename a host alias
#   ./ssk.sh --debug ...                  - verbose output
#
# Default user: root
# Default port: 22

set -euo pipefail

CONFIG_FILE="$HOME/.ssh/config"
_DEBUG=false

log() { $_DEBUG && echo "$@" || true; }
log_err() { echo "$@" >&2; }

# ---- Subcommands ----

do_list() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "No hosts saved yet."
    return 0
  fi

  local idx=0 host_name="" host_addr="" user_name="" port=""

  flush() {
    [[ -z "$host_name" ]] && return
    [[ -z "$host_addr" ]] && host_addr="$host_name"
    [[ -z "$user_name" ]] && user_name="root"
    [[ -z "$port" ]] && port="22"
    echo "${idx}  ${user_name}@${host_addr}:${port}  [${host_name}]"
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
    case "$key" in
      Host)     flush; idx=$((idx+1)); host_name="$value"; host_addr=""; user_name=""; port="" ;;
      HostName) host_addr="$value" ;;
      User)     user_name="$value" ;;
      Port)     port="$value" ;;
    esac
  done < "$CONFIG_FILE"

  flush
}

do_get_alias_by_id() {
  local target_id="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "No hosts saved yet."
    return 1
  fi

  local idx=0 host_name=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.*) ]]; then
      if [[ -n "$host_name" ]]; then
        idx=$((idx+1))
        if [[ "$idx" == "$target_id" ]]; then
          echo "$host_name"
          return 0
        fi
      fi
      host_name="${BASH_REMATCH[1]}"
    fi
  done < "$CONFIG_FILE"
  if [[ -n "$host_name" ]]; then
    idx=$((idx+1))
    if [[ "$idx" == "$target_id" ]]; then
      echo "$host_name"
      return 0
    fi
  fi
  log_err "Host not found for id: $target_id"
  return 1
}

do_rename() {
  local old_alias="$1"
  local new_alias="$2"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "No hosts saved yet."
    return 0
  fi
  if [[ -z "$old_alias" || -z "$new_alias" ]]; then
    log_err "Usage: ssk list rename <old-alias> <new-alias>"
    exit 1
  fi

  local old_escaped
  old_escaped=$(printf '%s' "$old_alias" | sed 's/[.[\*^$()+?{|\\]/\\&/g')

  if ! grep -q "^Host ${old_alias}\$" "$CONFIG_FILE"; then
    log_err "Host alias not found: $old_alias"
    exit 1
  fi

  sed -i "s/^Host ${old_escaped}\$/Host ${new_alias}/" "$CONFIG_FILE"
  echo "Renamed: $old_alias -> $new_alias"
}

do_connect() {
  do_list
  echo ""
  echo "Type /help for available commands, /q to quit."
  echo ""

  while true; do
    read -rp "ssk> " _input
    [[ -z "$_input" ]] && continue

    # --- / prefix commands ---
    if [[ "$_input" == /* ]]; then
      _cmd="${_input%% *}"
      _args="${_input#* }"
      [[ "$_args" == "$_cmd" ]] && _args=""

      case "$_cmd" in
        /q|/quit|/exit) return 0 ;;
        /list|/ls) do_list; echo "" ;;
        /del|/rm)
          if [[ -z "$_args" ]]; then echo "Usage: /del <number>"; echo ""; continue; fi
          do_del_by_id "$_args" && { do_list; echo ""; }
          ;;
        /rename)
          _rn_id="${_args%% *}"
          _rn_new="${_args#* }"
          if [[ -z "$_rn_id" || -z "$_rn_new" || "$_rn_new" == "$_rn_id" ]]; then
            echo "Usage: /rename <number> <new-alias>"; echo ""; continue
          fi
          do_rename_by_id "$_rn_id" "$_rn_new" && { do_list; echo ""; }
          ;;
        /add)
          if [[ -z "$_args" ]]; then echo "Usage: /add user@host:port"; echo ""; continue; fi
          do_add "$_args" && { do_list; echo ""; }
          ;;
        /filter|/fi)
          do_filter "$_args"; echo ""
          ;;
        /clear) clear ;;
        /help|/h|/)
          echo ""
          echo "Available commands:"
          echo "  /ls  /list           Show host list"
          echo "  /del <number>        Delete host by list number"
          echo "  /rename <n> <name>   Rename host alias by list number"
          echo "  /add <user@host>     Save a new host to config"
          echo "  /filter <keyword>    Filter list by keyword"
          echo "  /clear               Clear screen"
          echo "  /help  /h            Show this help"
          echo "  /q  /quit  /exit     Quit interactive mode"
          echo ""
          echo "  <number>             Connect to host by list number"
          echo "  <string>             Connect by user@host:port or host alias"
          echo ""
          ;;
        *)
          echo "Unknown command: $_cmd"
          echo "Type /help for available commands."
          echo ""
          ;;
      esac
      continue
    fi

    # --- Default: connect ---
    if [[ "$_input" =~ ^[0-9]+$ ]]; then
      _target=$(do_get_alias_by_id "$_input") || { echo "Invalid selection: $_input"; echo ""; continue; }
      echo "Connecting to $_target..."
      "$0" "$_target" || true
    else
      echo "Connecting to $_input..."
      "$0" "$_input" || true
    fi
    echo ""
  done
}

do_del_by_id() {
  local target_id="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "No hosts saved yet."
    return 1
  fi

  local idx=0 host_name="" target_alias=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.*) ]]; then
      if [[ -n "$host_name" ]]; then
        idx=$((idx+1))
        if [[ "$idx" == "$target_id" ]]; then
          target_alias="$host_name"
          break
        fi
      fi
      host_name="${BASH_REMATCH[1]}"
    fi
  done < "$CONFIG_FILE"
  if [[ -n "$host_name" && -z "$target_alias" ]]; then
    idx=$((idx+1))
    if [[ "$idx" == "$target_id" ]]; then
      target_alias="$host_name"
    fi
  fi

  if [[ -z "$target_alias" ]]; then
    log_err "Host not found for id: $target_id"
    return 1
  fi

  local escaped
  escaped=$(printf '%s' "$target_alias" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
  # Delete the Host line and its indented sub-lines
  sed -i "/^Host ${escaped}\$/,/^[^[:space:]]/{ /^Host ${escaped}\$/d; /^[[:space:]]/d; }" "$CONFIG_FILE"
  # Remove leading blank lines left behind
  sed -i '/./,$!d' "$CONFIG_FILE"
  echo "Deleted: $target_alias"
  return 0
}

do_rename_by_id() {
  local target_id="$1"
  local new_alias="$2"
  local old_alias

  old_alias=$(do_get_alias_by_id "$target_id") || return 1

  local escaped
  escaped=$(printf '%s' "$old_alias" | sed 's/[.[\*^$()+?{|\\]/\\&/g')

  if ! grep -q "^Host ${old_alias}\$" "$CONFIG_FILE"; then
    log_err "Host alias not found: $old_alias"
    return 1
  fi

  sed -i "s/^Host ${escaped}\$/Host ${new_alias}/" "$CONFIG_FILE"
  echo "Renamed: $old_alias -> $new_alias"
  return 0
}

do_add() {
  local target="$1"
  if [[ -z "$target" ]]; then
    log_err "Usage: /add user@host:port"
    return 1
  fi

  local user_name="root" host_addr="$target" port="22"

  if [[ "$target" =~ ^([^@]+)@([^:]+):([0-9]+)$ ]]; then
    user_name="${BASH_REMATCH[1]}"
    host_addr="${BASH_REMATCH[2]}"
    port="${BASH_REMATCH[3]}"
  elif [[ "$target" =~ ^([^@]+)@([^:]+)$ ]]; then
    user_name="${BASH_REMATCH[1]}"
    host_addr="${BASH_REMATCH[2]}"
  elif [[ "$target" =~ ^([^:]+):([0-9]+)$ ]]; then
    host_addr="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
  fi

  local config_path="$HOME/.ssh/config"
  local host_alias="$target"

  # Dedup check
  if [[ -f "$config_path" ]]; then
    local _current_block="" _dup=false
    while IFS= read -r _line || [[ -n "$_line" ]]; do
      if [[ "$_line" =~ ^[[:space:]]*Host[[:space:]] ]]; then
        if [[ -n "$_current_block" ]]; then
          if echo "$_current_block" | grep -q "HostName[[:space:]]*${host_addr}"; then
            if echo "$_current_block" | grep -q "User[[:space:]]*${user_name}"; then
              if [[ "$port" == "22" ]]; then
                echo "$_current_block" | grep -q "Port[[:space:]]*" || _dup=true
                echo "$_current_block" | grep -q "Port[[:space:]]*22" && _dup=true
              else
                echo "$_current_block" | grep -q "Port[[:space:]]*${port}" && _dup=true
              fi
            fi
          fi
          if $_dup; then echo "Already exists: $host_alias"; return 0; fi
        fi
        _current_block="$_line"
      elif [[ -n "$_line" ]]; then
        _current_block="${_current_block}"$'\n'"${_line}"
      fi
    done < "$config_path"
    if [[ -n "$_current_block" ]]; then
      if echo "$_current_block" | grep -q "HostName[[:space:]]*${host_addr}"; then
        if echo "$_current_block" | grep -q "User[[:space:]]*${user_name}"; then
          if [[ "$port" == "22" ]]; then
            echo "$_current_block" | grep -q "Port[[:space:]]*" || _dup=true
            echo "$_current_block" | grep -q "Port[[:space:]]*22" && _dup=true
          else
            echo "$_current_block" | grep -q "Port[[:space:]]*${port}" && _dup=true
          fi
        fi
      fi
      if $_dup; then echo "Already exists: $host_alias"; return 0; fi
    fi
  fi

  local date_str
  date_str=$(date +%Y-%m-%d)
  mkdir -p "$HOME/.ssh"
  {
    echo ""
    echo "# Added by ssk - $date_str"
    echo "Host $host_alias"
    echo "    HostName $host_addr"
    echo "    User $user_name"
    echo "    Port $port"
    echo ""
  } >> "$config_path"
  echo "Added: $host_alias"
  return 0
}

do_filter() {
  local keyword="$1"
  if [[ -z "$keyword" ]]; then
    do_list
    return 0
  fi
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "No hosts saved yet."
    return 0
  fi

  local idx=0 host_name="" host_addr="" user_name="" port=""

  flush_filtered() {
    [[ -z "$host_name" ]] && return
    [[ -z "$host_addr" ]] && host_addr="$host_name"
    [[ -z "$user_name" ]] && user_name="root"
    [[ -z "$port" ]] && port="22"
    local entry="${user_name}@${host_addr}:${port}  [${host_name}]"
    if echo "$entry" | grep -qi "$keyword"; then
      echo "${idx}  ${entry}"
    fi
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
    case "$key" in
      Host)     flush_filtered; idx=$((idx+1)); host_name="$value"; host_addr=""; user_name=""; port="" ;;
      HostName) host_addr="$value" ;;
      User)     user_name="$value" ;;
      Port)     port="$value" ;;
    esac
  done < "$CONFIG_FILE"

  flush_filtered
}

# ---- Dispatch ----

# Extract --debug before case (it can appear anywhere in args)
for _arg in "$@"; do
  if [[ "$_arg" == "--debug" ]]; then
    _DEBUG=true
    break
  fi
done
# Remove --debug from args
if $_DEBUG; then
  set -- "${@/--debug/}"
fi

case "${1:-}" in
  list)
    if [[ "${2:-}" == "rename" ]]; then
      do_rename "$3" "$4"
    else
      do_list
    fi
    exit 0
    ;;
  --id)
    _alias=$(do_get_alias_by_id "${2:-}")
    set -- "$_alias"
    ;;
esac

# ---- Interactive mode when no args ----
if [[ $# -eq 0 ]]; then
  do_connect
  exit 0
fi

# ---- Connect (default) ----

TARGET="${1:-}"

USER_NAME=""
HOST_ADDR=""
PORT="22"
_USER_EXPLICIT=false
_PORT_EXPLICIT=false

parse_target() {
  local t="$1"

  [[ -z "$t" ]] && return 0

  # user@host:port
  if [[ "$t" =~ ^([^@]+)@([^:]+):([0-9]+)$ ]]; then
    USER_NAME="${BASH_REMATCH[1]}"
    HOST_ADDR="${BASH_REMATCH[2]}"
    PORT="${BASH_REMATCH[3]}"
    _USER_EXPLICIT=true
    _PORT_EXPLICIT=true
    return 0
  fi

  # user@host
  if [[ "$t" =~ ^([^@]+)@([^:]+)$ ]]; then
    USER_NAME="${BASH_REMATCH[1]}"
    HOST_ADDR="${BASH_REMATCH[2]}"
    _USER_EXPLICIT=true
    return 0
  fi

  # host:port
  if [[ "$t" =~ ^([^:]+):([0-9]+)$ ]]; then
    HOST_ADDR="${BASH_REMATCH[1]}"
    PORT="${BASH_REMATCH[2]}"
    _PORT_EXPLICIT=true
    return 0
  fi

  # host only
  if [[ "$t" =~ ^([^:@]+)$ ]]; then
    HOST_ADDR="${BASH_REMATCH[1]}"
    return 0
  fi

  log_err "Invalid target format: $t"
  log_err "Use: user@host:port | user@host | host:port | host"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_err "Missing required command: $1"
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

# Resolve SSH config alias: if HOST_ADDR matches a Host alias, use its HostName/User/Port
_resolved_from_alias=false
if [[ -f "$CONFIG_FILE" ]]; then
  _in_any_block=false
  _is_target=false
  _block_hostname=""
  _block_user=""
  _block_port=""
  _resolved_hostname=""
  _resolved_user=""
  _resolved_port=""
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    [[ -z "$_line" || "$_line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$_line" =~ ^[[:space:]]*Host[[:space:]]+(.*) ]]; then
      if $_is_target && [[ -n "$_block_hostname" ]]; then
        _resolved_hostname="$_block_hostname"
        _resolved_user="$_block_user"
        _resolved_port="$_block_port"
        break
      fi
      _aliases="${BASH_REMATCH[1]}"
      _is_target=false
      for _a in $_aliases; do
        if [[ "$_a" == "$HOST_ADDR" ]]; then
          _is_target=true
          _block_hostname=""
          _block_user=""
          _block_port=""
          break
        fi
      done
      _in_any_block=true
    elif $_in_any_block && [[ "$_line" =~ ^[[:space:]]+[^[:space:]] ]]; then
      if $_is_target; then
        if [[ "$_line" =~ ^[[:space:]]*HostName[[:space:]]+(.*) ]]; then
          _block_hostname="${BASH_REMATCH[1]}"
        elif [[ "$_line" =~ ^[[:space:]]*User[[:space:]]+(.*) ]]; then
          _block_user="${BASH_REMATCH[1]}"
        elif [[ "$_line" =~ ^[[:space:]]*Port[[:space:]]+(.*) ]]; then
          _block_port="${BASH_REMATCH[1]}"
        fi
      fi
    else
      _in_any_block=false
    fi
  done < "$CONFIG_FILE"
  if $_is_target && [[ -n "$_block_hostname" ]]; then
    _resolved_hostname="$_block_hostname"
    _resolved_user="$_block_user"
    _resolved_port="$_block_port"
  fi
  if [[ -n "$_resolved_hostname" ]]; then
    HOST_ADDR="$_resolved_hostname"
    _resolved_from_alias=true
    if ! $_USER_EXPLICIT && [[ -n "$_resolved_user" ]]; then
      USER_NAME="$_resolved_user"
    fi
    if ! $_PORT_EXPLICIT && [[ -n "$_resolved_port" ]]; then
      PORT="$_resolved_port"
    fi
  fi
fi

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"
PUB_PATH="$KEY_PATH.pub"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$KEY_PATH" || ! -f "$PUB_PATH" ]]; then
  log "No SSH key found. Generating: $KEY_PATH"
  ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" 2>/dev/null
else
  log "SSH key already exists: $KEY_PATH"
fi

log "Target: ${USER_NAME}@${HOST_ADDR}:${PORT}"

# Detect SSH service and host key requirements from banner (occurs before authentication)
SSH_OPTS=()
_ssh_banner=$(ssh -v -o BatchMode=yes -o ConnectTimeout=5 -p "$PORT" "${USER_NAME}@${HOST_ADDR}" </dev/null 2>&1 || true)

if echo "$_ssh_banner" | grep -q "no matching host key type"; then
  SSH_OPTS=(-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedKeyTypes=+ssh-rsa)
  _ssh_banner=$(ssh -v "${SSH_OPTS[@]}" -o BatchMode=yes -o ConnectTimeout=5 -p "$PORT" "${USER_NAME}@${HOST_ADDR}" 2>&1 || true)
fi

if echo "$_ssh_banner" | grep -qi "dropbear"; then
  _pub_key=$(cat "$PUB_PATH")
  ssh "${SSH_OPTS[@]}" -p "$PORT" "${USER_NAME}@${HOST_ADDR}" \
    "AUTH_DIR=\$([ -d /etc/dropbear ] && echo /etc/dropbear || echo ~/.ssh) && mkdir -p \"\$AUTH_DIR\" && chmod 700 \"\$AUTH_DIR\" && (grep -qxF '$_pub_key' \"\$AUTH_DIR/authorized_keys\" 2>/dev/null || echo '$_pub_key' >> \"\$AUTH_DIR/authorized_keys\") && chmod 600 \"\$AUTH_DIR/authorized_keys\"" 2>/dev/null
else
  ssh-copy-id "${SSH_OPTS[@]}" -i "$PUB_PATH" -p "$PORT" "${USER_NAME}@${HOST_ADDR}" 2>/dev/null
fi

# Save to SSH config
CONFIG_PATH="$SSH_DIR/config"
_DATE=$(date +%Y-%m-%d)
if [[ "$PORT" == "22" ]]; then
  _host_alias="${USER_NAME}@${HOST_ADDR}"
else
  _host_alias="${USER_NAME}@${HOST_ADDR}:${PORT}"
fi

_duplicate=false
if $_resolved_from_alias; then
  _duplicate=true
  log "Using existing SSH config alias for $HOST_ADDR"
elif [[ -f "$CONFIG_PATH" ]]; then
  _current_block=""
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    if [[ "$_line" =~ ^[[:space:]]*Host[[:space:]] ]]; then
      # New Host block: process previous block first
      if [[ -n "$_current_block" ]] && echo "$_current_block" | grep -q "HostName[[:space:]]*$HOST_ADDR"; then
        _has_user=false
        _has_port=false
        echo "$_current_block" | grep -q "User[[:space:]]*${USER_NAME}" && _has_user=true
        if [[ "$PORT" == "22" ]]; then
          echo "$_current_block" | grep -q "Port[[:space:]]*" || _has_port=true
          echo "$_current_block" | grep -q "Port[[:space:]]*22" && _has_port=true
        else
          echo "$_current_block" | grep -q "Port[[:space:]]*${PORT}" && _has_port=true
        fi
        if $_has_user && $_has_port; then
          _duplicate=true
          break
        fi
      fi
      _current_block="$_line"
    elif [[ -n "$_line" ]]; then
      _current_block="${_current_block}"$'\n'"${_line}"
    fi
  done < "$CONFIG_PATH"
  if [[ -n "$_current_block" ]] && echo "$_current_block" | grep -q "HostName[[:space:]]*$HOST_ADDR"; then
    _has_user=false
    _has_port=false
    echo "$_current_block" | grep -q "User[[:space:]]*${USER_NAME}" && _has_user=true
    if [[ "$PORT" == "22" ]]; then
      echo "$_current_block" | grep -q "Port[[:space:]]*" || _has_port=true
      echo "$_current_block" | grep -q "Port[[:space:]]*22" && _has_port=true
    else
      echo "$_current_block" | grep -q "Port[[:space:]]*${PORT}" && _has_port=true
    fi
    if $_has_user && $_has_port; then
      _duplicate=true
    fi
  fi
fi

if $_duplicate; then
  if ! $_resolved_from_alias; then
    log "SSH config already has entry for $_host_alias"
  fi
else
  {
    echo ""
    echo "# Added by ssk - $_DATE"
    echo "Host $_host_alias"
    echo "    HostName $HOST_ADDR"
    echo "    User $USER_NAME"
    echo "    Port $PORT"
    echo ""
  } >> "$CONFIG_PATH"
  log "Saved to SSH config: Host $_host_alias"
fi

ssh "${SSH_OPTS[@]}" -p "${PORT}" "${USER_NAME}@${HOST_ADDR}"
