# GitHub 更新部署完整指南

## 🚀 将 v2.0 更新推送到 GitHub

### 第一步：准备推送更新

#### 1. 检查当前状态
```bash
# 检查Git状态
git status

# 查看当前分支
git branch

# 检查远程仓库
git remote -v
```

#### 2. 添加所有新文件和更改
```bash
# 添加所有新的架构文件
git add src/
git add docs/
git add deployment/
git add tests/

# 添加更新的文件
git add requirements.txt
git add README.md

# 检查要提交的文件
git status
```

#### 3. 提交更改
```bash
# 提交v2.0架构重构
git commit -m "feat: 重构到v2.0模块化架构

- 🏗️ 采用分层架构设计 (API/服务/数据/工具层)
- 📁 重新组织项目结构，代码模块化
- 🔧 升级技术栈 (Flask 3.0+, SQLAlchemy 2.0+)
- 📚 完善文档体系和部署指南
- 🚨 增强价格提醒功能
- 🛠️ 添加自动更新脚本
- ⚙️ 支持多环境配置
- 🧪 改进测试结构
- 📊 添加健康检查和监控API
- 🔄 向后兼容所有现有功能

BREAKING CHANGE: 启动路径从 app.py 变更为 src/app.py"
```

#### 4. 推送到GitHub
```bash
# 推送到主分支
git push origin main

# 如果需要强制推送（谨慎使用）
# git push --force-with-lease origin main
```

#### 5. 创建发布标签
```bash
# 创建v2.0标签
git tag -a v2.0.0 -m "CryptoChart Pro v2.0.0 - 模块化架构重构

主要更新:
- 全新模块化架构设计
- 分层代码组织结构  
- 增强的价格提醒系统
- 完整的更新部署工具
- 企业级配置管理
- 详细的文档体系"

# 推送标签
git push origin v2.0.0
```

---

## 📥 用户从GitHub获取更新

### 对于现有部署的用户

#### 方法一：使用自动更新脚本（推荐）

**Linux用户:**
```bash
cd /opt/crypto-chart
sudo git pull origin main
sudo chmod +x deployment/update.sh
sudo ./deployment/update.sh
```

**Windows用户:**
```cmd
cd C:\crypto-chart
git pull origin main
deployment\update.bat
```

**Docker用户:**
```bash
cd crypto-chart
git pull origin main
chmod +x deployment/docker-update.sh
./deployment/docker-update.sh
```

#### 方法二：手动更新流程

```bash
# 1. 备份现有部署
sudo cp -r /opt/crypto-chart /opt/crypto-chart-backup-$(date +%Y%m%d)

# 2. 停止服务
sudo systemctl stop crypto-chart

# 3. 更新代码
cd /opt/crypto-chart
sudo git stash  # 保存本地修改
sudo git pull origin main

# 4. 安装新依赖
sudo pip3 install -r requirements.txt --upgrade

# 5. 更新系统配置（重要！）
sudo cp deployment/crypto-chart.service /etc/systemd/system/
sudo systemctl daemon-reload

# 6. 启动服务
sudo systemctl start crypto-chart

# 7. 验证更新
curl http://localhost:5008/health
```

### 对于全新部署的用户

#### 标准部署
```bash
# 1. 克隆仓库
git clone https://github.com/yunze7373/crypto-chart.git
cd crypto-chart

# 2. 安装依赖
pip install -r requirements.txt

# 3. 直接运行（开发模式）
cd src
python app.py

# 4. 或使用部署脚本（生产模式）
sudo chmod +x deployment/setup_system.sh
sudo ./deployment/setup_system.sh
```

#### Docker部署
```bash
# 1. 克隆仓库
git clone https://github.com/yunze7373/crypto-chart.git
cd crypto-chart

# 2. 构建镜像
docker build -t crypto-chart:v2.0 .

# 3. 运行容器
docker run -d \
  --name crypto-chart \
  --restart unless-stopped \
  -p 5008:5008 \
  -v crypto-chart-data:/app/instance \
  -e DISCORD_WEBHOOK_URL=your_webhook_url \
  crypto-chart:v2.0
```

---

## 🔄 持续更新流程

### 为用户设置自动更新检查

#### 创建更新检查脚本
```bash
# 创建 /opt/crypto-chart/check-updates.sh
#!/bin/bash

CURRENT_DIR="/opt/crypto-chart"
cd "$CURRENT_DIR"

# 检查远程更新
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "🔔 检测到新版本可用！"
    echo "当前版本: $LOCAL"
    echo "最新版本: $REMOTE"
    echo ""
    echo "执行以下命令进行更新："
    echo "sudo ./deployment/update.sh"
    
    # 可选：发送通知到Discord
    if [ -n "$UPDATE_WEBHOOK_URL" ]; then
        curl -X POST -H "Content-Type: application/json" \
             -d '{"content":"🔔 CryptoChart Pro 有新版本可用！请及时更新。"}' \
             "$UPDATE_WEBHOOK_URL"
    fi
else
    echo "✅ 当前已是最新版本"
fi
```

