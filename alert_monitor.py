# alert_monitor.py
import time
import threading
from datetime import datetime, timezone
from models import db, Alert
from discord_notifier import DiscordNotifier
import requests

class AlertMonitor:
    """价格提醒监控器"""
    
    def __init__(self, app):
        self.app = app
        self.running = False
        self.thread = None
        
    def start(self):
        """启动监控服务"""
        if not self.running:
            self.running = True
            self.thread = threading.Thread(target=self._monitor_loop, daemon=True)
            self.thread.start()
            print("价格监控服务已启动")
    
    def stop(self):
        """停止监控服务"""
        self.running = False
        if self.thread:
            self.thread.join()
        print("价格监控服务已停止")
    
    def _monitor_loop(self):
        """监控循环"""
        while self.running:
            try:
                with self.app.app_context():
                    self._check_alerts()
                time.sleep(30)  # 每30秒检查一次
            except Exception as e:
                print(f"监控循环中出错: {e}")
                time.sleep(60)  # 出错时等待1分钟再继续
    
    def _check_alerts(self):
        """检查所有活跃的提醒"""
        # 获取所有活跃且未触发的提醒
        active_alerts = Alert.query.filter_by(is_active=True, is_triggered=False).all()
        
        for alert in active_alerts:
            try:
                # 获取当前价格
                current_data = self._get_current_price(alert.base_currency, alert.quote_currency)
                
                if current_data is None:
                    print(f"无法获取 {alert.base_currency}/{alert.quote_currency} 的当前价格")
                    continue
                
                current_ratio = current_data['ratio']
                
                # 检查是否触发条件
                should_trigger = False
                if alert.condition_type == 'above' and current_ratio >= alert.target_price:
                    should_trigger = True
                elif alert.condition_type == 'below' and current_ratio <= alert.target_price:
                    should_trigger = True
                
                if should_trigger:
                    # 发送Discord通知
                    alert_data = alert.to_dict()
                    success = DiscordNotifier.send_alert(
                        alert.discord_webhook_url,
                        alert_data,
                        current_data['base_price'],
                        current_ratio
                    )
                    
                    if success:
                        # 标记为已触发
                        alert.is_triggered = True
                        alert.triggered_at = datetime.now(timezone.utc)
                        db.session.commit()
                        print(f"提醒已触发并通知: {alert.base_currency}/{alert.quote_currency} {alert.condition_type} {alert.target_price}")
                    else:
                        print(f"Discord通知发送失败: {alert.base_currency}/{alert.quote_currency}")
                        
            except Exception as e:
                print(f"检查提醒 {alert.id} 时出错: {e}")
    
    def _get_current_price(self, base_currency, quote_currency):
        """获取当前价格数据"""
        try:
            # 检查是否为法币
            fiat_currencies = {'USD', 'CNY', 'EUR', 'JPY', 'GBP', 'KRW', 'CAD', 'AUD', 'CHF', 'HKD', 'SGD', 'INR'}
            base_is_fiat = base_currency.upper() in fiat_currencies
            quote_is_fiat = quote_currency.upper() in fiat_currencies
            
            if base_is_fiat and quote_is_fiat:
                # 法币对法币
                if base_currency == quote_currency:
                    return None
                
                rate = self._get_fiat_exchange_rate(base_currency, quote_currency)
                if rate is not None:
                    return {
                        "base_price": 1.0,
                        "quote_price": 1.0/rate,
                        "ratio": rate
                    }
                return None
                
            elif base_is_fiat and not quote_is_fiat:
                # 法币对加密货币
                rate = self._get_crypto_to_fiat_rate(quote_currency, base_currency)
                if rate is not None:
                    return {
                        "base_price": 1.0,
                        "quote_price": rate,
                        "ratio": 1.0 / rate
                    }
                return None
                
            elif not base_is_fiat and quote_is_fiat:
                # 加密货币对法币
                rate = self._get_crypto_to_fiat_rate(base_currency, quote_currency)
                if rate is not None:
                    return {
                        "base_price": rate,
                        "quote_price": 1.0,
                        "ratio": rate
                    }
                return None
            
            else:
                # 加密货币对加密货币
                if base_currency == 'USDT' and quote_currency == 'USDT':
                    return None
                
                if base_currency == 'USDT':
                    quote_symbol = f"{quote_currency}USDT"
                    quote_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={quote_symbol}")
                    
                    if quote_response.status_code == 200:
                        quote_price = float(quote_response.json()['price'])
                        return {
                            "base_price": 1.0,
                            "quote_price": quote_price,
                            "ratio": 1.0 / quote_price
                        }
                    return None
                    
                elif quote_currency == 'USDT':
                    base_symbol = f"{base_currency}USDT"
                    base_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={base_symbol}")
                    
                    if base_response.status_code == 200:
                        base_price = float(base_response.json()['price'])
                        return {
                            "base_price": base_price,
                            "quote_price": 1.0,
                            "ratio": base_price
                        }
                    return None
                
                else:
                    base_symbol = f"{base_currency}USDT"
                    quote_symbol = f"{quote_currency}USDT"
                    
                    base_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={base_symbol}")
                    quote_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={quote_symbol}")
                    
                    if base_response.status_code == 200 and quote_response.status_code == 200:
                        base_price = float(base_response.json()['price'])
                        quote_price = float(quote_response.json()['price'])
                        return {
                            "base_price": base_price,
                            "quote_price": quote_price,
                            "ratio": base_price / quote_price
                        }
                    return None
                    
        except Exception as e:
            print(f"获取价格数据时出错: {e}")
            return None
    
    def _get_fiat_exchange_rate(self, from_currency, to_currency):
        """获取法币汇率"""
        try:
            url = f"https://api.exchangerate-api.com/v4/latest/{from_currency}"
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if to_currency in data['rates']:
                    return data['rates'][to_currency]
            return None
        except Exception as e:
            print(f"获取汇率失败: {e}")
            return None
    
    def _get_crypto_to_fiat_rate(self, crypto_symbol, fiat_symbol):
        """获取加密货币对法币的汇率"""
        try:
            if fiat_symbol == 'USD':
                url = f"https://api.binance.com/api/v3/ticker/price?symbol={crypto_symbol}USDT"
                response = requests.get(url, timeout=10)
                if response.status_code == 200:
                    return float(response.json()['price'])
            else:
                url = f"https://api.binance.com/api/v3/ticker/price?symbol={crypto_symbol}USDT"
                response = requests.get(url, timeout=10)
                if response.status_code == 200:
                    usd_price = float(response.json()['price'])
                    exchange_rate = self._get_fiat_exchange_rate('USD', fiat_symbol)
                    if exchange_rate:
                        return usd_price * exchange_rate
            return None
        except Exception as e:
            print(f"获取加密货币汇率失败: {e}")
            return None
