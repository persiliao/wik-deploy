#!/usr/bin/env zsh
source ~/.zshrc

copy_remote_logs "WIK.VPN.Dev" "/opt/qas/restapi/log/app.log" "$(dirname $(realpath $0))/logs"