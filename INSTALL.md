# CryptoRate Pro - 树莓派快速安装指南

## 🚀 一键部署（推荐）

```bash
# 下载并运行部署脚本
curl -o deploy.sh https://raw.githubusercontent.com/eizawa/crypto-chart/main/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

## 📋 手动部署步骤

### 1. 系统准备
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv git curl nginx
```

### 2. 克隆项目
```bash
cd /home/pi
git clone https://github.com/eizawa/crypto-chart.git
cd crypto-chart
```

### 3. Python环境设置
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 4. 安装服务
```bash
sudo cp crypto-chart.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable crypto-chart
sudo systemctl start crypto-chart
```

### 5. 配置Nginx（可选）
```bash
sudo cp nginx.conf /etc/nginx/sites-available/crypto-chart
sudo ln -s /etc/nginx/sites-available/crypto-chart /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
```

## 🔧 常用命令

### 服务管理
```bash
# 查看状态
sudo systemctl status crypto-chart

# 重启服务  
sudo systemctl restart crypto-chart

# 查看日志
journalctl -u crypto-chart -f

# 更新应用
./update_crypto_chart.sh
```

### 监控命令
```bash
# 完整监控检查
./monitor.sh

# 简单状态检查
./monitor.sh status

# 系统资源检查
./monitor.sh resources
```

## 🌐 访问地址

部署完成后访问：
- 直接访问: http://树莓派IP:5008
- Nginx代理: http://树莓派IP

## 📚 详细文档

参见 `DEPLOYMENT.md` 获取完整的部署和配置说明。
