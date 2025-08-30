#!/bin/bash

# CryptoRate Pro 系统配置脚本 - 修复版
# 用于设置定时任务、日志轮转等系统级配置

set -euo pipefail

readonly PROJECT_DIR="$HOME/crypto-chart"
readonly LOG_DIR="/var/log/crypto-chart"
readonly BACKUP_DIR="$HOME/backup/crypto-chart"
readonly USERNAME=$(whoami)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    # 日志目录 - 确保权限正确
    sudo mkdir -p "$LOG_DIR"
    sudo chown ${USERNAME}:${USERNAME} "$LOG_DIR"
    sudo chmod 755 "$LOG_DIR"
    
    # 备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 运行时目录（可选）
    sudo mkdir -p /var/run/crypto-chart || true
    sudo chown ${USERNAME}:${USERNAME} /var/run/crypto-chart || true
    
    # 项目日志目录
    mkdir -p "$PROJECT_DIR/logs"
    
    log_success "目录创建完成"
}

# 设置脚本权限
setup_script_permissions() {
    log_info "设置脚本权限..."
    
    cd "$PROJECT_DIR"
    
    # 设置执行权限（检查文件是否存在）
    [ -f "update_crypto_chart.sh" ] && chmod +x update_crypto_chart.sh
    [ -f "monitor.sh" ] && chmod +x monitor.sh
    [ -f "deploy.sh" ] && chmod +x deploy.sh
    
    log_success "脚本权限设置完成"
}

# 配置日志轮转
setup_log_rotation() {
    log_info "配置日志轮转..."
    
    # 创建 logrotate 配置文件
    sudo tee /etc/logrotate.d/crypto-chart > /dev/null << EOF
# CryptoRate Pro 日志轮转配置

# 系统日志目录
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 ${USERNAME} ${USERNAME}
    postrotate
        sudo systemctl reload crypto-chart 2>/dev/null || true
    endscript
}

# 项目日志目录
$PROJECT_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 ${USERNAME} ${USERNAME}
    postrotate
        sudo systemctl reload crypto-chart 2>/dev/null || true
    endscript
}

# Gunicorn 日志特殊处理
$LOG_DIR/gunicorn.*.log $PROJECT_DIR/logs/gunicorn.*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 ${USERNAME} ${USERNAME}
    postrotate
        sudo systemctl restart crypto-chart 2>/dev/null || true
    endscript
}
EOF
    
    # 测试配置
    sudo logrotate -d /etc/logrotate.d/crypto-chart
    
    log_success "日志轮转配置完成"
}

# 设置定时任务
setup_cron_jobs() {
    log_info "设置定时任务..."
    
    # 备份当前的 crontab
    crontab -l > /tmp/current_crontab 2>/dev/null || touch /tmp/current_crontab
    
    # 检查是否已存在相关任务
    if grep -q "crypto-chart" /tmp/current_crontab; then
        log_warning "检测到现有的 crypto-chart 定时任务，跳过设置"
        rm /tmp/current_crontab
        return 0
    fi
    
    # 添加监控任务
    cat >> /tmp/current_crontab << EOF

# CryptoRate Pro 监控任务
*/5 * * * * [ -f $PROJECT_DIR/monitor.sh ] && $PROJECT_DIR/monitor.sh status >/dev/null 2>&1
0 * * * * [ -f $PROJECT_DIR/monitor.sh ] && $PROJECT_DIR/monitor.sh full >> $PROJECT_DIR/logs/cron-monitor.log 2>&1

# 日志清理 - 清理两个可能的日志目录
0 2 * * * find $LOG_DIR/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
0 2 * * * find $PROJECT_DIR/logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true

# 备份清理
0 0 1 * * find $BACKUP_DIR/ -type f -mtime +30 -delete 2>/dev/null || true
EOF
    
    # 应用新的 crontab
    crontab /tmp/current_crontab
    
    # 清理临时文件
    rm /tmp/current_crontab
    
    log_success "定时任务设置完成"
}

