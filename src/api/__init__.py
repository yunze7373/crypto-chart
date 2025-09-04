# src/api/__init__.py
"""
API路由模块
"""
from .price_routes import price_bp
from .alert_routes import alert_bp

__all__ = ['price_bp', 'alert_bp']
