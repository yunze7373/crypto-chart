#!/bin/bash

# =============================================================================
# CryptoRate Pro 一键部署脚本 (Raspberry Pi/Debian) - 修复版
# =============================================================================

set -euo pipefail

# 配置变量
readonly PROJECT_NAME="CryptoRate Pro"
readonly SERVICE_NAME="crypto-chart"
readonly DEFAULT_PROJECT_DIR="$HOME/crypto-chart"
PROJECT_DIR="${1:-$DEFAULT_PROJECT_DIR}"
readonly GIT_REPO="${CRYPTO_CHART_REPO:-https://github.com/yunze7373/crypto-chart.git}"  # 可通过环境变量覆盖
readonly GIT_BRANCH="${CRYPTO_CHART_BRANCH:-main}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 错误处理
error_exit() {
    log_error "$1"
    exit 1
}

# 检查系统
check_system() {
    log_info "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        error_exit "无法确定操作系统版本"
    fi
    
    # 检查是否为树莓派或Debian系
    if ! grep -qE "(Debian|Ubuntu|Raspbian)" /etc/os-release; then
        log_warning "此脚本专为 Debian/Ubuntu/Raspbian 设计"
    fi
    
    # 检查用户
    if [ "$EUID" -eq 0 ]; then
        error_exit "请不要以 root 用户运行此脚本"
    fi
    
    log_success "系统检查通过"
}

# 安装系统依赖
install_system_dependencies() {
    log_info "安装系统依赖..."
    
    # 更新包列表
    sudo apt-get update
    
    # 安装必要的包
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        git \
        curl \
        nginx \
        supervisor
    
    log_success "系统依赖安装完成"
}