# 配置系统限制
setup_system_limits() {
    log_info "配置系统限制..."
    
    # 检查是否已经配置过
    if grep -q "CryptoRate Pro 资源限制" /etc/security/limits.conf; then
        log_warning "系统限制已配置，跳过"
        return 0
    fi
    
    # 为当前用户设置资源限制
    sudo tee -a /etc/security/limits.conf > /dev/null << EOF

# CryptoRate Pro 资源限制
${USERNAME} soft nproc 4096
${USERNAME} hard nproc 8192
${USERNAME} soft nofile 65536
${USERNAME} hard nofile 65536
EOF
    
    log_success "系统限制配置完成"
}

# 配置系统服务参数
optimize_system() {
    log_info "优化系统参数..."
    
    # 检查是否已经配置过
    if grep -q "CryptoRate Pro 网络优化" /etc/sysctl.conf; then
        log_warning "系统参数已优化，跳过"
        return 0
    fi
    
    # 网络参数优化
    sudo tee -a /etc/sysctl.conf > /dev/null << EOF

# CryptoRate Pro 网络优化
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 2000
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
EOF
    
    # 应用参数
    sudo sysctl -p
    
    log_success "系统优化完成"
}

# 创建快捷命令
create_shortcuts() {
    log_info "创建快捷命令..."
    
    # 创建符号链接到 /usr/local/bin（检查文件是否存在）
    [ -f "$PROJECT_DIR/update_crypto_chart.sh" ] && sudo ln -sf "$PROJECT_DIR/update_crypto_chart.sh" /usr/local/bin/crypto-update
    [ -f "$PROJECT_DIR/monitor.sh" ] && sudo ln -sf "$PROJECT_DIR/monitor.sh" /usr/local/bin/crypto-monitor
    
    # 创建别名脚本
    cat > /home/${USERNAME}/.crypto_aliases << EOF
# CryptoRate Pro 快捷命令
alias crypto-status='systemctl status crypto-chart'
alias crypto-logs='journalctl -u crypto-chart -f'
alias crypto-restart='sudo systemctl restart crypto-chart'
alias crypto-stop='sudo systemctl stop crypto-chart'
alias crypto-start='sudo systemctl start crypto-chart'
alias crypto-update='[ -f $PROJECT_DIR/update_crypto_chart.sh ] && $PROJECT_DIR/update_crypto_chart.sh || echo "update script not found"'
alias crypto-monitor='[ -f $PROJECT_DIR/monitor.sh ] && $PROJECT_DIR/monitor.sh || echo "monitor script not found"'
alias crypto-backup='[ -f $PROJECT_DIR/update_crypto_chart.sh ] && $PROJECT_DIR/update_crypto_chart.sh backup || echo "backup script not found"'
alias crypto-restore='[ -f $PROJECT_DIR/update_crypto_chart.sh ] && $PROJECT_DIR/update_crypto_chart.sh restore || echo "restore script not found"'
EOF
    
    # 添加到 .bashrc（如果尚未添加）
    if ! grep -q ".crypto_aliases" /home/${USERNAME}/.bashrc; then
        echo "[ -f ~/.crypto_aliases ] && source ~/.crypto_aliases" >> /home/${USERNAME}/.bashrc
    fi
    
    log_success "快捷命令创建完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    # 检查 ufw 是否已安装
    if ! command -v ufw &> /dev/null; then
        log_info "安装 ufw..."
        sudo apt-get update
        sudo apt-get install -y ufw
    fi
    
    # 检查防火墙是否已经配置
    if sudo ufw status | grep -q "5008"; then
        log_warning "防火墙规则已存在，跳过配置"
        return 0
    fi
    
    # 配置基本规则
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # 允许 SSH
    sudo ufw allow ssh
    
    # 允许应用端口
    sudo ufw allow 5008 comment 'CryptoRate Pro Direct Access'
    
    # 询问是否允许 HTTP/HTTPS
    read -p "是否允许 HTTP (80) 端口？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ufw allow 80 comment 'HTTP'
    fi
    
    read -p "是否允许 HTTPS (443) 端口？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo ufw allow 443 comment 'HTTPS'
    fi
    
    # 启用防火墙
    sudo ufw --force enable
    
    log_success "防火墙配置完成"
}

