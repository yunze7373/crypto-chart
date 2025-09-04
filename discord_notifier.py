# discord_notifier.py
import requests
import json
from datetime import datetime

class DiscordNotifier:
    """Discord通知器"""
    
    @staticmethod
    def send_alert(webhook_url, alert_data, current_price, current_ratio):
        """发送价格提醒到Discord"""
        try:
            # 构建Discord消息
            embed = {
                "title": "🚨 价格提醒触发",
                "description": f"您设置的 **{alert_data['base_currency']}/{alert_data['quote_currency']}** 价格提醒已触发！",
                "color": 0xff6b35 if alert_data['condition_type'] == 'above' else 0x4ecdc4,
                "fields": [
                    {
                        "name": "💱 货币对",
                        "value": f"{alert_data['base_currency']}/{alert_data['quote_currency']}",
                        "inline": True
                    },
                    {
                        "name": "🎯 触发条件",
                        "value": f"{'高于' if alert_data['condition_type'] == 'above' else '低于'} {alert_data['target_price']}",
                        "inline": True
                    },
                    {
                        "name": "📊 当前价格",
                        "value": f"{current_price:.6f}",
                        "inline": True
                    },
                    {
                        "name": "📈 当前比例",
                        "value": f"{current_ratio:.6f}",
                        "inline": True
                    },
                    {
                        "name": "⏰ 触发时间",
                        "value": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                        "inline": True
                    }
                ],
                "footer": {
                    "text": "CryptoRate Pro 价格监控系统"
                },
                "timestamp": datetime.now().isoformat()
            }
            
            # 添加备注字段（如果有）
            if alert_data.get('note'):
                embed["fields"].append({
                    "name": "📝 备注",
                    "value": alert_data['note'],
                    "inline": False
                })
            
            # 构建请求数据
            data = {
                "username": "CryptoRate Pro",
                "avatar_url": "https://cdn.discordapp.com/attachments/your-avatar-url.png",  # 可选：设置头像
                "embeds": [embed]
            }
            
            # 发送到Discord
            response = requests.post(
                webhook_url,
                headers={"Content-Type": "application/json"},
                data=json.dumps(data),
                timeout=10
            )
            
            if response.status_code == 204:
                print(f"Discord通知发送成功: {alert_data['base_currency']}/{alert_data['quote_currency']}")
                return True
            else:
                print(f"Discord通知发送失败: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"发送Discord通知时出错: {e}")
            return False
    
    @staticmethod
    def test_webhook(webhook_url):
        """测试Discord Webhook是否有效"""
        try:
            test_embed = {
                "title": "✅ Webhook 测试",
                "description": "您的 Discord Webhook 设置成功！",
                "color": 0x00ff00,
                "fields": [
                    {
                        "name": "🎉 测试结果",
                        "value": "连接正常，可以接收价格提醒",
                        "inline": False
                    }
                ],
                "footer": {
                    "text": "CryptoRate Pro 测试消息"
                },
                "timestamp": datetime.now().isoformat()
            }
            
            data = {
                "username": "CryptoRate Pro",
                "embeds": [test_embed]
            }
            
            response = requests.post(
                webhook_url,
                headers={"Content-Type": "application/json"},
                data=json.dumps(data),
                timeout=10
            )
            
            return response.status_code == 204
            
        except Exception as e:
            print(f"测试Discord Webhook时出错: {e}")
            return False
