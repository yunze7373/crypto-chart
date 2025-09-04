# src/models/__init__.py
"""
数据模型模块
"""
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

from .alert import Alert

__all__ = ['db', 'Alert']
