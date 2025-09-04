# CryptoRate Pro - 树莓派部署文档

## 概述

CryptoRate Pro 是一个专业的数字资产与法币汇率监控平台，支持加密货币和法币的实时汇率查询与历史图表展示。

## 系统要求

- **操作系统**: Raspberry Pi OS, Debian 11+, Ubuntu 20.04+
- **Python**: 3.7+
- **内存**: 最小 512MB，推荐 1GB+
- **存储**: 最小 2GB 可用空间
- **网络**: 互联网连接（用于获取汇率数据）

## 快速部署

### 方法一：一键部署脚本

1. 下载部署脚本：
```bash
curl -o deploy.sh https://raw.githubusercontent.com/eizawa/crypto-chart/main/deploy.sh
chmod +x deploy.sh
```

2. 运行部署脚本：
```bash
./deploy.sh
```

### 方法二：手动部署

1. **克隆项目**
```bash
cd /home/pi
git clone https://github.com/eizawa/crypto-chart.git
cd crypto-chart
```

2. **安装系统依赖**
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv git curl nginx
```

3. **创建Python虚拟环境**
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

4. **安装systemd服务**
```bash
sudo cp crypto-chart.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable crypto-chart
sudo systemctl start crypto-chart
```

5. **配置Nginx（可选）**
```bash
sudo cp nginx.conf /etc/nginx/sites-available/crypto-chart
sudo ln -s /etc/nginx/sites-available/crypto-chart /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

## 服务管理

### 基本命令

```bash
# 查看服务状态
sudo systemctl status crypto-chart

# 启动服务
sudo systemctl start crypto-chart

# 停止服务
sudo systemctl stop crypto-chart

# 重启服务
sudo systemctl restart crypto-chart

# 查看日志
journalctl -u crypto-chart -f

# 查看最近50条日志
journalctl -u crypto-chart -n 50
```

### 更新脚本

项目提供了完整的更新脚本 `update_crypto_chart.sh`，支持：

```bash
# 完整更新（默认）
./update_crypto_chart.sh

# 查看服务状态
./update_crypto_chart.sh status

# 查看日志
./update_crypto_chart.sh logs

# 创建备份
./update_crypto_chart.sh backup

# 恢复备份
./update_crypto_chart.sh restore

# 重启服务
./update_crypto_chart.sh restart
```

## 访问地址

部署完成后可通过以下地址访问：

- **直接访问**: http://树莓派IP:5008
- **Nginx代理**: http://树莓派IP (如果配置了Nginx)
- **本地访问**: http://localhost:5008

## 功能特性

### 支持的货币对

**法币 (12种)**:
- USD, CNY, EUR, JPY, GBP, KRW
- CAD, AUD, CHF, HKD, SGD, INR

**加密货币 (主流币种)**:
- Bitcoin (BTC), Ethereum (ETH), Binance Coin (BNB)
- Solana (SOL), Cardano (ADA), Polygon (POL)
- Arbitrum (ARB), Optimism (OP), Avalanche (AVAX)
- 等30+种主流加密货币

### 主要功能

1. **实时汇率查询**
   - 支持加密货币对法币
   - 支持法币对法币
   - 支持加密货币对加密货币

2. **历史图表展示**
   - 1天、7天、30天、90天、1年、全部时间跨度
   - 可视化价格趋势图表
   - 时间范围滑块功能

3. **智能输入系统**
   - 自动货币符号识别
   - 下拉选择和手动输入
   - 一键货币对反转

## 技术架构

### 后端技术栈

- **Web框架**: Flask 2.3.3
- **HTTP请求**: requests 2.31.0
- **数据处理**: pandas 2.0.3
- **WSGI服务器**: gunicorn 21.2.0

### 前端技术栈

- **图表库**: Chart.js
- **样式**: 原生CSS3 (响应式设计)
- **交互**: 原生JavaScript (ES6+)

### 数据源

- **加密货币数据**: Binance API
- **法币汇率数据**: ExchangeRate API
- **历史数据**: Binance Klines API

## 配置说明

### 环境变量

可以通过环境变量自定义配置：

