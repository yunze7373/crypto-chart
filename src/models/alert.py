# src/models/alert.py
"""
价格提醒数据模型
"""
from datetime import datetime
from typing import Dict, Any, Optional
from . import db


class Alert(db.Model):
    """价格提醒模型"""
    __tablename__ = 'alerts'
    
    # 主键
    id = db.Column(db.Integer, primary_key=True)
    
    # 货币对信息
    base_currency = db.Column(db.String(10), nullable=False, index=True)  # 基础货币，如 BTC
    quote_currency = db.Column(db.String(10), nullable=False, index=True)  # 计价货币，如 USD
    
    # 提醒条件
    condition_type = db.Column(db.String(20), nullable=False)  # 'above' 或 'below'
    target_price = db.Column(db.Float, nullable=False)  # 目标价格
    
    # Discord 通知设置
    discord_webhook_url = db.Column(db.Text, nullable=False)  # Discord Webhook URL
    
    # 提醒状态
    is_active = db.Column(db.Boolean, default=True, index=True)  # 是否激活
    is_triggered = db.Column(db.Boolean, default=False, index=True)  # 是否已触发
    
    # 时间戳
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    triggered_at = db.Column(db.DateTime, nullable=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 用户信息（可选，用于未来扩展）
    user_identifier = db.Column(db.String(100), nullable=True, index=True)  # 用户标识符
    
    # 备注和元数据
    note = db.Column(db.Text, nullable=True)  # 用户备注
    trigger_count = db.Column(db.Integer, default=0)  # 触发次数
    
    def to_dict(self) -> Dict[str, Any]:
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
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'user_identifier': self.user_identifier,
            'note': self.note,
            'trigger_count': self.trigger_count
        }
    
    def mark_as_triggered(self) -> None:
        """标记为已触发"""
        self.is_triggered = True
        self.triggered_at = datetime.utcnow()
        self.trigger_count += 1
        self.updated_at = datetime.utcnow()
    
    def activate(self) -> None:
        """激活提醒"""
        self.is_active = True
        self.updated_at = datetime.utcnow()
    
    def deactivate(self) -> None:
        """停用提醒"""
        self.is_active = False
        self.updated_at = datetime.utcnow()
    
    def reset(self) -> None:
        """重置提醒状态"""
        self.is_triggered = False
        self.triggered_at = None
        self.updated_at = datetime.utcnow()
    
    @property
    def currency_pair(self) -> str:
        """获取货币对字符串"""
        return f"{self.base_currency}/{self.quote_currency}"
    
    @classmethod
    def get_active_alerts(cls):
        """获取所有活跃的提醒"""
        return cls.query.filter_by(is_active=True, is_triggered=False).all()
    
    @classmethod
    def get_user_alerts(cls, user_identifier: str):
        """获取特定用户的提醒"""
        return cls.query.filter_by(user_identifier=user_identifier).all()
    
    def __repr__(self) -> str:
        return f'<Alert {self.currency_pair} {self.condition_type} {self.target_price}>'
