# src/services/notification_service.py
"""
通知服务
"""
import requests
import logging
from typing import Optional, Dict, Any
from datetime import datetime
from ..config import get_config

logger = logging.getLogger(__name__)


class NotificationService:
    """通知服务类"""
    
    def __init__(self):
        self.config = get_config()
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'CryptoChart/1.0',
            'Content-Type': 'application/json'
        })
    
    def send_discord_notification(self, webhook_url: str, message: str, 
                                embed: Optional[Dict[str, Any]] = None) -> bool:
        """
        发送Discord通知
        
        Args:
            webhook_url: Discord Webhook URL
            message: 消息内容
            embed: 嵌入内容（可选）
            
        Returns:
            是否发送成功
        """
        try:
            payload = {'content': message}
            
            if embed:
                payload['embeds'] = [embed]
            
            response = self.session.post(
                webhook_url,
                json=payload,
                timeout=self.config.API_REQUEST_TIMEOUT
            )
            response.raise_for_status()
            
            logger.info(f"Discord通知发送成功: {message[:50]}...")
            return True
            
        except requests.RequestException as e:
            logger.error(f"发送Discord通知时网络错误: {e}")
            return False
        except Exception as e:
            logger.error(f"发送Discord通知时发生未知错误: {e}")
            return False
    
    def create_price_alert_embed(self, base_currency: str, quote_currency: str,
                               condition_type: str, target_price: float,
                               current_price: float, note: Optional[str] = None) -> Dict[str, Any]:
        """
        创建价格提醒的Discord嵌入消息
        
        Args:
            base_currency: 基础货币
            quote_currency: 计价货币
            condition_type: 条件类型
            target_price: 目标价格
            current_price: 当前价格
            note: 备注
            
        Returns:
            Discord嵌入字典
        """
        # 确定颜色
        color = 0x00ff00 if condition_type == 'above' else 0xff0000  # 绿色或红色
        
        # 确定条件描述
        condition_text = "高于" if condition_type == "above" else "低于"
        
        # 计算价格变化
        price_change = current_price - target_price
        price_change_percent = (price_change / target_price) * 100 if target_price != 0 else 0
        
        embed = {
            "title": "🚨 价格提醒触发",
            "description": f"**{base_currency.upper()}/{quote_currency.upper()}** 价格{condition_text}目标价格！",
            "color": color,
            "fields": [
                {
                    "name": "💰 当前价格",
                    "value": f"`{current_price:.6f} {quote_currency.upper()}`",
                    "inline": True
                },
                {
                    "name": "🎯 目标价格",
                    "value": f"`{target_price:.6f} {quote_currency.upper()}`",
                    "inline": True
                },
                {
                    "name": "📈 价格变化",
                    "value": f"`{price_change:+.6f} ({price_change_percent:+.2f}%)`",
                    "inline": True
                },
                {
                    "name": "📊 条件",
                    "value": f"`{condition_text} {target_price:.6f}`",
                    "inline": True
                },
                {
                    "name": "💱 货币对",
                    "value": f"`{base_currency.upper()}/{quote_currency.upper()}`",
                    "inline": True
                },
                {
                    "name": "⏰ 触发时间",
                    "value": f"`{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}`",
                    "inline": True
                }
            ],
            "footer": {
                "text": "CryptoChart Pro - 数字资产汇率监控",
                "icon_url": "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4b9.png"
            },
            "timestamp": datetime.now().isoformat()
        }
        
        # 添加备注字段
        if note:
            embed["fields"].append({
                "name": "📝 备注",
                "value": f"`{note}`",
                "inline": False
            })
        
        return embed
    
    def send_price_alert(self, webhook_url: str, base_currency: str, quote_currency: str,
                        condition_type: str, target_price: float, current_price: float,
                        note: Optional[str] = None) -> bool:
        """
        发送价格提醒通知
        
        Args:
            webhook_url: Discord Webhook URL
            base_currency: 基础货币
            quote_currency: 计价货币
            condition_type: 条件类型
            target_price: 目标价格
            current_price: 当前价格
            note: 备注
            
        Returns:
            是否发送成功
        """
        condition_text = "高于" if condition_type == "above" else "低于"
        message = f"💰 **价格提醒** 💰\\n{base_currency.upper()}/{quote_currency.upper()} 价格{condition_text}目标价格 {target_price:.6f}！\\n当前价格: {current_price:.6f}"
        
        embed = self.create_price_alert_embed(
            base_currency, quote_currency, condition_type,
            target_price, current_price, note
        )
        
        return self.send_discord_notification(webhook_url, message, embed)
    
    def send_test_notification(self, webhook_url: str) -> bool:
        """
        发送测试通知
        
        Args:
            webhook_url: Discord Webhook URL
            
        Returns:
            是否发送成功
        """
        message = "🧪 **测试通知** 🧪\\nCryptoChart Pro 通知系统工作正常！"
        
        embed = {
            "title": "✅ 测试通知",
            "description": "CryptoChart Pro 通知系统已成功连接！",
            "color": 0x00ff00,  # 绿色
            "fields": [
                {
                    "name": "📡 状态",
                    "value": "`正常`",
                    "inline": True
                },
                {
                    "name": "⏰ 测试时间",
                    "value": f"`{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}`",
                    "inline": True
                }
            ],
            "footer": {
                "text": "CryptoChart Pro - 数字资产汇率监控",
                "icon_url": "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4b9.png"
            },
            "timestamp": datetime.now().isoformat()
        }
        
        return self.send_discord_notification(webhook_url, message, embed)
    
    def validate_webhook_url(self, webhook_url: str) -> bool:
        """
        验证Discord Webhook URL
        
        Args:
            webhook_url: Discord Webhook URL
            
        Returns:
            是否有效
        """
        if not webhook_url:
            return False
        
        # 简单的URL格式验证
        if not webhook_url.startswith('https://discord.com/api/webhooks/'):
            return False
        
        # 尝试发送测试消息
        return self.send_test_notification(webhook_url)
    
    def close(self):
        """关闭会话"""
        self.session.close()
