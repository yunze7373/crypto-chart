# src/services/alert_service.py
"""
提醒服务
"""
import logging
from typing import List, Optional, Dict, Any
from ..models import db, Alert
from .notification_service import NotificationService
from .price_service import PriceService

logger = logging.getLogger(__name__)


class AlertService:
    """提醒服务类"""
    
    def __init__(self):
        self.notification_service = NotificationService()
        self.price_service = PriceService()
    
    def create_alert(self, base_currency: str, quote_currency: str,
                    condition_type: str, target_price: float,
                    discord_webhook_url: str, user_identifier: Optional[str] = None,
                    note: Optional[str] = None) -> Optional[Alert]:
        """
        创建新的价格提醒
        
        Args:
            base_currency: 基础货币
            quote_currency: 计价货币
            condition_type: 条件类型 ('above' 或 'below')
            target_price: 目标价格
            discord_webhook_url: Discord Webhook URL
            user_identifier: 用户标识符
            note: 备注
            
        Returns:
            创建的提醒对象，失败时返回None
        """
        try:
            # 验证输入
            if not self._validate_alert_input(base_currency, quote_currency, 
                                            condition_type, target_price, 
                                            discord_webhook_url):
                return None
            
            # 创建提醒对象
            alert = Alert(
                base_currency=base_currency.lower(),
                quote_currency=quote_currency.lower(),
                condition_type=condition_type,
                target_price=target_price,
                discord_webhook_url=discord_webhook_url,
                user_identifier=user_identifier,
                note=note
            )
            
            # 保存到数据库
            db.session.add(alert)
            db.session.commit()
            
            logger.info(f"创建价格提醒成功: {alert}")
            return alert
            
        except Exception as e:
            logger.error(f"创建价格提醒时发生错误: {e}")
            db.session.rollback()
            return None
    
    def get_alerts(self, user_identifier: Optional[str] = None, 
                  active_only: bool = False) -> List[Alert]:
        """
        获取提醒列表
        
        Args:
            user_identifier: 用户标识符，为None时获取所有用户的提醒
            active_only: 是否只获取活跃的提醒
            
        Returns:
            提醒列表
        """
        try:
            query = Alert.query
            
            if user_identifier:
                query = query.filter_by(user_identifier=user_identifier)
            
            if active_only:
                query = query.filter_by(is_active=True, is_triggered=False)
            
            alerts = query.order_by(Alert.created_at.desc()).all()
            
            logger.debug(f"获取到 {len(alerts)} 个提醒")
            return alerts
            
        except Exception as e:
            logger.error(f"获取提醒列表时发生错误: {e}")
            return []
    
    def get_alert_by_id(self, alert_id: int) -> Optional[Alert]:
        """
        根据ID获取提醒
        
        Args:
            alert_id: 提醒ID
            
        Returns:
            提醒对象，不存在时返回None
        """
        try:
            return Alert.query.get(alert_id)
        except Exception as e:
            logger.error(f"获取提醒时发生错误: {e}")
            return None
    
    def delete_alert(self, alert_id: int) -> bool:
        """
        删除提醒
        
        Args:
            alert_id: 提醒ID
            
        Returns:
            是否删除成功
        """
        try:
            alert = Alert.query.get(alert_id)
            if not alert:
                logger.warning(f"提醒 {alert_id} 不存在")
                return False
            
            db.session.delete(alert)
            db.session.commit()
            
            logger.info(f"删除提醒成功: {alert}")
            return True
            
        except Exception as e:
            logger.error(f"删除提醒时发生错误: {e}")
            db.session.rollback()
            return False
    
    def toggle_alert(self, alert_id: int) -> Optional[Alert]:
        """
        切换提醒状态
        
        Args:
            alert_id: 提醒ID
            
        Returns:
            更新后的提醒对象，失败时返回None
        """
        try:
            alert = Alert.query.get(alert_id)
            if not alert:
                logger.warning(f"提醒 {alert_id} 不存在")
                return None
            
            if alert.is_active:
                alert.deactivate()
            else:
                alert.activate()
                # 如果重新激活，重置触发状态
                if alert.is_triggered:
                    alert.reset()
            
            db.session.commit()
            
            logger.info(f"切换提醒状态成功: {alert}")
            return alert
            
        except Exception as e:
            logger.error(f"切换提醒状态时发生错误: {e}")
            db.session.rollback()
            return None
    
    def check_alert_condition(self, alert: Alert, current_price: float) -> bool:
        """
        检查提醒条件是否满足
        
        Args:
            alert: 提醒对象
            current_price: 当前价格
            
        Returns:
            是否满足条件
        """
        if alert.condition_type == 'above':
            return current_price >= alert.target_price
        elif alert.condition_type == 'below':
            return current_price <= alert.target_price
        else:
            logger.warning(f"未知的条件类型: {alert.condition_type}")
            return False
    
    def trigger_alert(self, alert: Alert, current_price: float) -> bool:
        """
        触发提醒
        
        Args:
            alert: 提醒对象
            current_price: 当前价格
            
        Returns:
            是否触发成功
        """
        try:
            # 发送通知
            success = self.notification_service.send_price_alert(
                webhook_url=alert.discord_webhook_url,
                base_currency=alert.base_currency,
                quote_currency=alert.quote_currency,
                condition_type=alert.condition_type,
                target_price=alert.target_price,
                current_price=current_price,
                note=alert.note
            )
            
            if success:
                # 标记为已触发
                alert.mark_as_triggered()
                db.session.commit()
                
                logger.info(f"提醒触发成功: {alert}")
                return True
            else:
                logger.error(f"发送通知失败: {alert}")
                return False
                
        except Exception as e:
            logger.error(f"触发提醒时发生错误: {e}")
            db.session.rollback()
            return False
    
    def check_all_alerts(self) -> Dict[str, int]:
        """
        检查所有活跃的提醒
        
        Returns:
            检查结果统计
        """
        stats = {
            'checked': 0,
            'triggered': 0,
            'errors': 0
        }
        
        try:
            # 获取所有活跃且未触发的提醒
            alerts = Alert.get_active_alerts()
            stats['checked'] = len(alerts)
            
            logger.debug(f"开始检查 {len(alerts)} 个活跃提醒")
            
            for alert in alerts:
                try:
                    # 获取当前价格
                    current_price = self.price_service.get_current_price(
                        alert.base_currency, alert.quote_currency
                    )
                    
                    if current_price is None:
                        logger.warning(f"无法获取价格，跳过提醒: {alert}")
                        stats['errors'] += 1
                        continue
                    
                    # 检查条件
                    if self.check_alert_condition(alert, current_price):
                        # 触发提醒
                        if self.trigger_alert(alert, current_price):
                            stats['triggered'] += 1
                        else:
                            stats['errors'] += 1
                    
                except Exception as e:
                    logger.error(f"检查提醒时发生错误: {alert}, 错误: {e}")
                    stats['errors'] += 1
            
            logger.info(f"提醒检查完成: {stats}")
            return stats
            
        except Exception as e:
            logger.error(f"检查提醒时发生严重错误: {e}")
            stats['errors'] += stats['checked']
            return stats
    
    def _validate_alert_input(self, base_currency: str, quote_currency: str,
                            condition_type: str, target_price: float,
                            discord_webhook_url: str) -> bool:
        """
        验证提醒输入参数
        
        Args:
            base_currency: 基础货币
            quote_currency: 计价货币
            condition_type: 条件类型
            target_price: 目标价格
            discord_webhook_url: Discord Webhook URL
            
        Returns:
            是否有效
        """
        # 验证货币对
        if not self.price_service.validate_currency_pair(base_currency, quote_currency):
            logger.warning(f"无效的货币对: {base_currency}/{quote_currency}")
            return False
        
        # 验证条件类型
        if condition_type not in ['above', 'below']:
            logger.warning(f"无效的条件类型: {condition_type}")
            return False
        
        # 验证目标价格
        if target_price <= 0:
            logger.warning(f"无效的目标价格: {target_price}")
            return False
        
        # 验证Webhook URL
        if not self.notification_service.validate_webhook_url(discord_webhook_url):
            logger.warning(f"无效的Discord Webhook URL")
            return False
        
        return True
    
    def get_alert_statistics(self) -> Dict[str, Any]:
        """
        获取提醒统计信息
        
        Returns:
            统计信息字典
        """
        try:
            total_alerts = Alert.query.count()
            active_alerts = Alert.query.filter_by(is_active=True, is_triggered=False).count()
            triggered_alerts = Alert.query.filter_by(is_triggered=True).count()
            inactive_alerts = Alert.query.filter_by(is_active=False).count()
            
            return {
                'total': total_alerts,
                'active': active_alerts,
                'triggered': triggered_alerts,
                'inactive': inactive_alerts
            }
            
        except Exception as e:
            logger.error(f"获取统计信息时发生错误: {e}")
            return {
                'total': 0,
                'active': 0,
                'triggered': 0,
                'inactive': 0
            }
