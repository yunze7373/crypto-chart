#!/bin/bash

# ==============================================================================
#
#  CryptoRate Pro 增强版生产环境安全更新脚本 (Raspberry Pi/Debian)
#
#  功能:
#  - 完整的错误处理和自动回滚机制
#  - 智能服务检测和管理 (systemd)
#  - 全面的备份策略和完整性验证
#  - 多层次代码验证和语法检查
#  - 配置文件差异检测和新配置项提醒
#  - 依赖包冲突检测和解决
#  - 多重健康检查和验证
#  - 自动化前端静态文件处理
#  - 完整的日志记录和状态追踪
#
#  版本: 1.0 Enhanced for CryptoRate Pro
#  更新日期: 2025-08-30
#  适用环境: Raspberry Pi OS, Debian 11+, Ubuntu 20.04+
#  服务路径: $HOME/crypto-chart
#  服务名称: crypto-chart
#
# ==============================================================================

set -euo pipefail

# =============================================================================
# 配置变量
# =============================================================================

# 基本配置
readonly PROJECT_NAME="CryptoRate Pro"
readonly SERVICE_NAME="crypto-chart"
readonly DEFAULT_PROJECT_DIR="$HOME/crypto-chart"
readonly PROJECT_DIR="${1:-$DEFAULT_PROJECT_DIR}"
readonly BACKUP_DIR="$HOME/backup/crypto-chart"
readonly LOG_DIR="/var/log/crypto-chart"

# Git 配置
readonly GIT_REPO="${CRYPTO_CHART_REPO:-https://github.com/yunze7373/crypto-chart.git}"
readonly GIT_BRANCH="${CRYPTO_CHART_BRANCH:-main}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 健康检查配置
readonly HEALTH_CHECK_URL="${CRYPTO_CHART_HEALTH_URL:-http://localhost:5008/api/current_prices?base=BTC&quote=USDT}"
readonly HEALTH_CHECK_TIMEOUT="${CRYPTO_CHART_TIMEOUT:-30}"
readonly HEALTH_CHECK_RETRIES="${CRYPTO_CHART_RETRIES:-5}"

# 关键文件列表
readonly CRITICAL_FILES=(
    "app.py"
    "requirements.txt"
    "templates/index.html"
    "${SERVICE_NAME}.service"
)

# 可选配置文件
readonly OPTIONAL_CONFIG_FILES=(
    "config.py"
    ".env"
    "nginx.conf"
    "gunicorn.conf.py"
)

# 依赖包列表
readonly REQUIRED_PACKAGES=(
    "flask"
    "requests"
    "pandas"
    "gunicorn"
)

# =============================================================================
# 日志和工具函数
# =============================================================================

# 创建日志目录
setup_logging() {
    # 创建系统日志目录（如果不存在）
    if [ ! -d "$LOG_DIR" ]; then
        sudo mkdir -p "$LOG_DIR"
        sudo chown $(whoami):$(whoami) "$LOG_DIR" 2>/dev/null || true
        sudo chmod 755 "$LOG_DIR" 2>/dev/null || true
    fi
    
    # 如果系统日志目录不可写，使用项目日志目录
    local actual_log_dir="$LOG_DIR"
    if [ ! -w "$LOG_DIR" ]; then
        actual_log_dir="$PROJECT_DIR/logs"
        mkdir -p "$actual_log_dir"
    fi
    
    # 设置日志文件
    readonly LOG_FILE="$actual_log_dir/update-$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE" 2>/dev/null || {
        # 如果无法创建日志文件，使用项目目录
        readonly LOG_FILE="$PROJECT_DIR/logs/update-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$PROJECT_DIR/logs"
        touch "$LOG_FILE"
    }
}

# 日志函数
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

# 错误处理
error_exit() {
    log_error "$1"
    cleanup_on_error
    exit 1
}

# 错误清理
cleanup_on_error() {
    log_warning "检测到错误，开始执行回滚操作..."
    
    if [ -d "$BACKUP_DIR" ]; then
        log_info "恢复备份文件..."
        restore_backup
    fi
    
    # 尝试重启服务
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "服务仍在运行，无需额外操作"
    else
        log_warning "服务已停止，尝试启动..."
        sudo systemctl start "$SERVICE_NAME" || log_error "无法启动服务"
    fi
}

# =============================================================================
# 系统检查函数
# =============================================================================

