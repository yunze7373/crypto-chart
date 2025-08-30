# app.py
from flask import Flask, jsonify, render_template, request
import requests
import pandas as pd
from datetime import datetime, timedelta
import time

app = Flask(__name__)

# 支持的法币列表
FIAT_CURRENCIES = {'USD', 'CNY', 'EUR', 'JPY', 'GBP', 'KRW', 'CAD', 'AUD', 'CHF', 'HKD', 'SGD', 'INR'}

def get_fiat_exchange_rate(from_currency, to_currency):
    """获取法币汇率（使用免费的汇率API）"""
    try:
        # 使用exchangerate-api.com的免费API
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

def get_crypto_to_fiat_rate(crypto_symbol, fiat_symbol):
    """获取加密货币对法币的汇率"""
    try:
        if fiat_symbol == 'USD':
            # 直接获取加密货币对USD的价格
            url = f"https://api.binance.com/api/v3/ticker/price?symbol={crypto_symbol}USDT"
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                return float(response.json()['price'])
        else:
            # 先获取加密货币对USD的价格，再转换为目标法币
            url = f"https://api.binance.com/api/v3/ticker/price?symbol={crypto_symbol}USDT"
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                usd_price = float(response.json()['price'])
                # 获取USD到目标法币的汇率
                exchange_rate = get_fiat_exchange_rate('USD', fiat_symbol)
                if exchange_rate:
                    return usd_price * exchange_rate
        return None
    except Exception as e:
        print(f"获取加密货币汇率失败: {e}")
        return None

def is_fiat_currency(symbol):
    """判断是否为法币"""
    return symbol.upper() in FIAT_CURRENCIES

def get_binance_price_history(symbol, interval='1h', days=30):
    """通过币安API获取K线数据。"""
    limit = days * 24
    url = "https://api.binance.com/api/v3/klines"
    params = {"symbol": symbol, "interval": interval, "limit": int(limit)}
    
    try:
        r = requests.get(url, params=params)
        r.raise_for_status()
        data = r.json()
        
        df = pd.DataFrame(data, columns=[
            'timestamp', 'open', 'high', 'low', 'close', 'volume', 
            'close_time', 'quote_asset_volume', 'number_of_trades', 
            'taker_buy_base_asset_volume', 'taker_buy_quote_asset_volume', 'ignore'
        ])
        df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
        df['price'] = pd.to_numeric(df['close'])
        return df[['timestamp', 'price']].set_index('timestamp')
    except Exception as e:
        print(f"Error fetching data for {symbol}: {e}")
        return None

