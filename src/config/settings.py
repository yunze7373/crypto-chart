# src/config/settings.py
"""
应用程序配置设置
"""
import os
from typing import Dict, Any

class Config:
    """基础配置类"""
    
    # Flask 配置
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    DEBUG = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    
    # 数据库配置
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///instance/crypto_alerts.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # API 配置
    COINGECKO_API_URL = 'https://api.coingecko.com/api/v3'
    API_REQUEST_TIMEOUT = 30
    
    # 价格监控配置
    PRICE_CHECK_INTERVAL = 30  # 秒
    MAX_RETRIES = 3
    RETRY_DELAY = 5  # 秒
    
    # Discord 配置
    DISCORD_WEBHOOK_URL = os.environ.get('DISCORD_WEBHOOK_URL')
    DISCORD_ENABLED = bool(DISCORD_WEBHOOK_URL)
    
    # 应用配置
    HOST = os.environ.get('HOST', '127.0.0.1')
    PORT = int(os.environ.get('PORT', 5008))
    
    # 支持的货币列表
    SUPPORTED_CURRENCIES = [
        'bitcoin', 'ethereum', 'binancecoin', 'cardano', 'solana',
        'ripple', 'polkadot', 'dogecoin', 'avalanche-2', 'polygon',
        'chainlink', 'litecoin', 'bitcoin-cash', 'stellar', 'vechain',
        'filecoin', 'tron', 'ethereum-classic', 'monero', 'algorand',
        'cosmos', 'tezos', 'elrond-matic', 'theta-token', 'eos',
        'aave', 'neo', 'maker', 'compound-governance-token', 'dash',
        'zcash', 'decred', 'yearn-finance', 'synthetix-network-token',
        'uma', 'kyber-network-crystal', 'bancor', 'loopring', 'numeraire',
        'republic-protocol', 'augur', 'status', 'civic', 'district0x',
        'aragon', 'gnosis', 'golem', 'basic-attention-token', 'metal',
        'tenx', 'monaco', 'populous', 'salt', 'storj',
        'power-ledger', 'request-network', 'kyber-network', 'ethos',
        'raiden-network-token', 'polymath', 'dentacoin', 'veritaseum',
        'waltonchain', 'gas', 'nebulas', 'rchain', 'kin'
    ]
    
    # 货币符号映射
    CURRENCY_SYMBOLS = {
        'bitcoin': 'BTC',
        'ethereum': 'ETH',
        'binancecoin': 'BNB',
        'cardano': 'ADA',
        'solana': 'SOL',
        'ripple': 'XRP',
        'polkadot': 'DOT',
        'dogecoin': 'DOGE',
        'avalanche-2': 'AVAX',
        'polygon': 'MATIC',
        'chainlink': 'LINK',
        'litecoin': 'LTC',
        'bitcoin-cash': 'BCH',
        'stellar': 'XLM',
        'vechain': 'VET',
        'filecoin': 'FIL',
        'tron': 'TRX',
        'ethereum-classic': 'ETC',
        'monero': 'XMR',
        'algorand': 'ALGO',
        'cosmos': 'ATOM',
        'tezos': 'XTZ',
        'elrond-matic': 'EGLD',
        'theta-token': 'THETA',
        'eos': 'EOS',
        'aave': 'AAVE',
        'neo': 'NEO',
        'maker': 'MKR',
        'compound-governance-token': 'COMP',
        'dash': 'DASH',
        'zcash': 'ZEC',
        'decred': 'DCR',
        'yearn-finance': 'YFI',
        'synthetix-network-token': 'SNX',
        'uma': 'UMA',
        'kyber-network-crystal': 'KNC',
        'bancor': 'BNT',
        'loopring': 'LRC',
        'numeraire': 'NMR',
        'republic-protocol': 'REN',
        'augur': 'REP',
        'status': 'SNT',
        'civic': 'CVC',
        'district0x': 'DNT',
        'aragon': 'ANT',
        'gnosis': 'GNO',
        'golem': 'GLM',
        'basic-attention-token': 'BAT',
        'metal': 'MTL',
        'tenx': 'PAY',
        'monaco': 'MCO',
        'populous': 'PPT',
        'salt': 'SALT',
        'storj': 'STORJ',
        'power-ledger': 'POWR',
        'request-network': 'REQ',
        'kyber-network': 'KNC',
        'ethos': 'ETHOS',
        'raiden-network-token': 'RDN',
        'polymath': 'POLY',
        'dentacoin': 'DCN',
        'veritaseum': 'VERI',
        'waltonchain': 'WTC',
        'gas': 'GAS',
        'nebulas': 'NAS',
        'rchain': 'RHOC',
        'kin': 'KIN'
    }

class DevelopmentConfig(Config):
    """开发环境配置"""
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///instance/crypto_alerts_dev.db'

class ProductionConfig(Config):
    """生产环境配置"""
    DEBUG = False
    
    # 只在生产环境运行时才检查SECRET_KEY
    @property
    def SECRET_KEY(self):
        secret_key = os.environ.get('SECRET_KEY')
        if not secret_key:
            raise ValueError("生产环境必须设置 SECRET_KEY 环境变量")
        return secret_key

class TestingConfig(Config):
    """测试环境配置"""
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    PRICE_CHECK_INTERVAL = 5  # 测试时使用更短的间隔

# 配置映射
config_map: Dict[str, Any] = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}

def get_config(config_name: str = None) -> Config:
    """获取配置对象"""
    if config_name is None:
        config_name = os.environ.get('FLASK_ENV', 'default')
    
    return config_map.get(config_name, DevelopmentConfig)
