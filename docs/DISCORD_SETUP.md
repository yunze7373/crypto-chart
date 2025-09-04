# Discord Webhook 设置指南

## 如何获取Discord Webhook URL

### 步骤1: 创建或选择Discord服务器
1. 打开Discord应用或网页版
2. 选择一个你有管理权限的服务器
3. 或者创建一个新的服务器用于接收提醒

### 步骤2: 创建Webhook
1. 在服务器中右键点击你想接收消息的频道
2. 选择"编辑频道"
3. 在左侧菜单中选择"整合"
4. 点击"Webhooks"部分
5. 点击"新建Webhook"

### 步骤3: 配置Webhook
1. 为Webhook起一个名字（如：CryptoRate Pro 提醒）
2. 选择要发送消息的频道
3. 可以选择上传一个头像图片
4. 点击"复制Webhook URL"

### 步骤4: 使用Webhook URL
1. 将复制的URL粘贴到CryptoRate Pro的"Discord Webhook URL"字段
2. 点击"测试Webhook"按钮验证连接
3. 如果看到测试消息出现在Discord频道中，说明设置成功

## Webhook URL格式示例
```
https://discord.com/api/webhooks/123456789/ABCDEFGHIJKLMNOP-qrstuvwxyz123456789
```

## 安全提示
- 不要与他人分享你的Webhook URL
- 如果URL泄露，可以在Discord中重新生成
- 建议为价格提醒创建专门的频道

## 故障排除

### 测试失败的可能原因：
1. **URL格式错误**: 确保URL以`https://discord.com/api/webhooks/`开头
2. **权限不足**: 确保你有该频道的管理权限
3. **Webhook被删除**: 检查Discord中的Webhook是否仍然存在
4. **网络问题**: 检查网络连接

### 如果遇到问题：
1. 重新创建Webhook
2. 检查频道权限设置
3. 尝试在其他频道创建Webhook
4. 联系服务器管理员

## 提醒消息格式
当价格达到目标时，你会收到包含以下信息的Discord消息：
- 货币对信息
- 触发条件
- 当前价格
- 触发时间
- 你设置的备注（如果有）