# API 接口，用于向前端提供数据
@app.route('/api/data')
def get_ratio_data():
    """获取两个货币的价格数据并计算比例（目前仅支持加密货币）"""
    # 获取时间跨度参数，默认为30天
    timespan = request.args.get('timespan', '30d')
    # 获取货币对参数，默认为OP/ARB
    base_currency = request.args.get('base', 'OP').upper()
    quote_currency = request.args.get('quote', 'ARB').upper()
    
    # 检查是否包含法币（历史数据API暂不支持法币）
    if is_fiat_currency(base_currency) or is_fiat_currency(quote_currency):
        return jsonify({
            "error": "历史图表数据目前仅支持加密货币对，法币支持即将推出",
            "message": "Historical chart data currently supports only cryptocurrency pairs. Fiat currency support coming soon.",
            "suggestion": "您可以查看当前价格，或选择加密货币对来查看历史图表"
        }), 400
    
    # 根据时间跨度设置天数和K线间隔
    timespan_config = {
        '1d': {'days': 1, 'interval': '5m'},
        '7d': {'days': 7, 'interval': '1h'},
        '30d': {'days': 30, 'interval': '1h'},
        '90d': {'days': 90, 'interval': '4h'},
        '1y': {'days': 365, 'interval': '1d'},
        'all': {'days': 1000, 'interval': '1d'}
    }
    
    config = timespan_config.get(timespan, {'days': 30, 'interval': '1h'})
    
    # 特殊处理USDT情况
    if base_currency == 'USDT' and quote_currency == 'USDT':
        return jsonify({"error": "基础货币和计价货币不能都是USDT"}), 400
    
    # 构建币安交易对符号
    if base_currency == 'USDT':
        # 如果基础货币是USDT，获取计价货币对USDT的价格，然后取倒数
        base_symbol = f"{quote_currency}USDT"
        quote_symbol = "USDTUSDT"  # 这个不会被使用
        
        base_prices = get_binance_price_history(base_symbol, interval=config['interval'], days=config['days'])
        if base_prices is None:
            return jsonify({"error": f"Failed to fetch data for {quote_currency}/USDT from Binance"}), 500
        
        # 创建USDT价格数据（固定为1）和计算比例
        quote_prices = base_prices.copy()
        quote_prices['price'] = 1.0  # USDT价格固定为1
        
        # 合并数据并计算比例 (USDT/其他货币 = 1/其他货币价格)
        df = base_prices.join(quote_prices, lsuffix="_quote", rsuffix="_base", how="inner")
        df["ratio"] = df["price_base"] / df["price_quote"]  # 1 / 其他货币价格
        
    elif quote_currency == 'USDT':
        # 如果计价货币是USDT，直接获取基础货币对USDT的价格
        base_symbol = f"{base_currency}USDT"
        
        base_prices = get_binance_price_history(base_symbol, interval=config['interval'], days=config['days'])
        if base_prices is None:
            return jsonify({"error": f"Failed to fetch data for {base_currency}/USDT from Binance"}), 500
        
        # 创建USDT价格数据（固定为1）
        quote_prices = base_prices.copy()
        quote_prices['price'] = 1.0  # USDT价格固定为1
        
        # 合并数据并计算比例
        df = base_prices.join(quote_prices, lsuffix="_base", rsuffix="_quote", how="inner")
        df["ratio"] = df["price_base"] / df["price_quote"]  # 基础货币价格 / 1
        
    else:
        # 正常情况：两个货币都不是USDT
        base_symbol = f"{base_currency}USDT"
        quote_symbol = f"{quote_currency}USDT"
        
        base_prices = get_binance_price_history(base_symbol, interval=config['interval'], days=config['days'])
        quote_prices = get_binance_price_history(quote_symbol, interval=config['interval'], days=config['days'])

        if base_prices is None or quote_prices is None:
            return jsonify({"error": f"Failed to fetch data for {base_currency}/{quote_currency} from Binance"}), 500

        # 合并数据并计算比例
        df = base_prices.join(quote_prices, lsuffix="_base", rsuffix="_quote", how="inner")
        df["ratio"] = df["price_base"] / df["price_quote"]
    
    # 准备返回给前端的JSON数据
    # Chart.js 需要标签(labels)和数据(data)
    data = {
        "labels": df.index.strftime('%Y-%m-%d %H:%M').tolist(),
        "op_arb_data": df["ratio"].round(4).tolist(),
        "op_prices": df["price_base"].round(4).tolist(),
        "arb_prices": df["price_quote"].round(4).tolist(),
        "base_currency": base_currency,
        "quote_currency": quote_currency,
        "pair_name": f"{base_currency}/{quote_currency}"
    }
    return jsonify(data)

