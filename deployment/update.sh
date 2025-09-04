#!/bin/bash

# CryptoChart Pro 自动更新脚本 v2.0
# 用于将现有部署更新到新架构

set -e  # 遇到错误时退出

# 配置变量
APP_DIR="/opt/crypto-chart"
APP_USER="crypto-chart"
SERVICE_NAME="crypto-chart"
BACKUP_DIR="/opt/crypto-chart-backups"
LOG_FILE="/var/log/crypto-chart-update.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查权限
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要 root 权限运行。请使用 sudo ./update.sh"
    fi
}

# 创建备份
create_backup() {
    log "创建系统备份..."
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    CURRENT_BACKUP="$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    
    # 备份应用目录
    if [ -d "$APP_DIR" ]; then
        log "备份应用目录..."
        cp -r "$APP_DIR" "$CURRENT_BACKUP/crypto-chart"
        success "应用目录备份完成"
    fi
    
    # 备份系统配置
    log "备份系统配置..."
    mkdir -p "$CURRENT_BACKUP/system"
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        cp "/etc/systemd/system/$SERVICE_NAME.service" "$CURRENT_BACKUP/system/"
    fi
    
    if [ -f "/etc/nginx/sites-available/crypto-chart" ]; then
        cp "/etc/nginx/sites-available/crypto-chart" "$CURRENT_BACKUP/system/"
    fi
    
    success "备份创建完成: $CURRENT_BACKUP"
    echo "$CURRENT_BACKUP" > /tmp/crypto-chart-backup-path
}

# 停止服务
stop_services() {
    log "停止相关服务..."
    
    systemctl stop "$SERVICE_NAME" 2>/dev/null || warning "服务 $SERVICE_NAME 未运行"
    
    # 检查进程是否完全停止
    sleep 3
    if pgrep -f "crypto-chart" > /dev/null; then
        warning "强制终止残留进程..."
        pkill -f "crypto-chart" || true
    fi
    
    success "服务停止完成"
}

# 更新代码
update_code() {
    log "更新应用代码..."
    
    cd "$APP_DIR"
    
    # 检查是否为Git仓库
    if [ -d ".git" ]; then
        log "从Git仓库更新..."
        
        # 保存本地修改
        git stash push -m "Auto-stash before update $(date)"
        
        # 拉取最新代码
        git fetch origin
        git pull origin main
        
        success "代码更新完成"
    else
        error "未检测到Git仓库，请手动更新代码或重新部署"
    fi
}

# 更新依赖
update_dependencies() {
    log "更新Python依赖..."
    
    cd "$APP_DIR"
    
    # 升级pip
    pip3 install --upgrade pip
    
    # 安装/更新依赖
    pip3 install -r requirements.txt --upgrade
    
    success "依赖更新完成"
}

# 更新配置文件
update_configs() {
    log "更新配置文件..."
    
    # 更新systemd服务文件
    if [ -f "$APP_DIR/deployment/crypto-chart.service" ]; then
        log "更新systemd服务配置..."
        
        # 修改WorkingDirectory为新架构路径
        sed -i "s|WorkingDirectory=.*|WorkingDirectory=$APP_DIR/src|g" "$APP_DIR/deployment/crypto-chart.service"
        sed -i "s|ExecStart=.*|ExecStart=/usr/bin/python3 $APP_DIR/src/app.py|g" "$APP_DIR/deployment/crypto-chart.service"
        sed -i "s|Environment=PYTHONPATH=.*|Environment=PYTHONPATH=$APP_DIR/src|g" "$APP_DIR/deployment/crypto-chart.service"
        
        # 复制到系统目录
        cp "$APP_DIR/deployment/crypto-chart.service" "/etc/systemd/system/$SERVICE_NAME.service"
        
        # 重新加载systemd
        systemctl daemon-reload
        systemctl enable "$SERVICE_NAME"
        
        success "Systemd配置更新完成"
    fi
    
    # 检查Nginx配置
    if [ -f "/etc/nginx/sites-available/crypto-chart" ]; then
        log "Nginx配置无需更新"
    fi
}

# 数据库迁移
migrate_database() {
    log "检查数据库迁移..."
    
    # v2.0架构向后兼容，无需特殊迁移
    if [ -f "$APP_DIR/instance/crypto_alerts.db" ]; then
        # 确保数据库文件权限正确
        chown "$APP_USER:$APP_USER" "$APP_DIR/instance/crypto_alerts.db"
        success "数据库检查完成"
    else
        warning "未找到现有数据库，将创建新数据库"
    fi
}

