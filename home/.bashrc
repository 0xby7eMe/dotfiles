#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
eval "$(starship init bash)"
export PATH="$HOME/.cmake-deps/cmake/linux/x64/bin:$PATH" # Added by JetBrains IDE
export PATH="$HOME/.cmake-deps/ninja/linux/x64:$PATH" # Added by JetBrains IDE
export PATH=$PATH:$HOME/go/bin
alias code="flatpak run com.visualstudio.code"
export TERM=xterm-256color
