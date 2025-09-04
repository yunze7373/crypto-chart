# Gunicorn 配置文件
import multiprocessing
import os

# 服务器配置
bind = "0.0.0.0:5008"
workers = min(4, multiprocessing.cpu_count())
worker_class = "sync"
worker_connections = 1000
timeout = 120
keepalive = 2
max_requests = 1000
max_requests_jitter = 100

# 日志配置 - 智能路径选择
def get_log_path():
    """智能选择日志路径"""
    # 尝试使用系统日志目录
    system_log_dir = "/var/log/crypto-chart"
    project_log_dir = os.path.join(os.getcwd(), "logs")
    
    # 检查系统日志目录是否可写
    try:
        if os.path.exists(system_log_dir) and os.access(system_log_dir, os.W_OK):
            return system_log_dir
    except:
        pass
    
    # 使用项目日志目录
    os.makedirs(project_log_dir, exist_ok=True)
    return project_log_dir

# 获取日志目录
log_dir = get_log_path()

# 设置日志文件路径
accesslog = os.path.join(log_dir, "gunicorn.access.log")
errorlog = os.path.join(log_dir, "gunicorn.error.log")
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# 进程配置 - 移除可能有权限问题的配置
daemon = False
pidfile = None  # 不使用 pidfile，避免权限问题
user = None     # 不强制指定用户，使用启动用户
group = None    # 不强制指定组，使用启动用户的组
tmp_upload_dir = None

# 安全配置
limit_request_line = 4096
limit_request_fields = 100
limit_request_field_size = 8190

# 性能配置
preload_app = True
sendfile = True

# SSL配置（如果需要HTTPS）
# keyfile = None
# certfile = None

def when_ready(server):
    server.log.info("CryptoRate Pro server is ready. Spawning workers")
    server.log.info(f"Log directory: {log_dir}")

def worker_int(worker):
    worker.log.info("Worker received INT or QUIT signal")

def pre_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def post_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def post_worker_init(worker):
    worker.log.info("Worker initialized (pid: %s)", worker.pid)

def worker_abort(worker):
    worker.log.info("Worker aborted (pid: %s)", worker.pid)