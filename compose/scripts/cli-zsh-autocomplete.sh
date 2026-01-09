#compdef bitcart-cli
: ${PROG:=${$(basename "$funcstack[1]")#_}}

compdef _bitcart_cli_zsh_autocomplete $PROG

_bitcart_cli_zsh_autocomplete() {
        local -a opts
        local current
        current=${words[-1]}
        if [[ "$current" == "-"* ]]; then
                opts=("${(@f)$(${words[@]:0:#words[@]-1} ${current} --generate-shell-completion)}")
        else
                opts=("${(@f)$(${words[@]:0:#words[@]-1} --generate-shell-completion)}")
        fi
        if [[ "${opts[1]}" != "" ]]; then
                _describe 'values' opts
        else
                _files
        fi
}

if [ "$funcstack[1]" = "_$PROG" ]; then
        _bitcart_cli_zsh_autocomplete
fi
unset PROG
