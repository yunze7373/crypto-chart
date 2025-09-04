# 项目架构文档

## CryptoChart Pro v2.0 - 项目结构

本项目已按照现代软件工程的最佳实践重新组织，采用模块化、可维护的架构设计。

### 🏗️ 项目目录结构

```
crypto-chart/
├── src/                           # 📁 源代码目录
│   ├── __init__.py               # 包初始化文件
│   ├── app.py                    # 🚀 主应用程序入口
│   ├── config/                   # ⚙️ 配置模块
│   │   ├── __init__.py
│   │   └── settings.py           # 应用配置设置
│   ├── models/                   # 🗃️ 数据模型层
│   │   ├── __init__.py
│   │   └── alert.py              # Alert模型定义
│   ├── services/                 # 🔧 业务逻辑服务层
│   │   ├── __init__.py
│   │   ├── price_service.py      # 价格数据服务
│   │   ├── alert_service.py      # 提醒管理服务
│   │   ├── notification_service.py # 通知服务
│   │   └── monitor_service.py    # 监控服务
│   ├── api/                      # 🌐 API路由层
│   │   ├── __init__.py
│   │   ├── price_routes.py       # 价格相关API
│   │   └── alert_routes.py       # 提醒相关API
│   └── utils/                    # 🛠️ 工具模块
│       ├── __init__.py
│       ├── logging_config.py     # 日志配置
│       ├── validators.py         # 验证工具
│       └── formatters.py         # 格式化工具
├── docs/                         # 📚 文档目录
│   ├── ALERT_FEATURES.md        # 提醒功能说明
│   ├── DISCORD_SETUP.md         # Discord设置指南
│   ├── DEPLOYMENT.md            # 部署文档
│   ├── INSTALL.md               # 安装指南
│   └── screenshots/             # 截图目录
├── tests/                        # 🧪 测试目录
│   ├── test_app.py              # 应用测试
│   └── ...                      # 其他测试文件
├── deployment/                   # 🚀 部署配置
│   ├── deploy.sh                # 部署脚本
│   ├── gunicorn.conf.py         # Gunicorn配置
│   ├── nginx.conf               # Nginx配置
│   ├── setup_system.sh          # 系统设置脚本
│   ├── update_crypto_chart.sh   # 更新脚本
│   └── monitor.sh               # 监控脚本
├── static/                       # 🎨 静态资源
│   └── ...                      # CSS, JS, 图片等
├── templates/                    # 📄 HTML模板
│   └── index.html               # 主页模板
├── instance/                     # 💾 实例数据
│   └── crypto_alerts.db         # SQLite数据库
├── logs/                         # 📋 日志目录
│   └── crypto-chart.log         # 应用日志
├── .gitignore                   # Git忽略文件
├── requirements.txt             # Python依赖
├── README.md                    # 项目说明
└── crontab.txt                  # 定时任务配置
```

### 🏛️ 架构设计原则

#### 1. 分层架构 (Layered Architecture)
- **API层**: 处理HTTP请求和响应
- **服务层**: 业务逻辑处理
- **数据层**: 数据模型和数据库操作
- **工具层**: 通用工具和辅助功能

#### 2. 模块化设计 (Modular Design)
- 每个功能模块独立封装
- 明确的接口定义
- 低耦合，高内聚

#### 3. 配置管理 (Configuration Management)
- 环境相关配置分离
- 支持开发、测试、生产环境
- 敏感信息通过环境变量管理

#### 4. 错误处理 (Error Handling)
- 统一的错误处理机制
- 详细的日志记录
- 优雅的错误响应

### 📦 核心模块说明

#### Config 模块
- `settings.py`: 应用配置管理
  - 数据库配置
  - API配置
  - Discord配置
  - 环境特定配置

#### Models 模块
- `alert.py`: 价格提醒数据模型
  - 包含所有数据库字段定义
  - 业务逻辑方法
  - 数据验证

#### Services 模块
- `price_service.py`: 价格数据获取和处理
- `alert_service.py`: 提醒业务逻辑
- `notification_service.py`: Discord通知服务
- `monitor_service.py`: 后台监控服务

#### API 模块
- `price_routes.py`: 价格相关API端点
- `alert_routes.py`: 提醒相关API端点
- RESTful API设计
- 统一的响应格式

#### Utils 模块
- `logging_config.py`: 日志系统配置
- `validators.py`: 数据验证工具
- `formatters.py`: 数据格式化工具

### 🔄 数据流架构

```
用户请求 → API层 → 服务层 → 数据层 → 数据库
    ↓         ↓        ↓         ↓
  响应   ←  处理   ←  业务   ←  查询
```

### 🚀 新版本启动方式

#### 开发环境
```bash
cd src
python app.py
```

#### 生产环境
```bash
cd deployment
./deploy.sh
```

### 🔍 监控和日志

- **日志文件**: `logs/crypto-chart.log`
- **日志轮转**: 自动轮转，保留5个备份文件
- **监控接口**: `/health` 和 `/api/monitor/status`
- **错误追踪**: 详细的错误日志和堆栈跟踪

### 🧪 测试

- **单元测试**: `tests/` 目录下的测试文件
- **API测试**: 覆盖所有API端点
- **集成测试**: 端到端功能测试

### 📈 性能优化

- **数据库索引**: 关键字段建立索引
- **缓存机制**: 价格数据缓存
- **异步处理**: 后台监控服务
- **连接池**: 数据库连接优化

### 🔒 安全特性

- **输入验证**: 所有用户输入严格验证
- **SQL注入防护**: 使用ORM参数化查询
- **XSS防护**: 输出内容转义
- **敏感信息保护**: 环境变量管理

### 🛠️ 开发工具

- **代码规范**: PEP 8 Python代码规范
- **类型提示**: 使用类型注解提高代码质量
- **文档字符串**: 详细的函数和类文档
- **错误处理**: 完善的异常处理机制

### 📋 维护指南

#### 添加新功能
1. 在相应的服务模块中添加业务逻辑
2. 在API模块中添加路由
3. 更新数据模型（如需要）
4. 编写测试用例
5. 更新文档

#### 配置更新
1. 修改 `src/config/settings.py`
2. 更新环境变量
3. 重启应用

#### 数据库迁移
1. 修改模型定义
2. 生成迁移脚本
3. 执行数据库升级

这个新的架构提供了更好的可维护性、可扩展性和代码组织。每个模块都有明确的职责，便于团队协作和长期维护。
