# Aliases para funciones personalizadas
alias hm='helpme'
alias ws='workspace'
alias hs='hosts-ssh'
alias hg='hosts-gcp'
alias cb='copyclipboard'
alias hc='harlequin-connection'
alias hv='harlequin-vertical'

# Aliases de sesion/energia
alias sd='systemctl poweroff'
alias rb='systemctl reboot'
alias lou='loginctl terminate-session "$XDG_SESSION_ID"'

# Secretos efímeros (script ~/.dotfiles/cred/cred, enlazado en ~/.local/bin)
alias credls='cred ls'
alias credrm='cred rm'
alias credrun='cred run'
