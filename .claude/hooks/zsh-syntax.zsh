#!/bin/zsh -f
# Claude Code PostToolUse hook: syntax-check a Zsh file right after Claude
# edits it. Reads the hook's JSON from stdin; exits 2 with the parser error on
# stderr (shown to Claude) when `zsh -n` fails, and 0 for valid or non-Zsh
# files. Runs with -f so no user startup file is read.

emulate -L zsh
setopt EXTENDED_GLOB

typeset input='' file='' errors=''
typeset -a match=() mbegin=() mend=()

input=$(</dev/stdin) 2>/dev/null || exit 0
[[ $input =~ '"file_path"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"' ]] || exit 0
file=$match[1]
file=${file//\\\//\/}
file=${file//\\\"/\"}
file=${file//\\\\/\\}

[[ -f $file ]] || exit 0
[[ $file == */.zsh.addons/support/cache/* ]] && exit 0
case ${file:t} in
  (.zshrc|.zsh.?*|*.zsh) ;;
  (*) exit 0 ;;
esac

errors=$(/bin/zsh -fn -- "$file" 2>&1) && exit 0
print -u2 -r -- "zsh -n failed for $file:"
print -u2 -r -- "$errors"
exit 2
