# src/services/monitor_service.py
"""
监控服务
"""
import threading
import time
import logging
from typing import Optional
from .alert_service import AlertService
from ..config import get_config

logger = logging.getLogger(__name__)


class MonitorService:
    """价格监控服务类"""
    
    def __init__(self):
        self.config = get_config()
        self.alert_service = AlertService()
        self.check_interval = self.config.PRICE_CHECK_INTERVAL
        
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
    
    def start(self) -> bool:
        """
        启动监控服务
        
        Returns:
            是否启动成功
        """
        if self._running:
            logger.warning("监控服务已经在运行")
            return False
        
        try:
            self._running = True
            self._stop_event.clear()
            
            # 创建并启动监控线程
            self._thread = threading.Thread(
                target=self._monitor_loop,
                name="PriceMonitor",
                daemon=True
            )
            self._thread.start()
            
            logger.info("价格监控服务已启动")
            return True
            
        except Exception as e:
            logger.error(f"启动监控服务时发生错误: {e}")
            self._running = False
            return False
    
    def stop(self) -> bool:
        """
        停止监控服务
        
        Returns:
            是否停止成功
        """
        if not self._running:
            logger.warning("监控服务未在运行")
            return False
        
        try:
            logger.info("正在停止价格监控服务...")
            
            # 设置停止标志
            self._running = False
            self._stop_event.set()
            
            # 等待线程结束
            if self._thread and self._thread.is_alive():
                self._thread.join(timeout=10)  # 最多等待10秒
                
                if self._thread.is_alive():
                    logger.warning("监控线程未能在10秒内停止")
                    return False
            
            logger.info("价格监控服务已停止")
            return True
            
        except Exception as e:
            logger.error(f"停止监控服务时发生错误: {e}")
            return False
    
    def is_running(self) -> bool:
        """
        检查监控服务是否正在运行
        
        Returns:
            是否正在运行
        """
        return self._running and self._thread and self._thread.is_alive()
    
    def get_status(self) -> dict:
        """
        获取监控服务状态
        
        Returns:
            状态信息字典
        """
        return {
            'running': self.is_running(),
            'check_interval': self.check_interval,
            'thread_alive': self._thread.is_alive() if self._thread else False,
            'alert_statistics': self.alert_service.get_alert_statistics()
        }
    
    def _monitor_loop(self):
        """监控循环"""
        logger.info("价格监控循环已开始")
        
        while self._running and not self._stop_event.is_set():
            try:
                # 检查所有提醒
                stats = self.alert_service.check_all_alerts()
                
                if stats['checked'] > 0:
                    logger.debug(
                        f"检查完成 - 总数: {stats['checked']}, "
                        f"触发: {stats['triggered']}, "
                        f"错误: {stats['errors']}"
                    )
                
                # 等待下一次检查
                if self._stop_event.wait(timeout=self.check_interval):
                    # 收到停止信号
                    break
                    
            except Exception as e:
                logger.error(f"监控循环中发生错误: {e}")
                
                # 发生错误时短暂等待，避免快速重试
                if self._stop_event.wait(timeout=min(self.check_interval, 60)):
                    break
        
        logger.info("价格监控循环已结束")
    
    def force_check(self) -> dict:
        """
        强制执行一次检查
        
        Returns:
            检查结果统计
        """
        logger.info("执行强制检查")
        return self.alert_service.check_all_alerts()
    
    def restart(self) -> bool:
        """
        重启监控服务
        
        Returns:
            是否重启成功
        """
        logger.info("重启监控服务")
        
        if self.is_running():
            if not self.stop():
                return False
        
        # 短暂等待确保完全停止
        time.sleep(1)
        
        return self.start()
    
    def set_check_interval(self, interval: int) -> bool:
        """
        设置检查间隔
        
        Args:
            interval: 新的检查间隔（秒）
            
        Returns:
            是否设置成功
        """
        if interval < 5:
            logger.warning("检查间隔不能小于5秒")
            return False
        
        old_interval = self.check_interval
        self.check_interval = interval
        
        logger.info(f"检查间隔已从 {old_interval} 秒更新为 {interval} 秒")
        return True