# 克隆项目
clone_project() {
    local target_dir="$1"
    log_info "克隆项目代码到 $target_dir ..."
    # 如果目录已存在，备份
    if [ -d "$target_dir" ]; then
        log_warning "项目目录已存在，创建备份..."
        mv "$target_dir" "${target_dir}.backup.$(date +%s)"
    fi
    # 克隆代码（支持私有库环境变量）
    if [[ -n "${GITHUB_USER:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
        log_info "检测到 GitHub 认证环境变量，使用 HTTPS 认证克隆私有仓库..."
        git clone "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/$(echo "$GIT_REPO" | cut -d'/' -f4- )" "$target_dir" || {
            log_error "无法克隆私有仓库，请检查 GITHUB_USER/GITHUB_TOKEN 环境变量"
            error_exit "代码克隆失败"
        }
    else
        git clone "$GIT_REPO" "$target_dir" || {
            log_error "无法克隆仓库，请检查网络连接和仓库地址"
            log_info "如果是私有仓库，请先配置 SSH 密钥或环境变量"
            error_exit "代码克隆失败"
        }
    fi
    cd "$target_dir"
    log_success "项目克隆完成"
}

# 创建必要的系统目录
create_system_directories() {
    log_info "创建必要的系统目录..."
    
    # 创建日志目录
    sudo mkdir -p /var/log/crypto-chart
    sudo chown $(whoami):$(whoami) /var/log/crypto-chart
    sudo chmod 755 /var/log/crypto-chart
    
    # 创建运行时目录（可选）
    sudo mkdir -p /var/run/crypto-chart || true
    sudo chown $(whoami):$(whoami) /var/run/crypto-chart || true
    
    # 创建项目内日志目录作为备选
    mkdir -p "$PROJECT_DIR/logs"
    
    log_success "系统目录创建完成"
}

# 创建Python虚拟环境
setup_python_environment() {
    log_info "设置 Python 环境..."
    
    cd "$PROJECT_DIR"
    
    # 创建虚拟环境
    python3 -m venv venv
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级pip
    pip install --upgrade pip
    
    # 安装依赖
    if [ -f requirements.txt ]; then
        log_info "从 requirements.txt 安装依赖..."
        pip install -r requirements.txt
    else
        log_info "安装基本依赖..."
        pip install flask requests pandas gunicorn
    fi
    
    # 创建 requirements.txt（如果不存在）
    if [ ! -f requirements.txt ]; then
        log_info "生成 requirements.txt..."
        cat > requirements.txt << EOF
Flask==2.3.3
requests==2.31.0
pandas==2.0.3
gunicorn==21.2.0
EOF
    fi
    
    # 确认 gunicorn 安装成功
    if [ -f "venv/bin/gunicorn" ]; then
        log_success "Python 环境和 gunicorn 安装完成"
        chmod +x venv/bin/gunicorn
    else
        error_exit "gunicorn 安装失败"
    fi
}

# 创建修复版的 gunicorn 配置文件
create_gunicorn_config() {
    log_info "创建 Gunicorn 配置文件..."
    
    cd "$PROJECT_DIR"
    
    # 备份原配置（如果存在）
    if [ -f "gunicorn.conf.py" ]; then
        cp "gunicorn.conf.py" "gunicorn.conf.py.backup.$(date +%s)"
    fi
    
    cat > gunicorn.conf.py << 'EOF'
# Gunicorn 配置文件 - 修复版
import multiprocessing
import os

# 服务器配置
bind = "0.0.0.0:5008"
workers = min(4, multiprocessing.cpu_count())
worker_class = "sync"
worker_connections = 1000
timeout = 120
keepalive = 2
max_requests = 1000
max_requests_jitter = 100

# 日志配置 - 智能路径选择
def get_log_path():
    """智能选择日志路径"""
    # 尝试使用系统日志目录
    system_log_dir = "/var/log/crypto-chart"
    project_log_dir = os.path.join(os.getcwd(), "logs")
    
    # 检查系统日志目录是否可写
    try:
        if os.path.exists(system_log_dir) and os.access(system_log_dir, os.W_OK):
            return system_log_dir
    except:
        pass
    
    # 使用项目日志目录
    os.makedirs(project_log_dir, exist_ok=True)
    return project_log_dir

# 获取日志目录
log_dir = get_log_path()

# 设置日志文件路径
accesslog = os.path.join(log_dir, "gunicorn.access.log")
errorlog = os.path.join(log_dir, "gunicorn.error.log")
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# 进程配置 - 移除权限相关配置
daemon = False
pidfile = None  # 不使用 pidfile，避免权限问题
user = None     # 不强制指定用户，使用启动用户
group = None    # 不强制指定组，使用启动用户的组
tmp_upload_dir = None

# 安全配置
limit_request_line = 4096
limit_request_fields = 100
limit_request_field_size = 8190

# 性能配置
preload_app = True
sendfile = True

def when_ready(server):
    server.log.info("CryptoRate Pro server is ready. Spawning workers")
    server.log.info(f"Log directory: {log_dir}")

def worker_int(worker):
    worker.log.info("Worker received INT or QUIT signal")

def pre_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def post_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def post_worker_init(worker):
    worker.log.info("Worker initialized (pid: %s)", worker.pid)

def worker_abort(worker):
    worker.log.info("Worker aborted (pid: %s)", worker.pid)
EOF
    
    log_success "Gunicorn 配置文件创建完成"
}

# 创建增强的systemd服务文件
create_systemd_service() {
    log_info "创建 systemd 服务..."
    
    USERNAME=$(whoami)
    # 服务文档链接从仓库地址派生（去掉 .git）
    DOC_URL=${GIT_REPO%.git}
    
    cat > "${PROJECT_DIR}/${SERVICE_NAME}.service" << EOF
[Unit]
Description=CryptoRate Pro - 数字资产汇率监控平台
Documentation=${DOC_URL}
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USERNAME}
Group=${USERNAME}
WorkingDirectory=${PROJECT_DIR}
Environment=PATH=${PROJECT_DIR}/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=${PROJECT_DIR}
Environment=PYTHONUNBUFFERED=1
Environment=FLASK_ENV=production
Environment=FLASK_DEBUG=0

# 使用配置文件启动 gunicorn
ExecStart=${PROJECT_DIR}/venv/bin/gunicorn --config ${PROJECT_DIR}/gunicorn.conf.py app:app

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
    # 复制服务文件到系统目录
    sudo cp "${PROJECT_DIR}/${SERVICE_NAME}.service" "/etc/systemd/system/"
    
    # 重新加载systemd配置
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable "$SERVICE_NAME"
    
    log_success "systemd 服务创建完成"
}

# 配置nginx反向代理（可选）
setup_nginx() {
    log_info "配置 Nginx 反向代理..."
    
    # 创建nginx配置文件
    cat > "/tmp/${SERVICE_NAME}" << EOF
server {
    listen 80;
    server_name localhost;
    
    location / {
        proxy_pass http://127.0.0.1:5008;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # 增加超时时间
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 静态文件缓存
    location /static {
        alias ${PROJECT_DIR}/static;
        expires 30d;
    }
    
    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # 移动配置文件
    sudo mv "/tmp/${SERVICE_NAME}" "/etc/nginx/sites-available/"
    
    # 创建软链接
    sudo ln -sf "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/"
    
    # 删除默认站点
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # 测试nginx配置
    sudo nginx -t
    
    # 重启nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    log_success "Nginx 配置完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启动应用服务
    sudo systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "应用服务启动成功"
    else
        log_error "应用服务启动失败，查看详细日志..."
        journalctl -u "$SERVICE_NAME" -n 20 --no-pager
        error_exit "服务启动失败"
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    local health_url="http://localhost:5008"
    local attempt=1
    local max_attempts=5
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查 - 尝试 $attempt/$max_attempts"
        
        if curl -s --max-time 30 "$health_url" > /dev/null 2>&1; then
            log_success "健康检查通过 ✅"
            return 0
        fi
        
        log_warning "健康检查失败，等待重试..."
        sleep 10
        ((attempt++))
    done
    
    log_error "健康检查失败，但服务可能仍在启动中"
    log_info "请稍后手动检查: curl http://localhost:5008"
    return 1
}

# 显示部署结果
show_deployment_info() {
    log_info "=== 部署完成 ==="
    echo ""
    log_success "🎉 $PROJECT_NAME 部署成功！"
    echo ""
    echo "访问地址："
    echo "  - 应用直连: http://$(hostname -I | awk '{print $1}'):5008"
    if systemctl is-enabled nginx &>/dev/null; then
        echo "  - Nginx代理: http://$(hostname -I | awk '{print $1}')"
    fi
    echo ""
    echo "服务管理命令："
    echo "  - 查看状态: systemctl status $SERVICE_NAME"
    echo "  - 查看日志: journalctl -u $SERVICE_NAME -f"
    echo "  - 重启服务: sudo systemctl restart $SERVICE_NAME"
    echo "  - 停止服务: sudo systemctl stop $SERVICE_NAME"
    echo ""
    echo "日志位置："
    echo "  - 系统日志: /var/log/crypto-chart/ (如果可写)"
    echo "  - 项目日志: $PROJECT_DIR/logs/ (备选)"
    echo "  - 系统日志: journalctl -u $SERVICE_NAME"
    echo ""
    echo "项目目录: $PROJECT_DIR"
    echo ""
}

# 主安装流程
main() {
    log_info "=== $PROJECT_NAME 一键部署脚本 (修复版) ==="
    log_info "开始部署..."
    
    # 1. 系统检查
    check_system
    
    # 2. 安装系统依赖
    install_system_dependencies
    
    # 3. 克隆项目（支持自定义安装路径）
    clone_project "$PROJECT_DIR"
    
    # 4. 创建必要的系统目录
    create_system_directories
    
    # 5. 设置Python环境
    setup_python_environment
    
    # 6. 创建Gunicorn配置文件
    create_gunicorn_config
    
    # 7. 创建systemd服务
    create_systemd_service
    
    # 8. 配置nginx（询问用户是否需要）
    if [[ "${1:-}" != "--no-nginx" ]]; then
        read -p "是否配置 Nginx 反向代理？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_nginx
        else
            log_info "跳过 Nginx 配置"
        fi
    else
        log_info "跳过 Nginx 配置 (--no-nginx 参数)"
    fi
    
    # 9. 启动服务
    start_services
    
    # 10. 健康检查
    health_check
    
    # 11. 显示部署信息
    show_deployment_info
}

# 检查参数
if [ $# -gt 0 ]; then
    case "$1" in
        "--help"|"-h")
            echo "用法: $0 [选项] [项目目录]"
            echo "选项:"
            echo "  --help, -h    显示此帮助信息"
            echo "  --no-nginx    跳过 Nginx 配置"
            echo "示例:"
            echo "  $0                          # 默认安装到 $DEFAULT_PROJECT_DIR"
            echo "  $0 /opt/crypto-chart        # 安装到指定目录"
            echo "  $0 --no-nginx               # 跳过 Nginx 配置"
            exit 0
            ;;
        "--no-nginx")
            shift
            PROJECT_DIR="${1:-$DEFAULT_PROJECT_DIR}"
            ;;
    esac
fi

# 运行主函数
main "$@"