# 更新文件权限
update_permissions() {
    log "更新文件权限..."
    
    # 更新所有文件所有权
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    
    # 确保执行权限
    chmod +x "$APP_DIR/src/app.py"
    
    # 确保日志目录存在
    mkdir -p "$APP_DIR/logs"
    chown "$APP_USER:$APP_USER" "$APP_DIR/logs"
    
    success "权限更新完成"
}

# 启动服务
start_services() {
    log "启动服务..."
    
    systemctl start "$SERVICE_NAME"
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "服务启动成功"
    else
        error "服务启动失败，请检查日志: journalctl -u $SERVICE_NAME"
    fi
}

# 验证更新
verify_update() {
    log "验证更新结果..."
    
    # 检查健康状态
    for i in {1..30}; do
        if curl -f http://localhost:5008/health > /dev/null 2>&1; then
            success "健康检查通过"
            break
        elif [ $i -eq 30 ]; then
            error "健康检查失败，服务可能未正常启动"
        else
            log "等待服务启动... ($i/30)"
            sleep 2
        fi
    done
    
    # 检查API功能
    if curl -f http://localhost:5008/api/monitor/status > /dev/null 2>&1; then
        success "API功能正常"
    else
        warning "API功能可能异常，请手动检查"
    fi
    
    # 显示版本信息
    log "当前版本信息:"
    curl -s http://localhost:5008/health | python3 -m json.tool 2>/dev/null || true
}

# 回滚函数
rollback() {
    error "更新失败，开始回滚..."
    
    BACKUP_PATH=$(cat /tmp/crypto-chart-backup-path 2>/dev/null)
    
    if [ -n "$BACKUP_PATH" ] && [ -d "$BACKUP_PATH" ]; then
        log "从备份恢复: $BACKUP_PATH"
        
        # 停止服务
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        
        # 恢复应用目录
        rm -rf "$APP_DIR"
        cp -r "$BACKUP_PATH/crypto-chart" "$APP_DIR"
        
        # 恢复系统配置
        if [ -f "$BACKUP_PATH/system/$SERVICE_NAME.service" ]; then
            cp "$BACKUP_PATH/system/$SERVICE_NAME.service" "/etc/systemd/system/"
            systemctl daemon-reload
        fi
        
        # 启动服务
        systemctl start "$SERVICE_NAME"
        
        success "回滚完成"
    else
        error "无法找到备份，请手动恢复"
    fi
}

# 清理函数
cleanup() {
    # 清理临时文件
    rm -f /tmp/crypto-chart-backup-path
    
    # 清理旧备份（保留最近7天）
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
}

# 主函数
main() {
    log "开始 CryptoChart Pro v2.0 更新流程..."
    
    # 设置错误处理
    trap rollback ERR
    
    check_permissions
    create_backup
    stop_services
    update_code
    update_dependencies
    update_configs
    migrate_database
    update_permissions
    start_services
    verify_update
    cleanup
    
    success "🎉 CryptoChart Pro 更新到 v2.0 架构完成！"
    log "应用地址: http://localhost:5008"
    log "健康检查: http://localhost:5008/health"
    log "日志位置: $LOG_FILE"
}

# 显示使用说明
show_usage() {
    echo "CryptoChart Pro v2.0 自动更新脚本"
    echo ""
    echo "用法: sudo $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --dry-run    仅显示将要执行的操作，不实际执行"
    echo "  --help       显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  sudo $0              # 执行完整更新"
    echo "  sudo $0 --dry-run    # 预览更新步骤"
}

# 处理命令行参数
case "${1:-}" in
    --help)
        show_usage
        exit 0
        ;;
    --dry-run)
        log "DRY RUN 模式 - 仅显示操作步骤，不实际执行"
        log "将执行以下步骤:"
        log "1. 创建系统备份"
        log "2. 停止服务"
        log "3. 更新代码"
        log "4. 更新依赖"
        log "5. 更新配置"
        log "6. 数据库迁移"
        log "7. 更新权限"
        log "8. 启动服务"
        log "9. 验证更新"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "未知选项: $1"
        show_usage
        exit 1
        ;;
esac
