# src/api/price_routes.py
"""
价格相关API路由
"""
from flask import Blueprint, jsonify, request
import logging
import time
from ..services import PriceService

logger = logging.getLogger(__name__)

# 创建蓝图
price_bp = Blueprint('price', __name__, url_prefix='/api')

# 创建服务实例
price_service = PriceService()


@price_bp.route('/current_prices', methods=['GET'])
def get_current_prices():
    """获取当前价格"""
    try:
        base = request.args.get('base', '').lower()
        quote = request.args.get('quote', '').lower()
        
        if not base or not quote:
            return jsonify({'error': '缺少必需的参数 base 和 quote'}), 400
        
        price = price_service.get_current_price(base, quote)
        
        if price is None:
            return jsonify({'error': f'无法获取 {base}/{quote} 的价格'}), 404
        
        return jsonify({
            'success': True,
            'data': {
                'base_currency': base.upper(),
                'quote_currency': quote.upper(),
                'price': price,
                'timestamp': str(int(time.time()))
            }
        })
        
    except Exception as e:
        logger.error(f"获取当前价格时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@price_bp.route('/data', methods=['GET'])
def get_historical_data():
    """获取历史数据"""
    try:
        base = request.args.get('base', '').lower()
        quote = request.args.get('quote', '').lower()
        timespan = request.args.get('timespan', '30d')
        
        if not base or not quote:
            return jsonify({'error': '缺少必需的参数 base 和 quote'}), 400
        
        # 解析时间跨度
        days = parse_timespan(timespan)
        if days is None:
            return jsonify({'error': '无效的时间跨度'}), 400
        
        data = price_service.get_historical_data(base, quote, days)
        
        if data is None:
            return jsonify({'error': f'无法获取 {base}/{quote} 的历史数据'}), 404
        
        # 计算统计信息
        stats = price_service.get_price_statistics(data['prices'])
        
        return jsonify({
            'success': True,
            'data': {
                'base_currency': base.upper(),
                'quote_currency': quote.upper(),
                'timespan': timespan,
                'dates': data['dates'],
                'prices': data['prices'],
                'statistics': stats
            }
        })
        
    except Exception as e:
        logger.error(f"获取历史数据时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@price_bp.route('/currencies', methods=['GET'])
def get_supported_currencies():
    """获取支持的货币列表"""
    try:
        currencies = price_service.get_supported_currencies()
        
        return jsonify({
            'success': True,
            'data': currencies
        })
        
    except Exception as e:
        logger.error(f"获取货币列表时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


@price_bp.route('/validate_pair', methods=['GET'])
def validate_currency_pair():
    """验证货币对"""
    try:
        base = request.args.get('base', '').lower()
        quote = request.args.get('quote', '').lower()
        
        if not base or not quote:
            return jsonify({'error': '缺少必需的参数 base 和 quote'}), 400
        
        is_valid = price_service.validate_currency_pair(base, quote)
        
        return jsonify({
            'success': True,
            'data': {
                'base_currency': base.upper(),
                'quote_currency': quote.upper(),
                'is_valid': is_valid
            }
        })
        
    except Exception as e:
        logger.error(f"验证货币对时发生错误: {e}")
        return jsonify({'error': '服务器内部错误'}), 500


def parse_timespan(timespan):
    """解析时间跨度字符串"""
    import re
    
    # 匹配格式如 "30d", "7d", "24h", "1y"
    match = re.match(r'^(\d+)([dhy])$', timespan.lower())
    if not match:
        return None
    
    number = int(match.group(1))
    unit = match.group(2)
    
    if unit == 'd':  # 天
        return number
    elif unit == 'h':  # 小时
        return max(1, number // 24)  # 转换为天，最少1天
    elif unit == 'y':  # 年
        return number * 365
    else:
        return None


# 错误处理
@price_bp.errorhandler(404)
def not_found(error):
    return jsonify({'error': '请求的资源不存在'}), 404


@price_bp.errorhandler(500)
def internal_error(error):
    return jsonify({'error': '服务器内部错误'}), 500