```bash
# Flask配置
export FLASK_ENV=production
export FLASK_DEBUG=0

# 服务端口（默认5008）
export PORT=5008

# Python环境
export PYTHONUNBUFFERED=1
```

### Gunicorn配置

默认Gunicorn配置：
- 绑定地址: 0.0.0.0:5008
- Worker数量: 2
- 超时时间: 120秒
- Worker类型: sync

可以创建 `gunicorn.conf.py` 自定义配置。

### Nginx配置

如果使用Nginx，默认配置包括：
- 反向代理到本地5008端口
- 静态文件缓存
- 健康检查端点
- 适当的超时设置

## 监控和日志

### 系统监控

```bash
# 查看系统资源使用
htop

# 查看网络连接
ss -tulpn | grep 5008

# 查看磁盘使用
df -h

# 查看内存使用
free -h
```

### 应用监控

```bash
# 实时查看应用日志
journalctl -u crypto-chart -f

# 查看错误日志
journalctl -u crypto-chart -p err

# 查看应用进程
ps aux | grep gunicorn
```

### 健康检查

应用提供健康检查端点：
```bash
curl http://localhost:5008/api/current_prices?base=BTC&quote=USDT
```

## 故障排除

### 常见问题

1. **服务无法启动**
   ```bash
   # 检查服务状态
   systemctl status crypto-chart
   
   # 查看详细日志
   journalctl -u crypto-chart -n 50
   
   # 检查Python环境
   /home/pi/crypto-chart/venv/bin/python --version
   ```

2. **端口被占用**
   ```bash
   # 查找占用端口的进程
   lsof -i :5008
   
   # 或使用ss命令
   ss -tulpn | grep 5008
   ```

3. **API请求失败**
   ```bash
   # 测试网络连接
   curl -I https://api.binance.com/api/v3/ping
   curl -I https://api.exchangerate-api.com/v4/latest/USD
   ```

4. **权限问题**
   ```bash
   # 确保文件权限正确
   sudo chown -R pi:pi /home/pi/crypto-chart
   chmod +x /home/pi/crypto-chart/update_crypto_chart.sh
   ```

### 性能优化

1. **增加Worker数量**（适用于多核树莓派）
   编辑 systemd 服务文件，增加 worker 数量：
   ```
   --workers 4
   ```

2. **启用Nginx缓存**
   在Nginx配置中添加缓存设置

3. **优化Python内存使用**
   可以在服务文件中限制内存使用：
   ```
   MemoryMax=512M
   ```

## 安全考虑

### 基本安全设置

1. **防火墙配置**
   ```bash
   # 安装ufw
   sudo apt-get install ufw
   
   # 允许SSH
   sudo ufw allow ssh
   
   # 允许HTTP
   sudo ufw allow 80
   
   # 允许应用端口（如果直接访问）
   sudo ufw allow 5008
   
   # 启用防火墙
   sudo ufw enable
   ```

2. **SSL证书**（推荐用于生产环境）
   ```bash
   # 使用Let's Encrypt
   sudo apt-get install certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

### 系统加固

1. 定期更新系统
2. 使用强密码和SSH密钥认证
3. 禁用不必要的服务
4. 定期备份数据

## 备份和恢复

### 自动备份

更新脚本会自动创建备份：
- 备份位置: `/home/pi/backup/crypto-chart/`
- 包含: 项目文件、配置文件、服务文件

### 手动备份

```bash
# 创建完整备份
./update_crypto_chart.sh backup

# 备份到外部存储
rsync -av /home/pi/crypto-chart/ /media/usb/crypto-chart-backup/
```

### 恢复操作

```bash
# 从自动备份恢复
./update_crypto_chart.sh restore

# 从外部备份恢复
rsync -av /media/usb/crypto-chart-backup/ /home/pi/crypto-chart/
```

## 联系支持

如遇到问题，请：
1. 查看本文档的故障排除部分
2. 检查GitHub Issues页面
3. 查看应用日志文件

---

**注意**: 本应用仅供学习和参考使用，不构成投资建议。请在使用前仔细测试，并根据实际需求进行适当的安全配置。
