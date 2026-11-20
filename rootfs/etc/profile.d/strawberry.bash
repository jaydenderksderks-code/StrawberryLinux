# Strawberry interactive TTY greeting.
[[ $- == *i* && -t 1 ]] || return 0
[[ ${_strawberry_greeted_pid:-} == "${BASHPID}" ]] && return 0
_strawberry_greeted_pid=$BASHPID
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch --logo-type file --logo /usr/share/strawberry/logo.txt --logo-color-1 green --logo-color-2 red || true
fi
if [[ -e /run/strawberry/live ]]; then
    printf 'Live session: run berryinstall to install Strawberry Linux.\n'
fi
if [[ ${TERM:-} == linux ]]; then
    printf '\033]P0%02x%02x%02x\033]P1%02x%02x%02x\033]P7%02x%02x%02x' 12 8 12 210 45 60 235 235 235
fi
PS1='\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[31m\]\w\[\e[0m\]\$ '
export LS_COLORS='di=01;31:ln=01;36:ex=01;32:*.tar=01;31:*.gz=01;31:*.xz=01;31:*.zip=01;31'
