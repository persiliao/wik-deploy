#!/usr/bin/env zsh
source ~/.zshrc

yesterday=$(date -v-1d +%Y-%m-%d)

copy_remote_logs "WIK.VPN.HK.Master10.1.3.61" "/opt/prod/icp/logs/sys-console.$yesterday.log" "$(dirname $(realpath $0))/logs"

