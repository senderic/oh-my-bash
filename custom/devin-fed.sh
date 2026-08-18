# devin-fed autocomplete script for Oh My Bash
# Compatible with both bash and zsh

if [ -n "$ZSH_VERSION" ]; then
    if ! type complete >/dev/null 2>&1; then
        autoload -U +X compinit 2>/dev/null && compinit 2>/dev/null
        autoload -U +X bashcompinit 2>/dev/null && bashcompinit 2>/dev/null
    fi
fi

_devin_fed_completion() {
    local cur prev words cword
    if declare -f _get_comp_words_by_ref >/dev/null 2>&1; then
        _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword="$COMP_CWORD"
    fi

    local global_opts="--prompt-file --config --permission-mode --sandbox --model -p --print --export -c --continue -r --resume --respect-workspace-trust --agent-config -h --help -V --version"
    local subcommands="auth mcp models rules skills plugins cloud list ls update version migrate sandbox setup uninstall acp shell help"

    # Fetch/cache models
    local cache_dir="$HOME/.cache/devin"
    local cache_file="$cache_dir/models.cache"
    local models=""
    
    if [ ! -f "$cache_file" ]; then
        mkdir -p "$cache_dir" 2>/dev/null
        models=$(devin-fed models list 2>/dev/null | python3 -c '
import sys, re
lines = sys.stdin.read().splitlines()
models = []
for line in lines:
    if not line.strip() or "Available models" in line or "Pass a family" in line:
        continue
    if not line.startswith(" "):
        m = re.search(r"\(([^)]+(?:\([^)]*\)[^)]*)*)\)\s*$", line)
        if m:
            models.append(m.group(1))
    elif "aliases:" in line:
        parts = line.split("aliases:")
        if len(parts) > 1:
            aliases = [a.strip() for a in parts[1].replace(",", " ").split() if a.strip()]
            models.extend(aliases)
    else:
        parts = line.strip().split()
        if parts and parts[0] != "aliases:":
            models.append(parts[0])
print(" ".join(models))
' 2>/dev/null)
        echo "$models" > "$cache_file" 2>/dev/null
    else
        models=$(cat "$cache_file" 2>/dev/null)
        local mtime=$(date -r "$cache_file" +%s 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        local now=$(date +%s)
        if [ $((now - mtime)) -gt 86400 ]; then
            (
                local tmp_models=$(devin-fed models list 2>/dev/null | python3 -c '
import sys, re
lines = sys.stdin.read().splitlines()
models = []
for line in lines:
    if not line.strip() or "Available models" in line or "Pass a family" in line:
        continue
    if not line.startswith(" "):
        m = re.search(r"\(([^)]+(?:\([^)]*\)[^)]*)*)\)\s*$", line)
        if m:
            models.append(m.group(1))
    elif "aliases:" in line:
        parts = line.split("aliases:")
        if len(parts) > 1:
            aliases = [a.strip() for a in parts[1].replace(",", " ").split() if a.strip()]
            models.extend(aliases)
    else:
        parts = line.strip().split()
        if parts and parts[0] != "aliases:":
            models.append(parts[0])
print(" ".join(models))
' 2>/dev/null)
                if [ -n "$tmp_models" ]; then
                    echo "$tmp_models" > "$cache_file" 2>/dev/null
                fi
            ) &>/dev/null & disown 2>/dev/null
        fi
    fi

    if [ -z "$models" ]; then
        models="claude-sonnet-4 claude-opus-4.6 gemini-3-5-flash-medium gpt-5-4-medium opus gpt gemini"
    fi

    # Determine command and subcommands
    local cmd=""
    local subcmd=""
    local i=1
    while [ $i -lt $cword ]; do
        local word="${words[i]}"
        case "$word" in
            auth|mcp|models|rules|skills|plugins|cloud|list|ls|update|version|migrate|sandbox|setup|uninstall|acp|shell|help)
                cmd="$word"
                if [ "$cmd" = "cloud" ] && [ $((i+1)) -lt $cword ]; then
                    local next_word="${words[i+1]}"
                    if [ "$next_word" = "drs" ]; then
                        subcmd="drs"
                    fi
                fi
                break
                ;;
        esac
        i=$((i+1))
    done

    # Handle completion based on the previous word
    case "$prev" in
        --model)
            COMPREPLY=( $(compgen -W "$models" -- "$cur") )
            return 0
            ;;
        -r|--resume)
            local sessions=$(devin-fed list --format json 2>/dev/null | jq -r '.[].id' 2>/dev/null)
            COMPREPLY=( $(compgen -W "$sessions" -- "$cur") )
            return 0
            ;;
        --permission-mode)
            COMPREPLY=( $(compgen -W "auto accept-edits smart dangerous" -- "$cur") )
            return 0
            ;;
        --respect-workspace-trust)
            COMPREPLY=( $(compgen -W "true false" -- "$cur") )
            return 0
            ;;
        --format)
            COMPREPLY=( $(compgen -W "interactive json csv" -- "$cur") )
            return 0
            ;;
        --prompt-file|--config|--export|--agent-config)
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
    esac

    # Handle subcommand completion
    case "$cmd" in
        auth)
            COMPREPLY=( $(compgen -W "login logout status help" -- "$cur") )
            return 0
            ;;
        mcp)
            COMPREPLY=( $(compgen -W "add list get remove login logout enable disable help" -- "$cur") )
            return 0
            ;;
        models)
            COMPREPLY=( $(compgen -W "list help" -- "$cur") )
            return 0
            ;;
        rules|skills)
            COMPREPLY=( $(compgen -W "list show paths help" -- "$cur") )
            return 0
            ;;
        plugins)
            COMPREPLY=( $(compgen -W "install list info update remove prune help" -- "$cur") )
            return 0
            ;;
        cloud)
            if [ "$subcmd" = "drs" ]; then
                COMPREPLY=( $(compgen -W "whoami sandbox-create run blueprint-list blueprint-create blueprint-write build build-start build-wait build-logs secret-create help" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "drs help" -- "$cur") )
            fi
            return 0
            ;;
        sandbox)
            COMPREPLY=( $(compgen -W "setup help" -- "$cur") )
            return 0
            ;;
        shell)
            COMPREPLY=( $(compgen -W "init run setup help" -- "$cur") )
            return 0
            ;;
        list|ls)
            COMPREPLY=( $(compgen -W "--format -h --help" -- "$cur") )
            return 0
            ;;
    esac

    # Default top-level completion
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$global_opts" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
    fi
}

if type complete >/dev/null 2>&1; then
    complete -F _devin_fed_completion devin-fed
fi