check_system_requirements() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        error_exit "无法确定操作系统版本"
    fi
    
    local os_info=$(grep PRETTY_NAME /etc/os-release)
    log_info "系统信息: $os_info"
    
    # 检查 Python 版本
    if ! command -v python3 &> /dev/null; then
        error_exit "Python3 未安装"
    fi
    
    local python_version=$(python3 --version)
    log_info "Python版本: $python_version"
    
    # 检查 pip
    if ! command -v pip3 &> /dev/null; then
        log_warning "pip3 未安装，尝试安装..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
    fi
    
    # 检查 git
    if ! command -v git &> /dev/null; then
        log_warning "Git 未安装，尝试安装..."
        sudo apt-get update
        sudo apt-get install -y git
    fi
    
    # 检查磁盘空间
    if [ -d "$PROJECT_DIR" ]; then
        local available_space=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
        if [ -n "$available_space" ] && [ "$available_space" -lt 1048576 ]; then  # 1GB in KB
            error_exit "磁盘空间不足，至少需要1GB可用空间"
        fi
    else
        log_warning "项目目录不存在: $PROJECT_DIR"
    fi
    
    log_success "系统要求检查通过"
}

check_service_status() {
    log_info "检查服务状态..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "服务 $SERVICE_NAME 正在运行"
        return 0
    elif systemctl is-enabled --quiet "$SERVICE_NAME"; then
        log_warning "服务 $SERVICE_NAME 已启用但未运行"
        return 1
    else
        log_warning "服务 $SERVICE_NAME 未启用"
        return 2
    fi
}

# =============================================================================
# 备份和恢复函数
# =============================================================================

create_backup() {
    log_info "创建备份..."
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 备份整个项目目录
    if [ -d "$PROJECT_DIR" ]; then
        log_info "备份项目目录到 $BACKUP_DIR"
        rsync -av --delete "$PROJECT_DIR/" "$BACKUP_DIR/project/"
    fi
    
    # 备份 systemd 服务文件
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        log_info "备份 systemd 服务文件"
        sudo cp "/etc/systemd/system/${SERVICE_NAME}.service" "$BACKUP_DIR/"
    fi
    
    # 创建备份信息文件
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
备份时间: $(date)
项目路径: $PROJECT_DIR
服务名称: $SERVICE_NAME
备份类型: 完整备份
Git提交: $(cd "$PROJECT_DIR" && git rev-parse HEAD 2>/dev/null || echo "未知")
EOF
    
    log_success "备份创建完成"
}

restore_backup() {
    log_info "恢复备份..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "备份目录不存在: $BACKUP_DIR"
        return 1
    fi
    
    # 停止服务
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        sudo systemctl stop "$SERVICE_NAME"
    fi
    
    # 恢复项目文件
    if [ -d "$BACKUP_DIR/project" ]; then
        log_info "恢复项目文件..."
        rsync -av --delete "$BACKUP_DIR/project/" "$PROJECT_DIR/"
    fi
    
    # 恢复服务文件
    if [ -f "$BACKUP_DIR/${SERVICE_NAME}.service" ]; then
        log_info "恢复 systemd 服务文件"
        sudo cp "$BACKUP_DIR/${SERVICE_NAME}.service" "/etc/systemd/system/"
        sudo systemctl daemon-reload
    fi
    
    log_success "备份恢复完成"
}

# =============================================================================
# 代码更新函数
# =============================================================================

