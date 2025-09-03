#!/usr/bin/env zsh
source ~/.zshrc

copy_remote_logs "WIK.VPN.Dev" "/opt/prod/icp/logs/sys-console.log" "$(dirname $(realpath $0))/logs"