#### 设置定时检查
```bash
# 添加到crontab（每天检查一次）
echo "0 9 * * * /opt/crypto-chart/check-updates.sh" | sudo crontab -
```

### GitHub Release 发布流程

#### 1. 创建Release Notes模板
创建 `.github/RELEASE_TEMPLATE.md`:
```markdown
## 🚀 CryptoChart Pro v{VERSION}

### ✨ 新功能
- 

### 🐛 Bug修复
- 

### 🔧 改进
- 

### ⬆️ 升级指南
对于现有用户：
```bash
cd /opt/crypto-chart
sudo ./deployment/update.sh
```

对于新用户：
```bash
git clone https://github.com/yunze7373/crypto-chart.git
cd crypto-chart/src
python app.py
```

### 🔗 相关链接
- [完整更新指南](docs/UPDATE_GUIDE.md)
- [快速更新手册](docs/QUICK_UPDATE.md)
- [架构文档](docs/ARCHITECTURE.md)
```

#### 2. 自动化Release工作流
创建 `.github/workflows/release.yml`:
```yaml
name: Create Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Create Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ github.ref }}
        release_name: CryptoChart Pro ${{ github.ref }}
        body_path: .github/RELEASE_TEMPLATE.md
        draft: false
        prerelease: false
```

---

## 📢 用户通知策略

### 1. 在应用中添加更新提醒

在 `src/app.py` 中添加更新检查：
```python
@app.route('/api/check-updates')
def check_updates():
    """检查是否有更新可用"""
    try:
        # 检查GitHub最新release
        response = requests.get('https://api.github.com/repos/yunze7373/crypto-chart/releases/latest')
        latest_release = response.json()
        latest_version = latest_release['tag_name']
        
        # 获取当前版本
        current_version = "v2.0.0"  # 从配置中获取
        
        return jsonify({
            'current_version': current_version,
            'latest_version': latest_version,
            'update_available': latest_version != current_version,
            'download_url': latest_release['html_url']
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
```

### 2. 前端更新提醒

在 `templates/index.html` 中添加：
```javascript
// 检查更新
async function checkForUpdates() {
    try {
        const response = await fetch('/api/check-updates');
        const data = await response.json();
        
        if (data.update_available) {
            showUpdateNotification(data.latest_version);
        }
    } catch (error) {
        console.error('检查更新失败:', error);
    }
}

function showUpdateNotification(version) {
    const notification = document.createElement('div');
    notification.className = 'update-notification';
    notification.innerHTML = `
        <div class="alert alert-info">
            🔔 检测到新版本 ${version} 可用！
            <a href="https://github.com/yunze7373/crypto-chart/releases/latest" target="_blank">
                查看更新
            </a>
        </div>
    `;
    document.body.prepend(notification);
}

// 页面加载时检查更新
document.addEventListener('DOMContentLoaded', checkForUpdates);
```

---

## 📋 更新最佳实践

### 对于项目维护者

1. **语义化版本控制**
   - 主版本号：破坏性更改
   - 次版本号：新功能添加
   - 修订号：Bug修复

2. **详细的Commit信息**
   ```bash
   # 使用约定式提交
   feat: 添加新功能
   fix: 修复bug
   docs: 更新文档
   style: 代码格式调整
   refactor: 代码重构
   test: 添加测试
   chore: 构建过程或辅助工具的变动
   ```

3. **Release Notes规范**
   - 突出重要变更
   - 提供升级指导
   - 包含破坏性变更说明

### 对于用户

1. **更新前备份**
   ```bash
   sudo cp -r /opt/crypto-chart /opt/crypto-chart-backup
   ```

2. **测试环境验证**
   ```bash
   # 先在测试环境更新
   git clone https://github.com/yunze7373/crypto-chart.git test-update
   cd test-update/src
   python app.py
   ```

3. **监控更新状态**
   ```bash
   # 更新后检查服务状态
   systemctl status crypto-chart
   curl http://localhost:5008/health
   ```

---

## 🎯 快速更新命令总结

### 推送更新到GitHub
```bash
git add .
git commit -m "feat: 重构到v2.0架构"
git push origin main
git tag v2.0.0
git push origin v2.0.0
```

### 用户获取更新
```bash
# Linux自动更新
cd /opt/crypto-chart && sudo git pull && sudo ./deployment/update.sh

# Windows自动更新  
cd crypto-chart && git pull && deployment\update.bat

# Docker更新
git pull && ./deployment/docker-update.sh
```

---

**🎉 现在您的GitHub仓库已经准备好为用户提供v2.0架构的完整更新体验！**
