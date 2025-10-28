#!/usr/bin/env zsh
# 智能部署脚本 - 根据文件名自动识别环境

# ========================
# 配置区（请根据实际修改）
# ========================
# 服务器组配置
declare -A SERVER_GROUPS=(
    [test]="WIK.VPN.Dev"
    [prod]="WIK.VPN.HK.Master10.1.3.61"
)

# 部署路径配置
declare -A DEPLOY_PATHS=(
    [test_icp]="/opt/prod/icp"
    [test_apk]="/opt/prod/icp/apk"
    [prod_icp]="/opt/prod/icp"
    [prod_apk]="/opt/prod/icp/apk"
)

# 日志文件配置
DEPLOY_LOG="deploy.log"

# ========================
# 核心部署逻辑
# ========================
# 智能识别文件环境
detect_environment() {
    local file=$1
    case $file in
        *-test.*) echo "test" ;;
        *-prod.*) echo "prod" ;;
        *) echo "unknown" ;;
    esac
}

# 记录部署日志
log_deployment() {
    local file=$1
    local env=$2
    local server=$3
    local deploy_status=$4  # 修改变量名避免使用关键字
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo "[${timestamp}] ${file} -> ${env}@${server}: ${deploy_status}" >> "${DEPLOY_LOG}"
}

