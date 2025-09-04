#!/bin/bash

# CryptoRate Pro 监控脚本
# 用于监控服务状态、性能指标和健康检查

set -euo pipefail

readonly PROJECT_DIR="$HOME/crypto-chart"
readonly SERVICE_NAME="crypto-chart"
readonly LOG_DIR="/var/log/crypto-chart"
readonly PROJECT_LOG_DIR="$PROJECT_DIR/logs"

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

# 获取时间戳
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 检查服务状态
check_service_status() {
    local status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        status="运行中"
        return 0
    else
        status="已停止"
        return 1
    fi
}

# 检查端口监听
check_port_listening() {
    if netstat -tlnp 2>/dev/null | grep -q ":5008 "; then
        return 0
    else
        return 1
    fi
}

# HTTP健康检查
check_http_health() {
    local url="http://localhost:5008"
    if curl -s --max-time 10 "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 获取系统资源使用情况
get_system_resources() {
    local cpu_usage mem_usage disk_usage
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "N/A")
    
    # 内存使用率
    mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}' || echo "N/A")
    
    # 磁盘使用率
    disk_usage=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1 || echo "N/A")
    
    echo "CPU: ${cpu_usage}% | 内存: ${mem_usage}% | 磁盘: ${disk_usage}%"
}

# 获取进程信息
get_process_info() {
    local pid_info
    
    if pgrep -f "gunicorn.*crypto-chart" > /dev/null; then
        pid_info=$(pgrep -f "gunicorn.*crypto-chart" | head -1)
        if [ -n "$pid_info" ]; then
            echo "PID: $pid_info"
            # 获取内存使用
            local mem_kb=$(ps -o rss= -p "$pid_info" 2>/dev/null || echo "0")
            local mem_mb=$((mem_kb / 1024))
            echo "内存使用: ${mem_mb}MB"
        fi
    else
        echo "未找到 gunicorn 进程"
    fi
}

# 检查日志文件大小
check_log_sizes() {
    echo "日志文件大小:"
    
    # 检查系统日志目录
    if [ -d "$LOG_DIR" ]; then
        find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | while read -r logfile; do
            local size=$(du -h "$logfile" 2>/dev/null | cut -f1 || echo "0")
            echo "  $(basename "$logfile"): $size"
        done
    fi
    
    # 检查项目日志目录
    if [ -d "$PROJECT_LOG_DIR" ]; then
        find "$PROJECT_LOG_DIR" -name "*.log" -type f 2>/dev/null | while read -r logfile; do
            local size=$(du -h "$logfile" 2>/dev/null | cut -f1 || echo "0")
            echo "  $(basename "$logfile"): $size"
        done
    fi
}

# 快速状态检查
status_check() {
    echo "=== CryptoRate Pro 快速状态检查 ==="
    echo "时间: $(timestamp)"
    echo ""
    
    # 服务状态
    if check_service_status; then
        log_success "服务状态: 运行中"
    else
        log_error "服务状态: 已停止"
        return 1
    fi
    
    # 端口检查
    if check_port_listening; then
        log_success "端口 5008: 正常监听"
    else
        log_warning "端口 5008: 未监听"
    fi
    
    # HTTP检查
    if check_http_health; then
        log_success "HTTP健康检查: 通过"
    else
        log_warning "HTTP健康检查: 失败"
    fi
    
    echo ""
}

# 完整监控检查
full_check() {
    echo "=== CryptoRate Pro 完整监控报告 ==="
    echo "时间: $(timestamp)"
    echo ""
    
    # 基础状态
    status_check
    
    # 系统资源
    echo "系统资源使用:"
    get_system_resources
    echo ""
    
    # 进程信息
    echo "进程信息:"
    get_process_info
    echo ""
    
    # 日志大小
    check_log_sizes
    echo ""
    
    # 最近的错误日志
    echo "最近的错误日志:"
    if journalctl -u "$SERVICE_NAME" --since "1 hour ago" -p err -q --no-pager | head -5; then
        echo "  无最近错误"
    fi
    echo ""
    
    echo "=== 监控报告结束 ==="
}

# 自动修复服务
auto_fix() {
    log_info "开始自动修复..."
    
    if check_service_status; then
        log_info "服务正在运行，检查健康状态..."
        
        if ! check_http_health; then
            log_warning "HTTP检查失败，重启服务..."
            sudo systemctl restart "$SERVICE_NAME"
            sleep 10
            
            if check_http_health; then
                log_success "服务重启后恢复正常"
            else
                log_error "服务重启后仍然异常"
                return 1
            fi
        else
            log_success "服务运行正常，无需修复"
        fi
    else
        log_warning "服务已停止，尝试启动..."
        sudo systemctl start "$SERVICE_NAME"
        sleep 10
        
        if check_service_status && check_http_health; then
            log_success "服务启动成功"
        else
            log_error "服务启动失败"
            journalctl -u "$SERVICE_NAME" -n 10 --no-pager
            return 1
        fi
    fi
}

# 显示实时日志
show_logs() {
    echo "=== 实时日志监控 (按 Ctrl+C 退出) ==="
    journalctl -u "$SERVICE_NAME" -f
}

# 性能监控
performance_monitor() {
    echo "=== 性能监控 (每5秒更新，按 Ctrl+C 退出) ==="
    
    while true; do
        clear
        echo "CryptoRate Pro 性能监控 - $(timestamp)"
        echo "========================================"
        
        # 服务状态
        if check_service_status; then
            echo "服务状态: ✅ 运行中"
        else
            echo "服务状态: ❌ 已停止"
        fi
        
        # HTTP状态
        if check_http_health; then
            echo "HTTP状态: ✅ 正常"
        else
            echo "HTTP状态: ❌ 异常"
        fi
        
        echo ""
        echo "系统资源:"
        get_system_resources
        echo ""
        echo "进程信息:"
        get_process_info
        echo ""
        echo "按 Ctrl+C 退出监控..."
        
        sleep 5
    done
}

# 显示帮助信息
show_help() {
    echo "CryptoRate Pro 监控脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  status      快速状态检查"
    echo "  full        完整监控报告"
    echo "  fix         自动修复服务"
    echo "  logs        显示实时日志"
    echo "  perf        性能监控"
    echo "  help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 status   # 快速检查服务状态"
    echo "  $0 full     # 生成完整监控报告"
    echo "  $0 fix      # 自动修复服务问题"
}

# 主函数
main() {
    case "${1:-status}" in
        "status")
            status_check
            ;;
        "full")
            full_check
            ;;
        "fix")
            auto_fix
            ;;
        "logs")
            show_logs
            ;;
        "perf")
            performance_monitor
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"