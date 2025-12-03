#!/usr/bin/env zsh
source ~/.zshrc

copy_remote_logs "WIK.VPN.HK.Master10.1.3.61" "/opt/prod/restapi/log/app.log" "$(dirname $(realpath $0))/logs/hk-master"
copy_remote_logs "WIK.VPN.HK.Slave10.2.1.61" "/opt/prod/restapi/log/app.log" "$(dirname $(realpath $0))/logs/hk-slave"

# copy_remote_logs "WIK.VPN.SZ.Master10.2.1.62" "/opt/prod/restapi/log/app.log" "$(dirname $(realpath $0))/logs/sz-master"
# copy_remote_logs "WIK.VPN.SZ.Slave10.2.1.63" "/opt/prod/restapi/log/app.log" "$(dirname $(realpath $0))/logs/sz-slave"