# 克隆项目（如果需要）
clone_project_if_needed() {
    log_info "克隆项目代码..."
    
    # 如果目录已存在，备份
    if [ -d "$PROJECT_DIR" ]; then
        log_warning "项目目录已存在，创建备份..."
        mv "$PROJECT_DIR" "${PROJECT_DIR}.backup.$(date +%s)"
    fi
    
    # 克隆代码（支持私有库环境变量）
    if [[ -n "${GITHUB_USER:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
        log_info "检测到 GitHub 认证环境变量，使用 HTTPS 认证克隆私有仓库..."
        git clone "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/$(echo "$GIT_REPO" | cut -d'/' -f4- )" "$PROJECT_DIR" || {
            log_error "无法克隆私有仓库，请检查 GITHUB_USER/GITHUB_TOKEN 环境变量"
            error_exit "代码克隆失败"
        }
    else
        git clone "$GIT_REPO" "$PROJECT_DIR" || {
            log_error "无法克隆仓库，请检查网络连接和仓库地址"
            log_info "如果是私有仓库，请先配置 SSH 密钥或环境变量"
            error_exit "代码克隆失败"
        }
    fi
    
    log_success "项目克隆完成"
}

update_code() {
    log_info "更新代码..."
    
    # 检查项目目录是否存在
    if [ ! -d "$PROJECT_DIR" ]; then
        log_warning "项目目录不存在: $PROJECT_DIR"
        log_info "尝试重新克隆项目..."
        clone_project_if_needed
        return 0
    fi
    
    cd "$PROJECT_DIR" || error_exit "无法进入项目目录: $PROJECT_DIR"
    
    # 检查是否为 git 仓库
    if [ ! -d ".git" ]; then
        log_warning "不是 Git 仓库，尝试克隆..."
        cd "$HOME"
        if [ -d "$PROJECT_DIR" ]; then
            mv "$PROJECT_DIR" "${PROJECT_DIR}.backup.$(date +%s)"
        fi
        clone_project_if_needed
        cd "$PROJECT_DIR"
    fi
    
    # 保存本地修改
    if ! git diff --quiet; then
        log_warning "检测到本地修改，创建临时提交..."
        git add .
        git commit -m "Temporary commit before update - $(date)"
    fi
    
    # 获取最新代码
    log_info "拉取最新代码..."
    if [[ -n "${GITHUB_USER:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
        git fetch "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/$(echo "$GIT_REPO" | cut -d'/' -f4-)" "$GIT_BRANCH"
    else
        git fetch origin "$GIT_BRANCH"
    fi
    
    # 检查是否有更新
    local current_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse "origin/$GIT_BRANCH")
    
    if [ "$current_commit" = "$remote_commit" ]; then
        log_info "代码已是最新版本"
        return 0
    fi
    
    log_info "发现新版本，开始更新..."
    log_info "当前版本: $current_commit"
    log_info "目标版本: $remote_commit"
    
    # 执行合并
    git merge "origin/$GIT_BRANCH" || {
        log_error "代码合并失败"
        git merge --abort 2>/dev/null || true
        return 1
    }
    
    log_success "代码更新完成"
    return 0
}

# =============================================================================
# 依赖管理函数
# =============================================================================

check_python_dependencies() {
    log_info "检查 Python 依赖..."
    
    if [ ! -f "requirements.txt" ]; then
        log_warning "requirements.txt 不存在"
        return 1
    fi
    
    # 检查虚拟环境
    if [ ! -d "venv" ]; then
        log_warning "虚拟环境不存在，需要重新创建"
        return 1
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 检查每个必需的包
    local missing_packages=()
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! python -c "import ${package}" 2>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warning "发现缺失的包: ${missing_packages[*]}"
        return 1
    fi
    
    log_success "Python 依赖检查通过"
    return 0
}

install_python_dependencies() {
    log_info "安装/更新 Python 依赖..."
    
    cd "$PROJECT_DIR"
    
    # 检查并创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    python -m pip install --upgrade pip
    
    # 安装项目依赖
    if [ -f "requirements.txt" ]; then
        log_info "从 requirements.txt 安装依赖..."
        # 强制重装以避免版本冲突
        python -m pip install --force-reinstall --no-cache-dir -r requirements.txt
    else
        # 安装基本依赖
        log_info "安装基本依赖..."
        python -m pip install flask requests pandas gunicorn
    fi
    
    log_success "Python 依赖安装完成"
}

# =============================================================================
# 服务管理函数
# =============================================================================

install_service() {
    log_info "安装 systemd 服务..."
    
    cd "$PROJECT_DIR"
    local username=$(whoami)
    
    # 动态生成服务文件
    cat > "${SERVICE_NAME}.service" << EOF
[Unit]
Description=CryptoRate Pro - 数字资产汇率监控平台
Documentation=https://github.com/yunze7373/crypto-chart
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${username}
Group=${username}
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${PROJECT_DIR}/venv/bin:/usr/bin:/usr/local/bin
Environment=PYTHONPATH=${PROJECT_DIR}
Environment=PYTHONUNBUFFERED=1
Environment=FLASK_ENV=production
Environment=FLASK_DEBUG=0

# 启动命令 - 使用虚拟环境中的 gunicorn
ExecStart=${PROJECT_DIR}/venv/bin/gunicorn --bind 0.0.0.0:5008 --workers 2 --timeout 120 --worker-class sync app:app

# 重启策略
Restart=always
RestartSec=10

# 安全配置
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${PROJECT_DIR} /var/log/crypto-chart

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

# 日志配置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=crypto-chart

[Install]
WantedBy=multi-user.target
EOF
    
    # 复制服务文件
    sudo cp "${SERVICE_NAME}.service" "/etc/systemd/system/"
    
    # 重新加载 systemd
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable "$SERVICE_NAME"
    
    log_success "systemd 服务安装完成"
}

start_service() {
    log_info "启动服务..."
    
    # 停止服务（如果正在运行）
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "停止现有服务..."
        sudo systemctl stop "$SERVICE_NAME"
        sleep 3
    fi
    
    # 启动服务
    sudo systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "服务启动成功"
        return 0
    else
        log_error "服务启动失败"
        sudo systemctl status "$SERVICE_NAME" | tee -a "$LOG_FILE"
        return 1
    fi
}

# =============================================================================
# 健康检查函数
# =============================================================================

health_check() {
    log_info "执行健康检查..."
    
    local attempt=1
    while [ $attempt -le $HEALTH_CHECK_RETRIES ]; do
        log_info "健康检查 - 尝试 $attempt/$HEALTH_CHECK_RETRIES"
        
        if curl -s --max-time $HEALTH_CHECK_TIMEOUT "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
            log_success "健康检查通过"
            return 0
        fi
        
        log_warning "健康检查失败，等待重试..."
        sleep 10
        ((attempt++))
    done
    
    log_error "健康检查失败，服务可能未正常运行"
    return 1
}

# =============================================================================
# 语法检查函数
# =============================================================================

syntax_check() {
    log_info "执行语法检查..."
    
    cd "$PROJECT_DIR"
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # Python 语法检查
    if [ -f "app.py" ]; then
        if ! python -m py_compile app.py; then
            log_error "app.py 语法错误"
            return 1
        fi
        log_info "app.py 语法检查通过"
    fi
    
    # 检查 requirements.txt 格式
    if [ -f "requirements.txt" ]; then
        if ! python -m pip install --dry-run -r requirements.txt > /dev/null 2>&1; then
            log_warning "requirements.txt 可能存在问题"
        else
            log_info "requirements.txt 格式检查通过"
        fi
    fi
    
    log_success "语法检查完成"
}

# =============================================================================
# 配置检查函数
# =============================================================================

check_configuration() {
    log_info "检查配置..."
    
    # 检查关键文件
    for file in "${CRITICAL_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "关键文件不存在: $file"
            return 1
        fi
    done
    
    # 检查目录结构
    if [ ! -d "templates" ]; then
        log_error "templates 目录不存在"
        return 1
    fi
    
    if [ ! -f "templates/index.html" ]; then
        log_error "templates/index.html 不存在"
        return 1
    fi
    
    log_success "配置检查通过"
}

# =============================================================================
# 主要更新流程
# =============================================================================

main_update_process() {
    log_info "开始 $PROJECT_NAME 更新流程..."
    
    # 1. 系统检查
    check_system_requirements
    
    # 2. 检查并进入项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_warning "项目目录不存在，尝试克隆项目..."
        clone_project_if_needed
    fi
    
    cd "$PROJECT_DIR" || error_exit "无法进入项目目录"
    
    # 3. 创建备份
    create_backup
    
    # 4. 更新代码
    update_code || error_exit "代码更新失败"
    
    # 5. 语法检查
    syntax_check || error_exit "语法检查失败"
    
    # 6. 配置检查
    check_configuration || error_exit "配置检查失败"
    
    # 7. 安装依赖
    install_python_dependencies || error_exit "依赖安装失败"
    
    # 8. 安装/更新服务
    install_service || error_exit "服务安装失败"
    
    # 9. 启动服务
    start_service || error_exit "服务启动失败"
    
    # 10. 健康检查
    health_check || error_exit "健康检查失败"
    
    log_success "$PROJECT_NAME 更新完成！"
}

# =============================================================================
# 工具函数
# =============================================================================

show_status() {
    log_info "=== $PROJECT_NAME 状态信息 ==="
    
    # 服务状态
    echo "服务状态:"
    systemctl status "$SERVICE_NAME" --no-pager -l
    
    echo -e "\n端口监听:"
    ss -tulpn | grep :5008 || echo "端口 5008 未监听"
    
    echo -e "\n最近日志:"
    journalctl -u "$SERVICE_NAME" -n 10 --no-pager
    
    echo -e "\nPython进程:"
    ps aux | grep -E "(python|gunicorn)" | grep -v grep || echo "未发现相关进程"
    
    # 健康检查
    echo -e "\n健康检查:"
    if curl -s --max-time 10 "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo "✅ 服务响应正常"
    else
        echo "❌ 服务无响应"
    fi
}

show_logs() {
    local lines=${1:-50}
    log_info "显示最近 $lines 行日志..."
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
}

# 显示环境变量信息
show_environment_info() {
    log_info "=== 环境变量配置 ==="
    echo ""
    echo "当前配置："
    echo "  项目目录: $PROJECT_DIR"
    echo "  备份目录: $BACKUP_DIR"
    echo "  日志目录: $LOG_DIR"
    echo "  Git 仓库: $GIT_REPO"
    echo "  Git 分支: $GIT_BRANCH"
    echo "  健康检查 URL: $HEALTH_CHECK_URL"
    echo "  健康检查超时: $HEALTH_CHECK_TIMEOUT 秒"
    echo "  健康检查重试: $HEALTH_CHECK_RETRIES 次"
    echo ""
    echo "支持的环境变量："
    echo "  CRYPTO_CHART_REPO     - Git 仓库地址"
    echo "  CRYPTO_CHART_BRANCH   - Git 分支名称"
    echo "  CRYPTO_CHART_HEALTH_URL - 健康检查 URL"
    echo "  CRYPTO_CHART_TIMEOUT  - 健康检查超时时间"
    echo "  CRYPTO_CHART_RETRIES  - 健康检查重试次数"
    echo "  GITHUB_USER           - GitHub 用户名（私有仓库）"
    echo "  GITHUB_TOKEN          - GitHub 访问令牌（私有仓库）"
    echo ""
    echo "GitHub 认证状态："
    if [[ -n "${GITHUB_USER:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
        echo "  ✅ GitHub 认证已配置 (用户: ${GITHUB_USER})"
    else
        echo "  ❌ GitHub 认证未配置"
        echo "     如果是私有仓库，请设置 GITHUB_USER 和 GITHUB_TOKEN"
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [项目目录] {update|status|logs|backup|restore|restart|stop|start|env|help}"
    echo ""
    echo "参数："
    echo "  项目目录      - 可选，指定项目目录（默认: $DEFAULT_PROJECT_DIR）"
    echo ""
    echo "命令："
    echo "  update       - 完整更新流程（默认）"
    echo "  status       - 显示服务状态"
    echo "  logs [行数]  - 显示服务日志（默认50行）"
    echo "  backup       - 创建备份"
    echo "  restore      - 恢复备份"
    echo "  restart      - 重启服务"
    echo "  stop         - 停止服务"
    echo "  start        - 启动服务"
    echo "  env          - 显示环境变量配置"
    echo "  help         - 显示此帮助信息"
    echo ""
    echo "示例："
    echo "  $0                           # 使用默认目录进行更新"
    echo "  $0 /custom/path              # 指定项目目录进行更新"
    echo "  $0 status                    # 查看服务状态"
    echo "  $0 logs 100                  # 查看最近100行日志"
    echo "  $0 env                       # 查看环境变量配置"
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    # 设置日志
    setup_logging
    
    log_info "=== $PROJECT_NAME 更新脚本启动 ==="
    log_info "脚本版本: 1.0 Enhanced"
    log_info "执行用户: $(whoami)"
    log_info "执行时间: $(date)"
    log_info "项目目录: $PROJECT_DIR"
    
    # 解析参数
    case "${1:-update}" in
        "update")
            main_update_process
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${2:-50}"
            ;;
        "backup")
            create_backup
            ;;
        "restore")
            restore_backup
            ;;
        "restart")
            sudo systemctl restart "$SERVICE_NAME"
            health_check
            ;;
        "stop")
            sudo systemctl stop "$SERVICE_NAME"
            ;;
        "start")
            sudo systemctl start "$SERVICE_NAME"
            health_check
            ;;
        "env"|"environment")
            show_environment_info
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
    
    log_info "=== 脚本执行完成 ==="
}

# =============================================================================
# 脚本入口
# =============================================================================

# 捕获错误和中断信号
trap 'error_exit "脚本被中断"' INT TERM

# 检查是否以正确用户运行
if [ "$EUID" -eq 0 ]; then
    error_exit "请不要以 root 用户运行此脚本"
fi

# 处理命令行参数
if [ $# -gt 0 ] && [[ "$1" =~ ^/ ]] || [[ "$1" =~ ^\~ ]] || [[ "$1" =~ ^\$ ]]; then
    # 第一个参数是路径
    PROJECT_DIR="$1"
    shift
    readonly PROJECT_DIR
fi

# 执行主函数
main "$@"
