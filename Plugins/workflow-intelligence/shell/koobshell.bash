# Koob Shell Workflow Intelligence — bash integration
# Sourced when KOOBSHELL_INTEGRATION=1

if [[ -n "${KOOBSHELL_INTEGRATION_LOADED:-}" ]]; then
  return 0
fi
export KOOBSHELL_INTEGRATION_LOADED=1

_koobshell_osc() {
  printf '\033]133;%s\007' "$1"
}

_koobshell_preexec() {
  [[ -n "${KOOBSHELL_INTEGRATION:-}" ]] || return 0
  [[ "${KOOBSHELL_CAPTURE_ENABLED:-1}" == "1" ]] || return 0

  _koobshell_osc "A"
  _koobshell_osc "B"

  if command -v koobshell >/dev/null 2>&1; then
    koobshell record-start \
      --plugin "${KOOBSHELL_PLUGIN_ID:-workflow-intelligence}" \
      --session "${KOOBSHELL_SESSION_ID:-unknown}" \
      --cmd "$1" \
      --cwd "$PWD" 2>/dev/null || true
  fi
}

_koobshell_precmd() {
  local exit_code=$?
  [[ -n "${KOOBSHELL_INTEGRATION:-}" ]] || return 0
  [[ "${KOOBSHELL_CAPTURE_ENABLED:-1}" == "1" ]] || return 0

  _koobshell_osc "C"
  _koobshell_osc "D;${exit_code}"

  if command -v koobshell >/dev/null 2>&1; then
    koobshell record-end --exit "$exit_code" 2>/dev/null || true
  fi
}

if [[ -n "${BASH_VERSION:-}" ]]; then
  if declare -p __koobshell_last_command >/dev/null 2>&1; then
    :
  else
    __koobshell_last_command=""
  fi

  _koobshell_debug_trap() {
    local cmd="${BASH_COMMAND}"
    if [[ "$cmd" != "$__koobshell_last_command" && "$cmd" != _koobshell_* ]]; then
      __koobshell_last_command="$cmd"
      _koobshell_preexec "$cmd"
    fi
  }

  trap '_koobshell_debug_trap' DEBUG
  PROMPT_COMMAND="_koobshell_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
