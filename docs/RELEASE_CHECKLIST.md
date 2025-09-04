# GitHub 发布检查清单

## 📋 发布前检查清单

### 1. 代码质量检查
- [ ] 所有测试通过
- [ ] 代码审查完成
- [ ] 文档更新完成
- [ ] 版本号已更新

### 2. 兼容性检查
- [ ] 向后兼容性验证
- [ ] 数据库迁移脚本（如需要）
- [ ] 配置文件兼容性
- [ ] 依赖版本兼容性

### 3. 文档完整性
- [ ] README.md 更新
- [ ] CHANGELOG.md 更新
- [ ] API文档更新
- [ ] 部署指南更新

### 4. 发布准备
- [ ] Release Notes 准备
- [ ] 标签创建
- [ ] 备份脚本测试
- [ ] 更新脚本测试

## 🚀 发布执行步骤

1. **最终测试**
```bash
cd crypto-chart/src
python app.py
# 验证所有功能正常
```

2. **提交最终更改**
```bash
git add .
git commit -m "chore: 准备v2.0.0发布"
```

3. **创建并推送标签**
```bash
git tag -a v2.0.0 -m "CryptoChart Pro v2.0.0 - 模块化架构重构"
git push origin v2.0.0
```

4. **创建GitHub Release**
- 访问 GitHub 仓库
- 点击 "Releases" → "Create a new release"
- 选择 v2.0.0 标签
- 填写 Release Notes
- 发布

## 📢 发布后步骤

1. **通知用户**
- [ ] Discord 通知
- [ ] 邮件通知（如有）
- [ ] 文档网站更新

2. **监控部署**
- [ ] 检查用户反馈
- [ ] 监控错误报告
- [ ] 确认更新脚本有效性

3. **后续支持**
- [ ] 回答用户问题
- [ ] 修复紧急bug
- [ ] 收集改进建议
