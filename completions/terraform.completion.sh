#! bash oh-my-bash.module
# Bash Terraform completion

_terraform()
{
   local cmds cur colonprefixes
   cmds="apply destroy fmt get graph import init \
      output plan push refresh remote show taint \
      untaint validate version state"

   COMPREPLY=()
   cur=${COMP_WORDS[COMP_CWORD]}
   # Work-around bash_completion issue where bash interprets a colon
   # as a separator.
   # Work-around borrowed from the darcs work-around for the same
   # issue.
   colonprefixes=${cur%"${cur##*:}"}
   COMPREPLY=( $(compgen -W '$cmds'  -- $cur))
   local i=${#COMPREPLY[*]}
   while [ $((--i)) -ge 0 ]; do
      COMPREPLY[$i]=${COMPREPLY[$i]#"$colonprefixes"}
   done

        return 0
} &&
complete -F _terraform terraform

function _omb_terraform_alias_complete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=""
  if ((COMP_CWORD > 0)); then
    prev=${COMP_WORDS[COMP_CWORD - 1]}
  fi
  local cmd=${COMP_WORDS[0]}

  local expansion
  case $cmd in
    t)      expansion="terraform" ;;
    tapply) expansion="terraform apply" ;;
    tfmt)   expansion="terraform fmt" ;;
    tinit)  expansion="terraform init" ;;
    tplan)  expansion="terraform plan" ;;
    *)      return 1 ;;
  esac

  local -a expansion_words=($expansion)
  local -a new_words=("${expansion_words[@]}" "${COMP_WORDS[@]:1}")
  local new_cword=$((COMP_CWORD + ${#expansion_words[@]} - 1))

  local subcommand=""
  case $cmd in
    t)
      if ((new_cword > 1)); then
        subcommand="${new_words[1]}"
      fi
      ;;
    tapply) subcommand="apply" ;;
    tfmt)   subcommand="fmt" ;;
    tinit)  subcommand="init" ;;
    tplan)  subcommand="plan" ;;
  esac

  if [[ $cur == -* && $subcommand ]]; then
    local flags=""
    case $subcommand in
      apply)
        flags="-auto-approve -backup -compact-warnings -input -lock -lock-timeout -no-color -parallelism -state -state-out -target -var -var-file"
        ;;
      plan)
        flags="-compact-warnings -destroy -detailed-exitcode -input -lock -lock-timeout -no-color -out -parallelism -state -target -var -var-file"
        ;;
      init)
        flags="-backend -backend-config -force-copy -get -get-plugins -input -lock -lock-timeout -no-color -plugin-dir -reconfigure -upgrade"
        ;;
      fmt)
        flags="-list -write -diff -check -recursive"
        ;;
    esac

    if [[ $flags ]]; then
      COMPREPLY=( $(compgen -W "$flags" -- "$cur") )
      return 0
    fi
  fi

  local leading_whitespace=""
  local rest_of_line=""
  if [[ $COMP_LINE =~ ^([[:space:]]*)([^[:space:]]+)(.*)$ ]]; then
    leading_whitespace="${BASH_REMATCH[1]}"
    rest_of_line="${BASH_REMATCH[3]}"
  fi

  local new_line="${leading_whitespace}${expansion}${rest_of_line}"
  local new_point=$((COMP_POINT + ${#expansion} - ${#cmd}))

  local completion_info
  completion_info=$(complete -p terraform 2>/dev/null)

  if [[ $completion_info == *"-C "* ]]; then
    local real_cmd=""
    if [[ $completion_info =~ -C[[:space:]]+(\'[^\']+\'|\"[^\"]+\"|[^[:space:]]+) ]]; then
      real_cmd="${BASH_REMATCH[1]}"
      real_cmd="${real_cmd#\'}"
      real_cmd="${real_cmd%\'}"
      real_cmd="${real_cmd#\"}"
      real_cmd="${real_cmd%\"}"
    fi

    if [[ $real_cmd ]]; then
      local new_cur="${new_words[new_cword]}"
      local new_prev=""
      if ((new_cword > 0)); then
        new_prev="${new_words[new_cword - 1]}"
      fi

      local -a results
      _omb_util_split_lines results "$(COMP_LINE="$new_line" COMP_POINT="$new_point" "$real_cmd" "terraform" "$new_cur" "$new_prev" 2>/dev/null)"

      COMPREPLY=()
      local r escaped
      for r in "${results[@]}"; do
        printf -v escaped '%q' "$r"
        COMPREPLY+=("$escaped")
      done
      return 0
    fi
  fi

  if [[ $completion_info == *"-F "* ]]; then
    local real_func=""
    if [[ $completion_info =~ -F[[:space:]]+(\'[^\']+\'|\"[^\"]+\"|[^[:space:]]+) ]]; then
      real_func="${BASH_REMATCH[1]}"
      real_func="${real_func#\'}"
      real_func="${real_func%\'}"
      real_func="${real_func#\"}"
      real_func="${real_func%\"}"
    fi

    if [[ $real_func ]]; then
      local -a COMP_WORDS_saved=("${COMP_WORDS[@]}")
      local COMP_CWORD_saved=$COMP_CWORD
      local COMP_LINE_saved="$COMP_LINE"
      local COMP_POINT_saved=$COMP_POINT

      COMP_WORDS=("${new_words[@]}")
      COMP_CWORD=$new_cword
      COMP_LINE="$new_line"
      COMP_POINT=$new_point

      "$real_func"

      COMP_WORDS=("${COMP_WORDS_saved[@]}")
      COMP_CWORD=$COMP_CWORD_saved
      COMP_LINE="$COMP_LINE_saved"
      COMP_POINT=$COMP_POINT_saved
      return 0
    fi
  fi

  if _omb_util_function_exists _terraform; then
    local -a COMP_WORDS_saved=("${COMP_WORDS[@]}")
    local COMP_CWORD_saved=$COMP_CWORD
    local COMP_LINE_saved="$COMP_LINE"
    local COMP_POINT_saved=$COMP_POINT

    COMP_WORDS=("${new_words[@]}")
    COMP_CWORD=$new_cword
    COMP_LINE="$new_line"
    COMP_POINT=$new_point

    _terraform

    COMP_WORDS=("${COMP_WORDS_saved[@]}")
    COMP_CWORD=$COMP_CWORD_saved
    COMP_LINE="$COMP_LINE_saved"
    COMP_POINT=$COMP_POINT_saved
    return 0
  fi
}

complete -F _omb_terraform_alias_complete t tapply tfmt tinit tplan
