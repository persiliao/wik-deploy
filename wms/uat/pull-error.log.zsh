#!/usr/bin/env zsh

source ~/.zshrc

copy_remote_logs "WIK.VPN.Dev" "/opt/prod/icp/logs/sys-error.log" "$(dirname $(realpath $0))/logs"