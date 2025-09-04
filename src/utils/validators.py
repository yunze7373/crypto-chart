# src/utils/validators.py
"""
验证工具
"""
import re
from typing import Union


def validate_currency(currency: str) -> bool:
    """
    验证货币代码格式
    
    Args:
        currency: 货币代码
        
    Returns:
        是否有效
    """
    if not currency or not isinstance(currency, str):
        return False
    
    # 货币代码应该是2-10个字母或数字，可能包含短横线
    pattern = r'^[a-zA-Z0-9-]{2,10}$'
    return bool(re.match(pattern, currency))


def validate_price(price: Union[str, int, float]) -> bool:
    """
    验证价格格式
    
    Args:
        price: 价格值
        
    Returns:
        是否有效
    """
    try:
        price_float = float(price)
        return price_float > 0
    except (ValueError, TypeError):
        return False


def validate_webhook_url(url: str) -> bool:
    """
    验证Discord Webhook URL格式
    
    Args:
        url: Webhook URL
        
    Returns:
        是否有效
    """
    if not url or not isinstance(url, str):
        return False
    
    # Discord Webhook URL的基本格式验证
    pattern = r'^https://discord\.com/api/webhooks/\d+/[a-zA-Z0-9_-]+$'
    return bool(re.match(pattern, url))


def validate_condition_type(condition: str) -> bool:
    """
    验证条件类型
    
    Args:
        condition: 条件类型
        
    Returns:
        是否有效
    """
    return condition in ['above', 'below']


def validate_email(email: str) -> bool:
    """
    验证邮箱格式
    
    Args:
        email: 邮箱地址
        
    Returns:
        是否有效
    """
    if not email or not isinstance(email, str):
        return False
    
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_user_identifier(identifier: str) -> bool:
    """
    验证用户标识符格式
    
    Args:
        identifier: 用户标识符
        
    Returns:
        是否有效
    """
    if not identifier or not isinstance(identifier, str):
        return False
    
    # 用户标识符：3-50个字符，字母、数字、下划线、短横线
    pattern = r'^[a-zA-Z0-9_-]{3,50}$'
    return bool(re.match(pattern, identifier))


def sanitize_string(text: str, max_length: int = 1000) -> str:
    """
    清理字符串，移除危险字符
    
    Args:
        text: 要清理的文本
        max_length: 最大长度
        
    Returns:
        清理后的字符串
    """
    if not text or not isinstance(text, str):
        return ""
    
    # 移除控制字符和特殊字符
    cleaned = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', text)
    
    # 限制长度
    return cleaned[:max_length] if len(cleaned) > max_length else cleaned
