#!/bin/bash

# CryptoRate Pro 系统监控脚本
# 用于监控应用状态和系统资源

set -euo pipefail

# 配置
readonly SERVICE_NAME="crypto-chart"
readonly PROJECT_DIR="/home/pi/crypto-chart"
readonly LOG_FILE="/var/log/crypto-chart/monitor.log"
readonly ALERT_EMAIL=""  # 设置告警邮箱地址
readonly HEALTH_CHECK_URL="http://localhost:5008/api/current_prices?base=BTC&quote=USDT"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

# 检查服务状态
check_service_status() {
    local status="UNKNOWN"
    local color="$NC"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        status="RUNNING"
        color="$GREEN"
    elif systemctl is-failed --quiet "$SERVICE_NAME"; then
        status="FAILED"
        color="$RED"
    elif systemctl is-enabled --quiet "$SERVICE_NAME"; then
        status="STOPPED"
        color="$YELLOW"
    else
        status="DISABLED"
        color="$RED"
    fi
    
    echo -e "服务状态: ${color}${status}${NC}"
    return $([ "$status" = "RUNNING" ] && echo 0 || echo 1)
}

# 检查端口监听
check_port_listening() {
    if ss -tulpn | grep -q ":5008 "; then
        echo -e "端口状态: ${GREEN}监听中${NC}"
        return 0
    else
        echo -e "端口状态: ${RED}未监听${NC}"
        return 1
    fi
}

# 健康检查
check_health() {
    if curl -s --max-time 10 "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo -e "健康检查: ${GREEN}通过${NC}"
        return 0
    else
        echo -e "健康检查: ${RED}失败${NC}"
        return 1
    fi
}

# 检查系统资源
check_system_resources() {
    echo "=== 系统资源 ==="
    
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    echo "CPU使用率: ${cpu_usage}%"
    
    # 内存使用情况
    local memory_info=$(free -h | grep "Mem:")
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local total_mem=$(echo $memory_info | awk '{print $2}')
    echo "内存使用: $used_mem / $total_mem"
    
    # 磁盘使用情况
    local disk_usage=$(df -h "$PROJECT_DIR" | tail -1 | awk '{print $5}')
    echo "磁盘使用: $disk_usage"
    
    # 负载平均值
    local load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo "负载平均值:$load_avg"
    
    echo ""
}

# 检查应用进程
check_processes() {
    echo "=== 应用进程 ==="
    
    local processes=$(ps aux | grep -E "(gunicorn|python.*app\.py)" | grep -v grep)
    
    if [ -n "$processes" ]; then
        echo "$processes"
        local process_count=$(echo "$processes" | wc -l)
        echo -e "\n进程数量: ${GREEN}$process_count${NC}"
    else
        echo -e "${RED}未发现应用进程${NC}"
    fi
    
    echo ""
}

# 检查日志错误
check_logs_for_errors() {
    echo "=== 最近日志错误 ==="
    
    local recent_errors=$(journalctl -u "$SERVICE_NAME" -p err --since "1 hour ago" --no-pager -q)
    
    if [ -n "$recent_errors" ]; then
        echo -e "${RED}发现错误日志:${NC}"
        echo "$recent_errors"
    else
        echo -e "${GREEN}最近1小时无错误日志${NC}"
    fi
    
    echo ""
}

# 检查磁盘空间
check_disk_space() {
    echo "=== 磁盘空间检查 ==="
    
    local disk_usage_percent=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$disk_usage_percent" -gt 90 ]; then
        echo -e "${RED}警告: 磁盘使用率过高 ($disk_usage_percent%)${NC}"
        return 1
    elif [ "$disk_usage_percent" -gt 80 ]; then
        echo -e "${YELLOW}注意: 磁盘使用率较高 ($disk_usage_percent%)${NC}"
        return 1
    else
        echo -e "${GREEN}磁盘空间正常 ($disk_usage_percent%)${NC}"
        return 0
    fi
}

