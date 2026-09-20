#! bash oh-my-bash.module

# tmux plugin: aliases for tmux, the terminal multiplexer.
# Last reference implementation link:
# https://github.com/ohmyzsh/ohmyzsh/blob/5c4f27b7166360bd23709f24642b247eac30a147/plugins/tmux/tmux.plugin.zsh
#
# Dropped features from upstream:
#   - alias tmux -> _zsh_tmux_plugin_run (tmux wrapper with autostart/autoconnect)
#   - function _zsh_tmux_plugin_run (autostart, autoconnect, autoquit, TERM fixing)
#   - function _zsh_tmux_plugin_preexec (refresh tmux environment variables)
#   - function _build_tmux_alias (zsh completion wiring)
#   - ZSH_TMUX_* configuration variables (AUTOSTART, AUTOCONNECT, AUTOQUIT,
#     AUTONAME_SESSION, AUTOREFRESH, CONFIG, DEFAULT_SESSION_NAME, DETACHED,
#     FIXTERM, FIXTERM_WITHOUT_256COLOR, FIXTERM_WITH_256COLOR, ITERM2, UNICODE)
#   - tmux.extra.conf, tmux.only.conf (TERM fix config files)

if ! _omb_util_command_exists tmux; then
  _omb_util_print '[oh-my-bash] tmux not found, please install it from https://github.com/tmux/tmux' >&2
  return 0
fi

# Aliases
alias ta='tmux attach -t'
alias tad='tmux attach -d -t'
alias tkss='tmux kill-session -t'
alias tksv='tmux kill-server'
alias tl='tmux list-sessions'
alias ts='tmux new-session -s'
alias to='tmux new-session -A -s'
alias tmuxconf='${EDITOR:-vim} ~/.tmux.conf'

# Create or attach to a tmux session named after the current directory with an optional suffix.
function _omb_plugin_tmux_directory_session {
  local dir=${PWD##*/}
  local md5
  if _omb_util_command_exists md5sum; then
    md5=$(printf '%s' "$PWD" | md5sum | cut -d ' ' -f 1)
  elif _omb_util_command_exists md5; then
    md5=$(printf '%s' "$PWD" | md5)
  else
    _omb_util_print '[oh-my-bash] tmux plugin: md5sum or md5 not found, tds requires one of them' >&2
    return 1
  fi
  local suffix="${1:-}"
  local session_name="${dir}-${md5:0:6}"
  [[ -n "$suffix" ]] && session_name="${session_name}-${suffix}"
  tmux new-session -As "$session_name"
}

alias tds='_omb_plugin_tmux_directory_session'

# Create or attach to a tmux session named after the current directory with an optional suffix.
function _omb_plugin_tmux_directory_session_suffix {
  local dir=${PWD##*/}
  local md5
  if _omb_util_command_exists md5sum; then
    md5=$(printf '%s' "$PWD" | md5sum | cut -d ' ' -f 1)
  elif _omb_util_command_exists md5; then
    md5=$(printf '%s' "$PWD" | md5)
  else
    _omb_util_print '[oh-my-bash] tmux plugin: md5sum or md5 not found, tdss requires one of them' >&2
    return 1
  fi
  local suffix="${1:-}"
  local session_name="${dir}-${md5:0:6}"
  [[ -n "$suffix" ]] && session_name="${session_name}-${suffix}"
  tmux new-session -As "$session_name"
}

alias tdss='_omb_plugin_tmux_directory_session_suffix'

# Autocomplete for tmux aliases (ta, tad, tkss)
function _omb_tmux_alias_sessions() {
  local cur=${COMP_WORDS[COMP_CWORD]}

  local -a sessions
  _omb_util_split_lines sessions "$(tmux list-sessions -F '#S' 2>/dev/null)"

  COMPREPLY=()
  local s escaped
  for s in "${sessions[@]}"; do
    [[ $s == "$cur"* ]] || continue
    printf -v escaped '%q' "$s"  # escapes spaces/glob metachars
    COMPREPLY+=("$escaped")
  done
}

complete -F _omb_tmux_alias_sessions ta tad tkss
