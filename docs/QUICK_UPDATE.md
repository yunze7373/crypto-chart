# 快速更新指南

## 🚀 CryptoChart Pro 更新到 v2.0

根据您的部署方式选择相应的更新方法：

### 📋 更新前检查

1. **确认当前版本**
   ```bash
   curl http://your-domain:5008/health
   ```

2. **备份重要数据**
   ```bash
   cp /opt/crypto-chart/instance/crypto_alerts.db ~/crypto_alerts_backup.db
   ```

---

## 🐧 Linux 传统部署更新

### 自动更新（推荐）
```bash
# 下载并运行自动更新脚本
cd /opt/crypto-chart
sudo chmod +x deployment/update.sh
sudo ./deployment/update.sh
```

### 手动更新
```bash
# 1. 停止服务
sudo systemctl stop crypto-chart

# 2. 备份数据
sudo cp -r /opt/crypto-chart /opt/crypto-chart-backup

# 3. 更新代码
cd /opt/crypto-chart
sudo git pull origin main

# 4. 更新依赖
sudo pip3 install -r requirements.txt --upgrade

# 5. 更新系统配置
sudo cp deployment/crypto-chart.service /etc/systemd/system/
sudo systemctl daemon-reload

# 6. 启动服务
sudo systemctl start crypto-chart

# 7. 验证
curl http://localhost:5008/health
```

---

## 🐳 Docker 部署更新

### 自动更新
```bash
chmod +x deployment/docker-update.sh
./deployment/docker-update.sh
```

### 手动更新
```bash
# 1. 拉取最新镜像
docker pull crypto-chart:latest

# 2. 停止旧容器
docker stop crypto-chart
docker rm crypto-chart

# 3. 启动新容器
docker run -d \
  --name crypto-chart \
  --restart unless-stopped \
  -p 5008:5008 \
  -v crypto-chart-data:/app/instance \
  crypto-chart:latest

# 4. 验证
curl http://localhost:5008/health
```

---

## 🪟 Windows 部署更新

### 自动更新
```cmd
# 以管理员身份运行
cd crypto-chart\deployment
update.bat
```

### 手动更新
```cmd
# 1. 停止应用进程
taskkill /f /im python.exe

# 2. 更新代码
cd crypto-chart
git pull origin main

# 3. 更新依赖
python -m pip install -r requirements.txt --upgrade

# 4. 启动应用
cd src
python app.py
```

---

## ☁️ 云平台部署更新

### Heroku
```bash
# 推送代码更新
git push heroku main
```

### AWS/Azure/GCP
参考各平台的部署文档进行更新

---

## 🔧 配置迁移

### v2.0 新增配置选项

在 `.env` 文件中添加：
```bash
# 新架构配置
FLASK_ENV=production
PYTHONPATH=/opt/crypto-chart/src

# 监控配置
PRICE_CHECK_INTERVAL=30
MAX_RETRIES=3

# 日志配置
LOG_LEVEL=INFO
```

### 系统服务配置更新

新的 systemd 服务文件：
```ini
[Unit]
Description=CryptoChart Pro v2.0
After=network.target

[Service]
Type=simple
User=crypto-chart
WorkingDirectory=/opt/crypto-chart/src
Environment=PYTHONPATH=/opt/crypto-chart/src
ExecStart=/usr/bin/python3 /opt/crypto-chart/src/app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## ✅ 更新验证清单

更新完成后，验证以下功能：

- [ ] 应用正常启动 `curl http://localhost:5008/health`
- [ ] 主页访问正常
- [ ] 价格查询功能正常
- [ ] 历史图表显示正常
- [ ] 价格提醒功能正常
- [ ] Discord 通知测试成功
- [ ] 原有提醒数据完整保留
- [ ] 新的监控服务运行正常

---

## 🆘 故障排除

### 常见问题

1. **模块导入错误**
   ```bash
   export PYTHONPATH=/opt/crypto-chart/src:$PYTHONPATH
   ```

2. **权限问题**
   ```bash
   sudo chown -R crypto-chart:crypto-chart /opt/crypto-chart
   ```

3. **端口占用**
   ```bash
   sudo lsof -i :5008
   sudo kill -9 <PID>
   ```

4. **数据库锁定**
   ```bash
   sudo service crypto-chart stop
   # 等待几秒
   sudo service crypto-chart start
   ```

### 回滚到旧版本

如果更新失败，可以快速回滚：
```bash
sudo systemctl stop crypto-chart
sudo mv /opt/crypto-chart /opt/crypto-chart-v2-failed
sudo mv /opt/crypto-chart-backup /opt/crypto-chart
sudo systemctl start crypto-chart
```

---

## 📞 获取帮助

- 📖 详细文档: [UPDATE_GUIDE.md](UPDATE_GUIDE.md)
- 🐛 问题报告: GitHub Issues
- 💬 社区支持: Discord 服务器

---

**⚡ 快速更新，享受 v2.0 新架构的强大功能！**