# 网络连通性检查
check_network_connectivity() {
    echo "=== 网络连通性检查 ==="
    
    # 检查币安API
    if curl -s --max-time 10 "https://api.binance.com/api/v3/ping" > /dev/null; then
        echo -e "Binance API: ${GREEN}正常${NC}"
    else
        echo -e "Binance API: ${RED}连接失败${NC}"
    fi
    
    # 检查汇率API
    if curl -s --max-time 10 "https://api.exchangerate-api.com/v4/latest/USD" > /dev/null; then
        echo -e "汇率API: ${GREEN}正常${NC}"
    else
        echo -e "汇率API: ${RED}连接失败${NC}"
    fi
    
    echo ""
}

# 发送告警邮件
send_alert_email() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

# 尝试自动修复
auto_repair() {
    log_warning "尝试自动修复..."
    
    # 重启服务
    log_info "重启服务..."
    if sudo systemctl restart "$SERVICE_NAME"; then
        sleep 10
        if check_health; then
            log_success "自动修复成功"
            return 0
        fi
    fi
    
    log_error "自动修复失败"
    return 1
}

# 完整监控
full_monitor() {
    echo "=== CryptoRate Pro 系统监控 ==="
    echo "监控时间: $(date)"
    echo ""
    
    local issues=0
    
    # 检查服务状态
    if ! check_service_status; then
        ((issues++))
    fi
    
    # 检查端口
    if ! check_port_listening; then
        ((issues++))
    fi
    
    # 健康检查
    if ! check_health; then
        ((issues++))
    fi
    
    echo ""
    
    # 系统资源检查
    check_system_resources
    
    # 进程检查
    check_processes
    
    # 日志错误检查
    check_logs_for_errors
    
    # 磁盘空间检查
    if ! check_disk_space; then
        ((issues++))
    fi
    
    # 网络连通性检查
    check_network_connectivity
    
    # 总结
    echo "=== 监控总结 ==="
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}✅ 系统运行正常，无发现问题${NC}"
    else
        echo -e "${RED}⚠️ 发现 $issues 个问题${NC}"
        
        # 如果是严重问题，尝试自动修复
        if [ $issues -ge 2 ]; then
            if auto_repair; then
                send_alert_email "CryptoRate Pro - 自动修复成功" "系统检测到问题并已自动修复"
            else
                send_alert_email "CryptoRate Pro - 系统告警" "系统检测到严重问题，自动修复失败，需要人工介入"
            fi
        fi
    fi
    
    echo ""
}

# 简单状态检查
simple_status() {
    local all_ok=true
    
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "❌ 服务未运行"
        all_ok=false
    fi
    
    if ! ss -tulpn | grep -q ":5008 "; then
        echo "❌ 端口未监听"
        all_ok=false
    fi
    
    if ! curl -s --max-time 5 "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo "❌ 健康检查失败"
        all_ok=false
    fi
    
    if $all_ok; then
        echo "✅ 系统运行正常"
        exit 0
    else
        exit 1
    fi
}

# 主函数
main() {
    # 确保日志目录存在
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo chown pi:pi "$(dirname "$LOG_FILE")"
    
    case "${1:-full}" in
        "full")
            full_monitor
            ;;
        "status")
            simple_status
            ;;
        "service")
            check_service_status
            ;;
        "health")
            check_health
            ;;
        "resources")
            check_system_resources
            ;;
        "processes")
            check_processes
            ;;
        "logs")
            check_logs_for_errors
            ;;
        "repair")
            auto_repair
            ;;
        *)
            echo "用法: $0 {full|status|service|health|resources|processes|logs|repair}"
            echo ""
            echo "  full       - 完整监控检查（默认）"
            echo "  status     - 简单状态检查"
            echo "  service    - 检查服务状态"
            echo "  health     - 健康检查"
            echo "  resources  - 系统资源检查"
            echo "  processes  - 进程检查"
            echo "  logs       - 日志错误检查"
            echo "  repair     - 尝试自动修复"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
