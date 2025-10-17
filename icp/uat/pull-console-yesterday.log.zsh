#!/usr/bin/env zsh
source ~/.zshrc

# 获取当前日期和一周前的日期
today=$(date +%Y-%m-%d)
week_ago=$(date -v-5d +%Y-%m-%d)

# 创建目标目录（如果不存在）
log_dir="$(dirname $(realpath $0))/logs"
mkdir -p "$log_dir"

# 循环下载一周内的日志
current_date="$week_ago"
while [[ "$current_date" < "$today" ]]; do
    # 调用你的copy_remote_logs函数
    copy_remote_logs "WIK.VPN.Dev" "/opt/prod/icp/logs/sys-info.$current_date.log" "$log_dir"
    
    # 日期递增
    current_date=$(date -j -v+1d -f "%Y-%m-%d" "$current_date" +%Y-%m-%d)
done

echo "已下载从 $week_ago 到 $today 的日志文件"