# 获取当前价格的API
@app.route('/api/current')
def get_current_prices():
    """获取当前的两个货币价格"""
    base_currency = request.args.get('base', 'OP').upper()
    quote_currency = request.args.get('quote', 'ARB').upper()
    
    try:
        # 特殊处理USDT情况
        if base_currency == 'USDT' and quote_currency == 'USDT':
            return jsonify({"error": "基础货币和计价货币不能都是USDT"}), 400
        
        if base_currency == 'USDT':
            # 如果基础货币是USDT，获取计价货币对USDT的价格，然后取倒数
            quote_symbol = f"{quote_currency}USDT"
            quote_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={quote_symbol}")
            
            if quote_response.status_code == 200:
                quote_price = float(quote_response.json()['price'])
                base_price = 1.0  # USDT价格为1
                ratio = base_price / quote_price  # 1 / 其他货币价格
                
                return jsonify({
                    "base_price": round(base_price, 4),
                    "quote_price": round(quote_price, 4),
                    "ratio": round(ratio, 4),
                    "base_currency": base_currency,
                    "quote_currency": quote_currency,
                    "pair_name": f"{base_currency}/{quote_currency}",
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            else:
                return jsonify({"error": f"Failed to fetch price for {quote_currency}"}), 500
                
        elif quote_currency == 'USDT':
            # 如果计价货币是USDT，直接获取基础货币对USDT的价格
            base_symbol = f"{base_currency}USDT"
            base_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={base_symbol}")
            
            if base_response.status_code == 200:
                base_price = float(base_response.json()['price'])
                quote_price = 1.0  # USDT价格为1
                ratio = base_price / quote_price  # 基础货币价格 / 1
                
                return jsonify({
                    "base_price": round(base_price, 4),
                    "quote_price": round(quote_price, 4),
                    "ratio": round(ratio, 4),
                    "base_currency": base_currency,
                    "quote_currency": quote_currency,
                    "pair_name": f"{base_currency}/{quote_currency}",
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            else:
                return jsonify({"error": f"Failed to fetch price for {base_currency}"}), 500
        
        else:
            # 正常情况：两个货币都不是USDT
            base_symbol = f"{base_currency}USDT"
            quote_symbol = f"{quote_currency}USDT"
            
            base_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={base_symbol}")
            quote_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={quote_symbol}")
            
            if base_response.status_code == 200 and quote_response.status_code == 200:
                base_price = float(base_response.json()['price'])
                quote_price = float(quote_response.json()['price'])
                ratio = base_price / quote_price
                
                return jsonify({
                    "base_price": round(base_price, 4),
                    "quote_price": round(quote_price, 4),
                    "ratio": round(ratio, 4),
                    "base_currency": base_currency,
                    "quote_currency": quote_currency,
                    "pair_name": f"{base_currency}/{quote_currency}",
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            else:
                return jsonify({"error": f"Failed to fetch current prices for {base_currency}/{quote_currency}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# 新的当前价格API（与前端匹配，支持法币）
@app.route('/api/current_prices')
def get_current_prices_new():
    """获取当前的两个货币价格 - 新API格式，支持法币"""
    base_currency = request.args.get('base', 'OP').upper()
    quote_currency = request.args.get('quote', 'ARB').upper()
    
    try:
        # 检查是否为法币
        base_is_fiat = is_fiat_currency(base_currency)
        quote_is_fiat = is_fiat_currency(quote_currency)
        
        if base_is_fiat and quote_is_fiat:
            # 法币对法币
            if base_currency == quote_currency:
                return jsonify({
                    "status": "error",
                    "message": "基础货币和计价货币不能相同"
                }), 400
            
            # 获取法币汇率
            rate = get_fiat_exchange_rate(base_currency, quote_currency)
            if rate is not None:
                return jsonify({
                    "status": "success",
                    "base_price": 1.0,
                    "quote_price": round(1.0/rate, 6),
                    "ratio": round(rate, 6),
                    "base_currency": base_currency,
                    "quote_currency": quote_currency,
                    "pair_name": f"{base_currency}/{quote_currency}",
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            else:
                return jsonify({
                    "status": "error",
                    "message": f"无法获取 {base_currency}/{quote_currency} 汇率"
                }), 500
                
        elif base_is_fiat and not quote_is_fiat:
            # 法币对加密货币
            rate = get_crypto_to_fiat_rate(quote_currency, base_currency)
            if rate is not None:
                crypto_price_in_fiat = rate
                fiat_price_in_crypto = 1.0 / rate
                return jsonify({
                    "status": "success",
                    "base_price": 1.0,
                    "quote_price": round(crypto_price_in_fiat, 6),
                    "ratio": round(fiat_price_in_crypto, 8),
                    "base_currency": base_currency,
                    "quote_currency": quote_currency,
                    "pair_name": f"{base_currency}/{quote_currency}",
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            else:
                return jsonify({
                    "status": "error",
                    "message": f"无法获取 {quote_currency} 在 {base_currency} 中的价格"
                }), 500
                
        elif not base_is_fiat and quote_is_fiat:
            # 加密货币对法币
            rate = get_crypto_to_fiat_rate(base_currency, quote_currency)
            if rate is not None:
                return jsonify({
                    "status": "success",
                    "base_price": round(rate, 6),
                    "quote_price": 1.0,
                    "ratio": round(rate, 6),
                    "base_currency": base_currency,
                    "quote_currency": quote_currency,
                    "pair_name": f"{base_currency}/{quote_currency}",
                    "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                })
            else:
                return jsonify({
                    "status": "error",
                    "message": f"无法获取 {base_currency} 在 {quote_currency} 中的价格"
                }), 500
        
        else:
            # 加密货币对加密货币（原有逻辑）
            # 特殊处理USDT情况
            if base_currency == 'USDT' and quote_currency == 'USDT':
                return jsonify({
                    "status": "error",
                    "message": "基础货币和计价货币不能都是USDT"
                }), 400
            
            if base_currency == 'USDT':
                # 如果基础货币是USDT
                quote_symbol = f"{quote_currency}USDT"
                quote_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={quote_symbol}")
                
                if quote_response.status_code == 200:
                    quote_price = float(quote_response.json()['price'])
                    base_price = 1.0
                    ratio = base_price / quote_price
                    
                    return jsonify({
                        "status": "success",
                        "base_price": round(base_price, 4),
                        "quote_price": round(quote_price, 4),
                        "ratio": round(ratio, 6),
                        "base_currency": base_currency,
                        "quote_currency": quote_currency,
                        "pair_name": f"{base_currency}/{quote_currency}",
                        "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                else:
                    return jsonify({
                        "status": "error",
                        "message": f"Failed to fetch price for {quote_currency}"
                    }), 500
                    
            elif quote_currency == 'USDT':
                # 如果计价货币是USDT
                base_symbol = f"{base_currency}USDT"
                base_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={base_symbol}")
                
                if base_response.status_code == 200:
                    base_price = float(base_response.json()['price'])
                    quote_price = 1.0
                    ratio = base_price / quote_price
                    
                    return jsonify({
                        "status": "success",
                        "base_price": round(base_price, 4),
                        "quote_price": round(quote_price, 4),
                        "ratio": round(ratio, 6),
                        "base_currency": base_currency,
                        "quote_currency": quote_currency,
                        "pair_name": f"{base_currency}/{quote_currency}",
                        "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                else:
                    return jsonify({
                        "status": "error",
                        "message": f"Failed to fetch price for {base_currency}"
                    }), 500
            
            else:
                # 正常情况：两个加密货币都不是USDT
                base_symbol = f"{base_currency}USDT"
                quote_symbol = f"{quote_currency}USDT"
                
                base_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={base_symbol}")
                quote_response = requests.get(f"https://api.binance.com/api/v3/ticker/price?symbol={quote_symbol}")
                
                if base_response.status_code == 200 and quote_response.status_code == 200:
                    base_price = float(base_response.json()['price'])
                    quote_price = float(quote_response.json()['price'])
                    ratio = base_price / quote_price
                    
                    return jsonify({
                        "status": "success",
                        "base_price": round(base_price, 4),
                        "quote_price": round(quote_price, 4),
                        "ratio": round(ratio, 6),
                        "base_currency": base_currency,
                        "quote_currency": quote_currency,
                        "pair_name": f"{base_currency}/{quote_currency}",
                        "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    })
                else:
                    return jsonify({
                        "status": "error",
                        "message": f"Failed to fetch current prices for {base_currency}/{quote_currency}"
                    }), 500
                    
    except Exception as e:
        return jsonify({
            "status": "error", 
            "message": str(e)
        }), 500

# 网站主页
@app.route('/')
def index():
    """渲染前端HTML页面"""
    return render_template('index.html')

if __name__ == '__main__':
    # 启动Web服务器
    print("启动 CryptoRate Pro - 数字资产汇率监控平台...")
    print("请在浏览器中访问: http://127.0.0.1:5008/")
    app.run(debug=True, port=5008)
