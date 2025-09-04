# models.py
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

class Alert(db.Model):
    """价格提醒模型"""
    __tablename__ = 'alerts'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # 货币对信息
    base_currency = db.Column(db.String(10), nullable=False)  # 基础货币，如 BTC
    quote_currency = db.Column(db.String(10), nullable=False)  # 计价货币，如 USD
    
    # 提醒条件
    condition_type = db.Column(db.String(20), nullable=False)  # 'above' 或 'below'
    target_price = db.Column(db.Float, nullable=False)  # 目标价格
    
    # Discord 通知设置
    discord_webhook_url = db.Column(db.Text, nullable=False)  # Discord Webhook URL
    
    # 提醒状态
    is_active = db.Column(db.Boolean, default=True)  # 是否激活
    is_triggered = db.Column(db.Boolean, default=False)  # 是否已触发
    
    # 创建和触发时间
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    triggered_at = db.Column(db.DateTime, nullable=True)
    
    # 用户信息（可选，用于未来扩展）
    user_identifier = db.Column(db.String(100), nullable=True)  # 用户标识符
    
    # 备注
    note = db.Column(db.Text, nullable=True)  # 用户备注
    
    def to_dict(self):
        """转换为字典格式"""
        return {
            'id': self.id,
            'base_currency': self.base_currency,
            'quote_currency': self.quote_currency,
            'condition_type': self.condition_type,
            'target_price': self.target_price,
            'discord_webhook_url': self.discord_webhook_url,
            'is_active': self.is_active,
            'is_triggered': self.is_triggered,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'triggered_at': self.triggered_at.isoformat() if self.triggered_at else None,
            'user_identifier': self.user_identifier,
            'note': self.note
        }
    
    def __repr__(self):
        return f'<Alert {self.base_currency}/{self.quote_currency} {self.condition_type} {self.target_price}>'
