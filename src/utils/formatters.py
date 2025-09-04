# src/utils/formatters.py
"""
格式化工具
"""
from datetime import datetime
from typing import Optional, Union


def format_price(price: Union[int, float], precision: int = 6, currency: str = None) -> str:
    """
    格式化价格显示
    
    Args:
        price: 价格值
        precision: 小数位数
        currency: 货币符号
        
    Returns:
        格式化后的价格字符串
    """
    if price is None:
        return "N/A"
    
    try:
        # 根据价格大小调整精度
        if price >= 1000:
            precision = 2
        elif price >= 1:
            precision = 4
        else:
            precision = 6
        
        formatted = f"{float(price):.{precision}f}"
        
        # 移除末尾的零
        if '.' in formatted:
            formatted = formatted.rstrip('0').rstrip('.')
        
        if currency:
            return f"{formatted} {currency.upper()}"
        else:
            return formatted
            
    except (ValueError, TypeError):
        return "N/A"


def format_currency_pair(base: str, quote: str, separator: str = "/") -> str:
    """
    格式化货币对显示
    
    Args:
        base: 基础货币
        quote: 计价货币
        separator: 分隔符
        
    Returns:
        格式化后的货币对字符串
    """
    if not base or not quote:
        return "N/A"
    
    return f"{base.upper()}{separator}{quote.upper()}"


def format_datetime(dt: Optional[datetime], format_str: str = "%Y-%m-%d %H:%M:%S") -> str:
    """
    格式化日期时间显示
    
    Args:
        dt: 日期时间对象
        format_str: 格式字符串
        
    Returns:
        格式化后的日期时间字符串
    """
    if dt is None:
        return "N/A"
    
    try:
        return dt.strftime(format_str)
    except (ValueError, TypeError):
        return "N/A"


def format_percentage(value: Union[int, float], precision: int = 2) -> str:
    """
    格式化百分比显示
    
    Args:
        value: 百分比值
        precision: 小数位数
        
    Returns:
        格式化后的百分比字符串
    """
    if value is None:
        return "N/A"
    
    try:
        sign = "+" if value > 0 else ""
        return f"{sign}{float(value):.{precision}f}%"
    except (ValueError, TypeError):
        return "N/A"


def format_duration(seconds: Union[int, float]) -> str:
    """
    格式化时间间隔显示
    
    Args:
        seconds: 秒数
        
    Returns:
        格式化后的时间间隔字符串
    """
    if seconds is None:
        return "N/A"
    
    try:
        seconds = int(seconds)
        
        if seconds < 60:
            return f"{seconds}秒"
        elif seconds < 3600:
            minutes = seconds // 60
            return f"{minutes}分钟"
        elif seconds < 86400:
            hours = seconds // 3600
            return f"{hours}小时"
        else:
            days = seconds // 86400
            return f"{days}天"
            
    except (ValueError, TypeError):
        return "N/A"


def format_file_size(size_bytes: Union[int, float]) -> str:
    """
    格式化文件大小显示
    
    Args:
        size_bytes: 字节数
        
    Returns:
        格式化后的文件大小字符串
    """
    if size_bytes is None:
        return "N/A"
    
    try:
        size = float(size_bytes)
        
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size < 1024.0:
                return f"{size:.1f} {unit}"
            size /= 1024.0
        
        return f"{size:.1f} PB"
        
    except (ValueError, TypeError):
        return "N/A"


def truncate_string(text: str, max_length: int = 50, suffix: str = "...") -> str:
    """
    截断字符串并添加后缀
    
    Args:
        text: 要截断的文本
        max_length: 最大长度
        suffix: 后缀
        
    Returns:
        截断后的字符串
    """
    if not text or not isinstance(text, str):
        return ""
    
    if len(text) <= max_length:
        return text
    
    return text[:max_length - len(suffix)] + suffix
