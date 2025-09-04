# src/app.py
"""
CryptoChart Pro 主应用程序
重构版本，采用现代软件工程架构
"""
import os
import sys
from flask import Flask, render_template, jsonify
import logging

# 添加src目录到Python路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import get_config
from models import db, Alert
from services import MonitorService
from api import price_bp, alert_bp
from utils import setup_logging

# 全局变量
monitor_service = None


def create_app(config_name=None):
    """
    应用程序工厂函数
    
    Args:
        config_name: 配置名称
        
    Returns:
        Flask应用实例
    """
    app = Flask(__name__, 
                template_folder='../templates',
                static_folder='../static')
    
    # 加载配置
    config = get_config(config_name)
    app.config.from_object(config)
    
    # 设置日志
    log_level = logging.DEBUG if config.DEBUG else logging.INFO
    log_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'logs', 'crypto-chart.log')
    setup_logging(log_level, log_file)
    
    logger = logging.getLogger(__name__)
    logger.info(f"启动 CryptoChart Pro v2.0 - {config.__class__.__name__}")
    
    # 初始化扩展
    db.init_app(app)
    
    # 注册蓝图
    app.register_blueprint(price_bp)
    app.register_blueprint(alert_bp)
    
    # 创建数据库表
    with app.app_context():
        try:
            db.create_all()
            logger.info("数据库表创建成功")
        except Exception as e:
            logger.error(f"数据库初始化失败: {e}")
    
    # 注册路由
    register_routes(app)
    
    # 注册错误处理
    register_error_handlers(app)
    
    # 启动监控服务
    global monitor_service
    monitor_service = MonitorService()
    
    if not app.config.get('TESTING', False):
        if monitor_service.start():
            logger.info("价格监控服务已启动")
        else:
            logger.error("价格监控服务启动失败")
    
    return app


def register_routes(app):
    """注册主要路由"""
    
    @app.route('/')
    def index():
        """主页"""
        return render_template('index.html')
    
    @app.route('/health')
    def health_check():
        """健康检查"""
        global monitor_service
        
        try:
            # 检查数据库连接
            db.session.execute('SELECT 1')
            db_status = 'healthy'
        except Exception:
            db_status = 'unhealthy'
        
        # 检查监控服务状态
        monitor_status = monitor_service.get_status() if monitor_service else {'running': False}
        
        status = {
            'status': 'healthy' if db_status == 'healthy' and monitor_status['running'] else 'unhealthy',
            'database': db_status,
            'monitor_service': monitor_status,
            'version': '2.0.0'
        }
        
        return jsonify(status), 200 if status['status'] == 'healthy' else 503
    
    @app.route('/api/monitor/status')
    def monitor_status():
        """获取监控服务状态"""
        global monitor_service
        
        if monitor_service:
            return jsonify({
                'success': True,
                'data': monitor_service.get_status()
            })
        else:
            return jsonify({
                'success': False,
                'error': '监控服务未初始化'
            }), 500
    
    @app.route('/api/monitor/restart', methods=['POST'])
    def restart_monitor():
        """重启监控服务"""
        global monitor_service
        
        if monitor_service:
            if monitor_service.restart():
                return jsonify({
                    'success': True,
                    'message': '监控服务重启成功'
                })
            else:
                return jsonify({
                    'success': False,
                    'error': '监控服务重启失败'
                }), 500
        else:
            return jsonify({
                'success': False,
                'error': '监控服务未初始化'
            }), 500


def register_error_handlers(app):
    """注册错误处理器"""
    
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({'error': '页面不存在'}), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        db.session.rollback()
        return jsonify({'error': '服务器内部错误'}), 500
    
    @app.errorhandler(Exception)
    def handle_exception(e):
        logger = logging.getLogger(__name__)
        logger.error(f"未处理的异常: {e}", exc_info=True)
        
        if app.config['DEBUG']:
            raise e
        
        return jsonify({'error': '服务器内部错误'}), 500


def shutdown_handler():
    """应用关闭处理"""
    global monitor_service
    
    logger = logging.getLogger(__name__)
    
    if monitor_service:
        logger.info("正在停止监控服务...")
        monitor_service.stop()
        logger.info("监控服务已停止")


# 注册关闭处理器
import atexit
atexit.register(shutdown_handler)


if __name__ == '__main__':
    # 开发环境直接运行
    app = create_app('development')
    
    try:
        print("启动 CryptoRate Pro - 数字资产汇率监控平台...")
        print("价格提醒功能已启用")
        print(f"请在浏览器中访问: http://{app.config['HOST']}:{app.config['PORT']}/")
        
        app.run(
            host=app.config['HOST'],
            port=app.config['PORT'],
            debug=app.config['DEBUG']
        )
    except KeyboardInterrupt:
        print("\\n应用程序已停止")
    except Exception as e:
        logger = logging.getLogger(__name__)
        logger.error(f"应用程序启动失败: {e}")
        sys.exit(1)
