#!/bin/bash

# CryptoChart Pro Docker 更新脚本
# 适用于容器化部署的快速更新

set -e

# 配置
CONTAINER_NAME="crypto-chart"
IMAGE_NAME="crypto-chart:latest"
DATA_VOLUME="crypto-chart-data"
BACKUP_DIR="./backups"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查Docker是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        error "Docker 未运行或无权限访问"
    fi
}

# 备份数据
backup_data() {
    log "创建数据备份..."
    
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/crypto-chart-$(date +%Y%m%d_%H%M%S).tar"
    
    if docker volume ls | grep -q "$DATA_VOLUME"; then
        docker run --rm -v "$DATA_VOLUME":/data -v "$(pwd)/$BACKUP_DIR":/backup \
            alpine tar czf "/backup/crypto-chart-$(date +%Y%m%d_%H%M%S).tar.gz" -C /data .
        log "备份完成: $BACKUP_FILE.gz"
    else
        warning "数据卷不存在，跳过备份"
    fi
}

# 拉取最新镜像
pull_image() {
    log "拉取最新镜像..."
    docker pull "$IMAGE_NAME"
}

# 停止旧容器
stop_container() {
    log "停止旧容器..."
    if docker ps | grep -q "$CONTAINER_NAME"; then
        docker stop "$CONTAINER_NAME"
    fi
    
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker rm "$CONTAINER_NAME"
    fi
}

# 启动新容器
start_container() {
    log "启动新容器..."
    
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        -p 5008:5008 \
        -v "$DATA_VOLUME":/app/instance \
        -e FLASK_ENV=production \
        "$IMAGE_NAME"
}

# 验证更新
verify_update() {
    log "验证更新..."
    
    sleep 10
    
    if curl -f http://localhost:5008/health > /dev/null 2>&1; then
        log "✅ 更新成功！"
        log "应用地址: http://localhost:5008"
    else
        error "❌ 更新失败，请检查容器日志: docker logs $CONTAINER_NAME"
    fi
}

# 主函数
main() {
    log "开始 CryptoChart Pro Docker 更新..."
    
    check_docker
    backup_data
    pull_image
    stop_container
    start_container
    verify_update
    
    log "🎉 Docker 更新完成！"
}

# 显示帮助
show_help() {
    echo "CryptoChart Pro Docker 更新脚本"
    echo ""
    echo "用法: ./docker-update.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --help     显示帮助信息"
    echo "  --no-backup 跳过数据备份"
    echo ""
}

# 处理参数
case "${1:-}" in
    --help)
        show_help
        exit 0
        ;;
    --no-backup)
        log "跳过备份步骤"
        check_docker
        pull_image
        stop_container
        start_container
        verify_update
        ;;
    "")
        main
        ;;
    *)
        echo "未知选项: $1"
        show_help
        exit 1
        ;;
esac