# 安全部署函数
deploy_file() {
    local file=$1
    local env=$2
    local server=$3

    __persiliao_tip "开始部署 ${file} 到 ${env} 环境服务器 ${server}"

    # 根据文件类型确定目标路径
    local target_path
    case $file in
        *.jar) target_path=${DEPLOY_PATHS[${env}_icp]} ;;
        *.zip) target_path=${DEPLOY_PATHS[${env}_icp]} ;;
        *.apk) target_path=${DEPLOY_PATHS[${env}_apk]} ;;
        *) __persiliao_error "不支持的文件类型: ${file}"; return 1 ;;
    esac

    # 执行部署
    if ! scp "$file" "${server}:${target_path}/"; then
        __persiliao_error "文件上传失败: ${file}"
        log_deployment "$file" "$env" "$server" "FAILED: scp error"
        return 1
    fi

    # 执行远程命令（根据文件类型）
    case $file in
        *.jar)
            ssh "$server" "
                set -e
                mkdir -p ${target_path}
                cd ${target_path}
                docker compose down && docker compose up -d
            " || {
                __persiliao_error "Docker操作失败: ${file}"
                log_deployment "$file" "$env" "$server" "FAILED: docker error"
                return 1
            }
            ;;
        *.zip)
            ssh "$server" "
                set -e
                mkdir -p ${target_path}/index
                rm -rf ${target_path}/index/*
                unzip -q -d ${target_path}/index -o ${target_path}/${file}
                rm -f ${target_path}/${file}
                chmod -R 755 ${target_path}/index
            " || {
                __persiliao_error "解压操作失败: ${file}"
                log_deployment "$file" "$env" "$server" "FAILED: unzip error"
                return 1
            }
            ;;
        *.apk)
            ssh "$server" "
                set -e
                mkdir -p ${target_path}
                # 保留3个历史版本
                ls -t ${target_path}/*.apk 2>/dev/null | tail -n +4 | xargs rm -f
                # 创建最新版本链接
                ln -sf ${target_path}/${file} ${target_path}/icp-app.apk
            " || {
                __persiliao_error "APK部署失败: ${file}"
                log_deployment "$file" "$env" "$server" "FAILED: apk deployment error"
                return 1
            }
            ;;
    esac

    log_deployment "$file" "$env" "$server" "SUCCESS"
    __persiliao_success "成功部署到 ${server}"
}

safe_cleanup() {
    local file=$1
    
    # 检查文件是否存在
    [[ ! -f $file ]] && {
        __persiliao_warning "文件不存在，无法清理: $file"
        return
    }
    
    # 直接删除文件
    rm -v "$file" && __persiliao_success "已清理: $file"
}

# 安全收集文件函数
collect_deploy_files() {
    local found_files=()
    
    # 分别检查每种模式，避免无匹配时保留模式字符串
    for pattern in '*-test.jar' '*-prod.jar' '*-test.zip' '*-prod.zip' '*-test.apk' '*-prod.apk'; do
        # 使用 (N) glob 限定符：如果无匹配则不返回模式本身
        found_files+=(${~pattern}(N))
    done
    
    # 返回收集到的文件
    echo ${(u)found_files}  # (u) 去重
}

# ========================
# 主控制流程
# ========================
main() {
    # 初始化日志文件
    if [[ ! -f "${DEPLOY_LOG}" ]]; then
        touch "${DEPLOY_LOG}"
        __persiliao_notice "创建新的部署日志文件: ${DEPLOY_LOG}"
    fi

    # 获取当前目录下所有匹配文件
    local files=($(collect_deploy_files))
    if [[ ${#files} -eq 0 ]]; then
        __persiliao_error "未找到可部署文件 (*-test.jar, *-prod.jar, *-test.zip, *-prod.zip, *-test.apk 或 *-prod.apk)"
        exit 1
    fi

    # 记录开始部署
    echo -e "\n===== 新部署开始 [$(date +"%Y-%m-%d %H:%M:%S")] =====" >> "${DEPLOY_LOG}"
    echo "待部署文件: ${(j:, :)files}" >> "${DEPLOY_LOG}"

    # 生产环境二次确认
    if [[ -n "${(M)files:#*-prod*}" ]]; then
        read -q "confirm?检测到生产环境文件，确认部署？(y/n) "
        echo
        [[ "$confirm" != "y" ]] && {
            echo "用户取消生产环境部署" >> "${DEPLOY_LOG}"
            exit 0
        }
    fi

    # 遍历处理所有文件
    local has_errors=0
    for file in $files; do
        local env=$(detect_environment "$file")
        if [[ "$env" == "unknown" ]]; then
            __persiliao_warning "跳过无法识别环境的文件: ${file}"
            echo "跳过无法识别环境的文件: ${file}" >> "${DEPLOY_LOG}"
            continue
        fi

        # 获取对应环境的服务器组
        local servers=(${=SERVER_GROUPS[$env]})
        if [[ ${#servers} -eq 0 ]]; then
            __persiliao_error "未配置 ${env} 环境的服务器组"
            echo "错误: 未配置 ${env} 环境的服务器组" >> "${DEPLOY_LOG}"
            has_errors=1
            continue
        fi

        # 部署到所有目标服务器
        for server in $servers; do
            if ! deploy_file "$file" "$env" "$server"; then
                has_errors=1
            fi
        done
        
        if [[ $has_errors -eq 0 ]]; then
            safe_cleanup "$file" "$env"
        else
            __persiliao_error "文件 ${file} 部署过程中出现错误"
        fi

    done

    # 生成部署报告
    __persiliao_section "===== 部署摘要 ====="
    __persiliao_notice "处理文件: ${(j:, :)files}"
    __persiliao_notice "部署环境: ${(j:, :)${(u)${files##*-}%%.*}}"
    if [[ $has_errors -eq 0 ]]; then
        __persiliao_success "所有文件部署成功!"
        echo "部署结果: 所有文件部署成功" >> "${DEPLOY_LOG}"
    else
        __persiliao_error "部署完成，但部分操作失败"
        echo "部署结果: 部分操作失败" >> "${DEPLOY_LOG}"
        exit 1
    fi
}

# ========================
# 工具函数（美化输出）
# ========================
__persiliao_section() { print -P "%F{blue}%B$1%b%f" }
__persiliao_tip() { print -P "%F{cyan}➤ $1%f" }
__persiliao_success() { print -P "%F{green}✓ $1%f" }
__persiliao_warning() { print -P "%F{yellow}⚠ $1%f" >&2 }
__persiliao_error() { print -P "%F{red}✗ $1%f" >&2 }
__persiliao_notice() { print -P "%F{magenta}ℹ $1%f" }

# ========================
# 脚本入口
# ========================
main "$@"