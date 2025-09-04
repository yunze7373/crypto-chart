# CryptoChart Pro 更新部署指南

## 🔄 从旧版本更新到 v2.0 架构

本指南帮助您将已部署的 CryptoChart Pro 从旧版本平滑升级到新的 v2.0 模块化架构。

### 📋 更新前准备

#### 1. 备份当前系统
```bash
# 备份应用目录
sudo cp -r /opt/crypto-chart /opt/crypto-chart-backup-$(date +%Y%m%d)

# 备份数据库
sudo cp /opt/crypto-chart/instance/crypto_alerts.db /opt/crypto-chart/instance/crypto_alerts.db.backup

# 备份配置文件
sudo cp /etc/systemd/system/crypto-chart.service /etc/systemd/system/crypto-chart.service.backup
sudo cp /etc/nginx/sites-available/crypto-chart /etc/nginx/sites-available/crypto-chart.backup
```

#### 2. 检查当前版本信息
```bash
cd /opt/crypto-chart
python3 --version
pip3 list | grep -E "(Flask|SQLAlchemy|requests)"
```

#### 3. 停止当前服务
```bash
# 停止应用服务
sudo systemctl stop crypto-chart

# 停止Nginx（可选，更新时保持运行）
# sudo systemctl stop nginx
```

### 🚀 升级步骤

#### 方法一：Git拉取更新（推荐）

```bash
# 1. 切换到应用目录
cd /opt/crypto-chart

# 2. 检查当前分支和状态
git status
git branch

# 3. 拉取最新代码
git fetch origin
git pull origin main

# 4. 检查是否有冲突
# 如果有冲突，请先解决冲突再继续

# 5. 更新Python依赖
sudo pip3 install -r requirements.txt --upgrade

# 6. 数据库迁移（v2.0会自动处理）
# 新架构兼容旧数据库结构，无需手动迁移
```

#### 方法二：全新部署（适用于大版本升级）

```bash
# 1. 下载最新代码到临时目录
cd /tmp
git clone https://github.com/yunze7373/crypto-chart.git crypto-chart-v2
cd crypto-chart-v2

# 2. 复制旧数据库到新版本
sudo cp /opt/crypto-chart/instance/crypto_alerts.db ./instance/

# 3. 复制重要配置（如环境变量文件）
sudo cp /opt/crypto-chart/.env ./ 2>/dev/null || true

# 4. 安装依赖
sudo pip3 install -r requirements.txt

# 5. 测试新版本
cd src
python3 app.py &
sleep 5
curl http://localhost:5008/health
kill %1

# 6. 如果测试成功，替换旧版本
sudo rm -rf /opt/crypto-chart-old 2>/dev/null || true
sudo mv /opt/crypto-chart /opt/crypto-chart-old
sudo mv /tmp/crypto-chart-v2 /opt/crypto-chart
sudo chown -R crypto-chart:crypto-chart /opt/crypto-chart
```

### ⚙️ 配置更新

#### 1. 更新Systemd服务文件

新架构的启动路径发生了变化，需要更新服务文件：

```bash
# 编辑服务文件
sudo nano /etc/systemd/system/crypto-chart.service
```