# 创建系统信息脚本
create_system_info() {
    log_info "创建系统信息脚本..."
    
    cat > "$PROJECT_DIR/system_info.sh" << 'EOF'
#!/bin/bash
echo "=== CryptoRate Pro 系统信息 ==="
echo "主机名: $(hostname)"
echo "IP地址: $(hostname -I | awk '{print $1}')"
echo "系统版本: $(lsb_release -d | cut -f2 2>/dev/null || echo "Unknown")"
echo "内核版本: $(uname -r)"
echo "运行时间: $(uptime -p)"
echo "CPU核心: $(nproc)"
echo "总内存: $(free -h | grep Mem | awk '{print $2}')"
echo "磁盘使用: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
echo ""
echo "=== 服务信息 ==="
echo "服务状态: $(systemctl is-active crypto-chart 2>/dev/null || echo "unknown")"
echo "服务启用: $(systemctl is-enabled crypto-chart 2>/dev/null || echo "unknown")"
echo "访问地址: http://$(hostname -I | awk '{print $1}'):5008"
echo ""
echo "=== 日志目录 ==="
echo "系统日志: /var/log/crypto-chart/"
echo "项目日志: ~/crypto-chart/logs/"
echo ""
echo "=== 快捷命令 ==="
echo "crypto-status    - 查看服务状态"
echo "crypto-logs      - 查看实时日志"  
echo "crypto-restart   - 重启服务"
echo "crypto-update    - 更新应用"
echo "crypto-monitor   - 系统监控"
echo "crypto-backup    - 创建备份"
EOF
    
    chmod +x "$PROJECT_DIR/system_info.sh"
    sudo ln -sf "$PROJECT_DIR/system_info.sh" /usr/local/bin/crypto-info
    
    log_success "系统信息脚本创建完成"
}

# 检查服务状态
check_service_status() {
    log_info "检查服务状态..."
    
    if systemctl is-active --quiet crypto-chart; then
        log_success "服务运行正常"
    else
        log_warning "服务未运行或有问题"
        echo "服务状态:"
        systemctl status crypto-chart --no-pager -l || true
    fi
}

# 显示配置总结
show_summary() {
    echo ""
    log_success "=== 系统配置完成 ==="
    echo ""
    echo "📁 目录结构:"
    echo "   项目目录: $PROJECT_DIR"
    echo "   系统日志: $LOG_DIR"
    echo "   项目日志: $PROJECT_DIR/logs"
    echo "   备份目录: $BACKUP_DIR"
    echo ""
    echo "⚙️ 配置完成:"
    echo "   ✅ 目录权限配置"
    echo "   ✅ 日志轮转配置"  
    echo "   ✅ 定时任务设置"
    echo "   ✅ 系统参数优化"
    echo "   ✅ 防火墙配置"
    echo "   ✅ 快捷命令创建"
    echo ""
    echo "🚀 可用命令:"
    echo "   crypto-info      - 查看系统信息"
    echo "   crypto-status    - 查看服务状态" 
    echo "   crypto-logs      - 查看实时日志"
    echo "   crypto-monitor   - 系统监控 (如果可用)"
    echo "   crypto-update    - 更新应用 (如果可用)"
    echo ""
    echo "📊 监控任务:"
    echo "   每5分钟检查服务状态 (如果 monitor.sh 存在)"
    echo "   每小时完整监控检查"
    echo "   每天清理旧日志文件"
    echo "   每月清理旧备份文件"
    echo ""
    echo "🔒 安全设置:"
    echo "   防火墙已配置并启用"
    echo "   系统资源限制已设置"
    echo "   日志自动轮转已配置"
    echo ""
    log_info "重新登录以启用快捷命令别名"
}

# 主函数
main() {
    log_info "=== CryptoRate Pro 系统配置脚本 (修复版) ==="
    
    # 检查权限
    if [ "$EUID" -eq 0 ]; then
        log_error "请不要以 root 用户运行此脚本"
        exit 1
    fi
    
    # 检查项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        log_info "请先运行部署脚本"
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    # 执行配置步骤
    create_directories
    setup_script_permissions
    setup_log_rotation
    setup_cron_jobs
    setup_system_limits
    optimize_system
    create_shortcuts
    setup_firewall
    create_system_info
    check_service_status
    
    # 显示配置总结
    show_summary
    
    log_success "系统配置脚本执行完成！"
}

# 运行主函数
main "$@"