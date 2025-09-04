# src/services/price_service.py
"""
价格数据服务
"""
import requests
import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
import logging
from ..config import get_config

logger = logging.getLogger(__name__)


class PriceService:
    """价格数据服务类"""
    
    def __init__(self):
        self.config = get_config()
        self.base_url = self.config.COINGECKO_API_URL
        self.timeout = self.config.API_REQUEST_TIMEOUT
        self.session = requests.Session()
        
        # 设置请求头
        self.session.headers.update({
            'User-Agent': 'CryptoChart/1.0',
            'Accept': 'application/json'
        })
    
    def get_current_price(self, base_currency: str, quote_currency: str) -> Optional[float]:
        """
        获取当前价格
        
        Args:
            base_currency: 基础货币
            quote_currency: 计价货币
            
        Returns:
            当前价格，失败时返回None
        """
        try:
            url = f"{self.base_url}/simple/price"
            params = {
                'ids': base_currency,
                'vs_currencies': quote_currency.lower()
            }
            
            response = self.session.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
            
            data = response.json()
            price = data.get(base_currency, {}).get(quote_currency.lower())
            
            if price is not None:
                logger.debug(f"获取到 {base_currency}/{quote_currency} 价格: {price}")
                return float(price)
            else:
                logger.warning(f"未找到 {base_currency}/{quote_currency} 的价格数据")
                return None
                
        except requests.RequestException as e:
            logger.error(f"获取价格时网络错误: {e}")
            return None
        except (ValueError, KeyError) as e:
            logger.error(f"解析价格数据时出错: {e}")
            return None
        except Exception as e:
            logger.error(f"获取价格时发生未知错误: {e}")
            return None
    
    def get_historical_data(self, base_currency: str, quote_currency: str, 
                          days: int = 30) -> Optional[Dict[str, Any]]:
        """
        获取历史价格数据
        
        Args:
            base_currency: 基础货币
            quote_currency: 计价货币
            days: 天数
            
        Returns:
            历史数据字典，包含时间和价格列表
        """
        try:
            url = f"{self.base_url}/coins/{base_currency}/market_chart"
            params = {
                'vs_currency': quote_currency.lower(),
                'days': days,
                'interval': 'daily' if days > 30 else 'hourly'
            }
            
            response = self.session.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
            
            data = response.json()
            prices = data.get('prices', [])
            
            if not prices:
                logger.warning(f"未找到 {base_currency}/{quote_currency} 的历史数据")
                return None
            
            # 转换为更易处理的格式
            timestamps = [price[0] for price in prices]
            values = [price[1] for price in prices]
            
            # 转换时间戳为日期字符串
            dates = [datetime.fromtimestamp(ts/1000).strftime('%Y-%m-%d %H:%M:%S') 
                    for ts in timestamps]
            
            result = {
                'dates': dates,
                'prices': values,
                'timestamps': timestamps
            }
            
            logger.debug(f"获取到 {base_currency}/{quote_currency} 历史数据，共 {len(prices)} 个数据点")
            return result
            
        except requests.RequestException as e:
            logger.error(f"获取历史数据时网络错误: {e}")
            return None
        except (ValueError, KeyError) as e:
            logger.error(f"解析历史数据时出错: {e}")
            return None
        except Exception as e:
            logger.error(f"获取历史数据时发生未知错误: {e}")
            return None
    
    def get_price_statistics(self, prices: List[float]) -> Dict[str, float]:
        """
        计算价格统计信息
        
        Args:
            prices: 价格列表
            
        Returns:
            统计信息字典
        """
        if not prices:
            return {}
        
        prices_array = np.array(prices)
        
        return {
            'current': prices[-1],
            'high_24h': np.max(prices),
            'low_24h': np.min(prices),
            'mean': np.mean(prices),
            'median': np.median(prices),
            'std': np.std(prices),
            'change_24h': prices[-1] - prices[0] if len(prices) > 1 else 0,
            'change_24h_percent': ((prices[-1] - prices[0]) / prices[0] * 100) if len(prices) > 1 and prices[0] != 0 else 0
        }
    
    def get_supported_currencies(self) -> List[Dict[str, str]]:
        """
        获取支持的货币列表
        
        Returns:
            货币列表，每个元素包含 id, symbol, name
        """
        try:
            url = f"{self.base_url}/coins/list"
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            
            data = response.json()
            
            # 过滤出我们支持的货币
            supported = []
            for coin in data:
                if coin['id'] in self.config.SUPPORTED_CURRENCIES:
                    supported.append({
                        'id': coin['id'],
                        'symbol': coin['symbol'].upper(),
                        'name': coin['name']
                    })
            
            logger.debug(f"获取到 {len(supported)} 个支持的货币")
            return supported
            
        except requests.RequestException as e:
            logger.error(f"获取货币列表时网络错误: {e}")
            return []
        except Exception as e:
            logger.error(f"获取货币列表时发生未知错误: {e}")
            return []
    
    def validate_currency_pair(self, base_currency: str, quote_currency: str) -> bool:
        """
        验证货币对是否有效
        
        Args:
            base_currency: 基础货币
            quote_currency: 计价货币
            
        Returns:
            是否有效
        """
        # 检查基础货币是否在支持列表中
        if base_currency not in self.config.SUPPORTED_CURRENCIES:
            return False
        
        # 尝试获取价格来验证
        price = self.get_current_price(base_currency, quote_currency)
        return price is not None
    
    def close(self):
        """关闭会话"""
        self.session.close()
