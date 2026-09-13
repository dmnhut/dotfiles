if status is-interactive
    set -g fish_greeting
end
set -Ux PATH $HOME/.cargo/bin $PATH
set -Ux PATH (npm bin -g) $PATH
set -gx PATH "$HOME/.local/bin" $PATH
alias yay paru