更新内容：
```ini
[Unit]
Description=CryptoChart Pro v2.0 - Digital Asset Rate Monitor
After=network.target

[Service]
Type=simple
User=crypto-chart
Group=crypto-chart
WorkingDirectory=/opt/crypto-chart/src
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/opt/crypto-chart/src
ExecStart=/usr/bin/python3 /opt/crypto-chart/src/app.py
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

#### 2. 重新加载Systemd配置
```bash
sudo systemctl daemon-reload
sudo systemctl enable crypto-chart
```

#### 3. 更新Nginx配置（如果需要）

检查并更新Nginx配置：
```bash
sudo nano /etc/nginx/sites-available/crypto-chart
```

确保配置正确：
```nginx
server {
    listen 80;
    server_name your-domain.com;  # 替换为您的域名

    location / {
        proxy_pass http://127.0.0.1:5008;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 健康检查端点
    location /health {
        proxy_pass http://127.0.0.1:5008/health;
        access_log off;
    }

    # 静态文件
    location /static {
        alias /opt/crypto-chart/static;
        expires 30d;
    }
}
```

#### 4. 环境变量配置

创建或更新环境变量文件：
```bash
sudo nano /opt/crypto-chart/.env
```

添加v2.0新配置：
```bash
# 应用配置
FLASK_ENV=production
SECRET_KEY=your-secret-key-here
HOST=127.0.0.1
PORT=5008

# 数据库配置
DATABASE_URL=sqlite:///instance/crypto_alerts.db

# Discord配置
DISCORD_WEBHOOK_URL=your-discord-webhook-url

# 监控配置
PRICE_CHECK_INTERVAL=30
MAX_RETRIES=3
```

### 🔧 启动新版本

#### 1. 启动应用服务
```bash
# 启动CryptoChart服务
sudo systemctl start crypto-chart

# 检查启动状态
sudo systemctl status crypto-chart

# 查看日志
sudo journalctl -u crypto-chart -f
```

#### 2. 验证服务正常
```bash
# 健康检查
curl http://localhost:5008/health

# API测试
curl http://localhost:5008/api/current_prices?base=bitcoin&quote=usd

# 检查监控服务状态
curl http://localhost:5008/api/monitor/status
```

#### 3. 重启Nginx（如果修改了配置）
```bash
sudo nginx -t  # 测试配置
sudo systemctl reload nginx
```

### 📊 验证更新成功

#### 1. 功能测试清单
- [ ] 主页正常访问
- [ ] 价格查询功能正常
- [ ] 历史图表显示正常
- [ ] 价格提醒功能正常
- [ ] Discord通知测试成功
- [ ] 旧的提醒数据完整保留

#### 2. 性能检查
```bash
# 检查进程
ps aux | grep python

# 检查端口
netstat -tlnp | grep 5008

# 检查内存使用
free -h

# 检查日志
tail -f /opt/crypto-chart/logs/crypto-chart.log
```

### 🛠️ 故障排除

#### 常见问题及解决方案

1. **导入模块错误**
```bash
# 检查Python路径
export PYTHONPATH=/opt/crypto-chart/src:$PYTHONPATH
cd /opt/crypto-chart/src && python3 app.py
```

2. **数据库访问错误**
```bash
# 检查数据库文件权限
sudo chown crypto-chart:crypto-chart /opt/crypto-chart/instance/crypto_alerts.db
```

3. **端口占用问题**
```bash
# 查找占用端口的进程
sudo lsof -i :5008
# 终止占用进程
sudo kill -9 <PID>
```

4. **权限问题**
```bash
# 确保用户权限正确
sudo chown -R crypto-chart:crypto-chart /opt/crypto-chart
sudo chmod +x /opt/crypto-chart/src/app.py
```

### 🔄 回滚方案

如果更新过程中遇到问题，可以快速回滚：

```bash
# 停止新版本服务
sudo systemctl stop crypto-chart

# 恢复旧版本
sudo mv /opt/crypto-chart /opt/crypto-chart-v2-failed
sudo mv /opt/crypto-chart-old /opt/crypto-chart

# 恢复旧的服务配置
sudo cp /etc/systemd/system/crypto-chart.service.backup /etc/systemd/system/crypto-chart.service
sudo systemctl daemon-reload

# 启动旧版本
sudo systemctl start crypto-chart
```

### 📋 更新后配置

#### 1. 设置定期备份
```bash
# 创建备份脚本
sudo nano /opt/crypto-chart/backup.sh

#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
cp /opt/crypto-chart/instance/crypto_alerts.db /opt/crypto-chart/backups/crypto_alerts_$DATE.db
find /opt/crypto-chart/backups -name "*.db" -mtime +7 -delete

# 设置定时任务
sudo crontab -e
0 2 * * * /opt/crypto-chart/backup.sh
```

#### 2. 监控设置
```bash
# 创建监控脚本
sudo nano /opt/crypto-chart/monitor.sh

#!/bin/bash
if ! curl -f http://localhost:5008/health > /dev/null 2>&1; then
    echo "CryptoChart service is down, restarting..."
    systemctl restart crypto-chart
fi

# 添加到定时任务
*/5 * * * * /opt/crypto-chart/monitor.sh
```

### 🎉 更新完成确认

更新完成后，您应该看到：

1. ✅ 应用正常运行在端口5008
2. ✅ 健康检查返回正常状态
3. ✅ 所有原有功能保持正常
4. ✅ 新的监控和日志功能生效
5. ✅ 性能和稳定性有所提升

---

## 🔗 相关文档

- [架构文档](ARCHITECTURE.md) - 了解v2.0新架构
- [部署指南](DEPLOYMENT.md) - 生产环境部署
- [故障排除](TROUBLESHOOTING.md) - 常见问题解决

---

**🎯 如有问题，请及时查看日志文件或联系技术支持**
