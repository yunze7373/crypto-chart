# src/api/alert_routes.py
"""
提醒相关API路由
"""
from flask import Blueprint, jsonify, request
import logging
from ..services import AlertService, NotificationService
from ..models import db

logger = logging.getLogger(__name__)

# 创建蓝图
alert_bp = Blueprint('alert', __name__, url_prefix='/api')

# 创建服务实例
alert_service = AlertService()
notification_service = NotificationService()


@alert_bp.route('/alerts', methods=['GET'])
def get_alerts():
    """获取提醒列表"""
    try:
        user_identifier = request.args.get('user_identifier')
        active_only = request.args.get('active_only', 'false').lower() == 'true'
        
        alerts = alert_service.get_alerts(user_identifier, active_only)
        
        return jsonify({
            'success': True,
            'data': [alert.to_dict() for alert in alerts]
        })
        
    except Exception as e:
        logger.error(f"获取提醒列表时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@alert_bp.route('/alerts', methods=['POST'])
def create_alert():
    """创建新提醒"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': '请求数据格式错误'}), 400
        
        # 验证必需字段
        required_fields = ['base_currency', 'quote_currency', 'condition_type', 
                          'target_price', 'discord_webhook_url']
        
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'缺少必需字段: {field}'}), 400
        
        # 创建提醒
        alert = alert_service.create_alert(
            base_currency=data['base_currency'],
            quote_currency=data['quote_currency'],
            condition_type=data['condition_type'],
            target_price=float(data['target_price']),
            discord_webhook_url=data['discord_webhook_url'],
            user_identifier=data.get('user_identifier'),
            note=data.get('note')
        )
        
        if alert:
            return jsonify({
                'success': True,
                'data': alert.to_dict()
            }), 201
        else:
            return jsonify({'error': '创建提醒失败'}), 400
        
    except ValueError as e:
        return jsonify({'error': f'数据格式错误: {str(e)}'}), 400
    except Exception as e:
        logger.error(f"创建提醒时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@alert_bp.route('/alerts/<int:alert_id>', methods=['DELETE'])
def delete_alert(alert_id):
    """删除提醒"""
    try:
        success = alert_service.delete_alert(alert_id)
        
        if success:
            return jsonify({
                'success': True,
                'message': '提醒删除成功'
            })
        else:
            return jsonify({'error': '提醒不存在或删除失败'}), 404
        
    except Exception as e:
        logger.error(f"删除提醒时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@alert_bp.route('/alerts/<int:alert_id>/toggle', methods=['POST'])
def toggle_alert(alert_id):
    """切换提醒状态"""
    try:
        alert = alert_service.toggle_alert(alert_id)
        
        if alert:
            return jsonify({
                'success': True,
                'data': alert.to_dict()
            })
        else:
            return jsonify({'error': '提醒不存在或操作失败'}), 404
        
    except Exception as e:
        logger.error(f"切换提醒状态时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@alert_bp.route('/alerts/statistics', methods=['GET'])
def get_alert_statistics():
    """获取提醒统计信息"""
    try:
        stats = alert_service.get_alert_statistics()
        
        return jsonify({
            'success': True,
            'data': stats
        })
        
    except Exception as e:
        logger.error(f"获取统计信息时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@alert_bp.route('/alerts/test-webhook', methods=['POST'])
def test_webhook():
    """测试Discord Webhook"""
    try:
        data = request.get_json()
        
        if not data or 'webhook_url' not in data:
            return jsonify({'error': '缺少webhook_url参数'}), 400
        
        webhook_url = data['webhook_url']
        success = notification_service.send_test_notification(webhook_url)
        
        if success:
            return jsonify({
                'success': True,
                'message': '测试通知发送成功'
            })
        else:
            return jsonify({'error': '测试通知发送失败，请检查Webhook URL'}), 400
        
    except Exception as e:
        logger.error(f"测试Webhook时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@alert_bp.route('/alerts/check', methods=['POST'])
def force_check_alerts():
    """强制检查所有提醒"""
    try:
        stats = alert_service.check_all_alerts()
        
        return jsonify({
            'success': True,
            'data': stats,
            'message': f'检查完成，共检查 {stats["checked"]} 个提醒，触发 {stats["triggered"]} 个'
        })
        
    except Exception as e:
        logger.error(f"强制检查提醒时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


# 错误处理
@alert_bp.errorhandler(404)
def not_found(error):
    return jsonify({'error': '请求的资源不存在'}), 404


@alert_bp.errorhandler(500)
def internal_error(error):
    return jsonify({'error': '服务器内部错误'}), 500
