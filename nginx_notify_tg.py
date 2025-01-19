#!/usr/bin/env python3
import time
import requests
import json
from pathlib import Path
import re
from datetime import datetime
from collections import defaultdict
from urllib.parse import urlparse

# 配置项
NGINX_LOG = "/var/log/nginx/access.log"
TELEGRAM_BOT_TOKEN = "YOUR_BOT_TOKEN"  # 替换为你的 Telegram Bot Token
TELEGRAM_CHAT_ID = "YOUR_CHAT_ID"      # 替换为你的 Chat ID
SERVER_NAME = "YOUR_SERVER_NAME"

# 监控配置
MONITOR_SETTINGS = {
    'threshold_enabled': False,  # 阈值开关：True-启用访问次数阈值，False-每次访问都通知
    'burst_threshold': 5,  # 访问次数阈值
    'burst_window': 60,  # 检测窗口(秒)
}

# 监控的网站和路径
MONITOR_SITES = {
    "example.com": ["/dashboard/login", "/admin"],
    # 添加更多网站和路径
}

# IP 白名单
IP_WHITELIST = {
    "1.1.1.1": "安全IP",
    "2.2.2.2": "开发者IP",
}


class AccessTracker:
    def __init__(self):
        self.ip_records = defaultdict(list)  # 记录访问时间
        self.last_notify_time = defaultdict(float)  # 记录最后通知时间

    def add_access(self, ip, current_time):
        """添加新的访问记录"""
        # 只有在启用阈值时才需要记录访问
        if MONITOR_SETTINGS['threshold_enabled']:
            self.cleanup_old_records(ip, current_time)
            self.ip_records[ip].append(current_time)

    def cleanup_old_records(self, ip, current_time):
        """清理过期记录"""
        if MONITOR_SETTINGS['threshold_enabled']:
            cutoff_time = current_time - MONITOR_SETTINGS['burst_window']
            self.ip_records[ip] = [t for t in self.ip_records[ip] if t > cutoff_time]

    def should_notify(self, ip, current_time):
        """检查是否需要发送通知"""
        # 如果阈值开关关闭，每次访问都通知
        if not MONITOR_SETTINGS['threshold_enabled']:
            return True

        # 启用阈值时，检查访问次数
        return len(self.ip_records[ip]) >= MONITOR_SETTINGS['burst_threshold']


def send_telegram_notification(message):
    """发送 Telegram 通知"""
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        data = {
            "chat_id": TELEGRAM_CHAT_ID,
            "text": message,
            "parse_mode": "HTML",  # 启用 HTML 格式
            "disable_web_page_preview": True
        }

        response = requests.post(url, json=data)

        if response.status_code == 200:
            print(f"通知发送成功")
        else:
            print(f"通知发送失败: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"发送通知时出错: {str(e)}")


def parse_nginx_log_line(line):
    """解析 Nginx 日志行"""
    try:
        pattern = r'(?P<ip>[\d\.]+) - - \[(?P<time>.*?)\] "(?P<method>\w+) (?P<path>.*?) HTTP/.*?" (?P<status>\d+) (?P<bytes>\d+) "(?P<referer>.*?)" "(?P<useragent>.*?)"'
        match = re.match(pattern, line)
        if match:
            return match.groupdict()
        return None
    except Exception as e:
        print(f"解析日志行时出错: {str(e)}")
        return None


def extract_real_access_info(referer):
    """从 referer 中提取实际访问的主机和路径"""
    if not referer or referer == '-':
        return None, None

    try:
        parsed = urlparse(referer)
        return parsed.netloc, parsed.path
    except:
        return None, None


def should_monitor_access(host, path):
    """检查是否需要监控该访问"""
    if host in MONITOR_SITES:
        return any(monitor_path in path for monitor_path in MONITOR_SITES[host])
    return False


def monitor_log():
    """监控日志文件"""
    log_file = Path(NGINX_LOG)
    if not log_file.exists():
        print(f"错误: 日志文件不存在 {NGINX_LOG}")
        return

    file_size = log_file.stat().st_size
    access_tracker = AccessTracker()

    print(f"开始监控 Nginx 访问日志... ({SERVER_NAME})")
    print(f"阈值开关: {'开启' if MONITOR_SETTINGS['threshold_enabled'] else '关闭'}")
    if MONITOR_SETTINGS['threshold_enabled']:
        print(f"访问阈值: {MONITOR_SETTINGS['burst_window']}秒内{MONITOR_SETTINGS['burst_threshold']}次")

    while True:
        try:
            with open(NGINX_LOG, 'r') as f:
                current_size = log_file.stat().st_size
                if current_size < file_size:
                    file_size = 0

                f.seek(file_size)

                for line in f:
                    current_time = time.time()
                    log_data = parse_nginx_log_line(line)

                    if log_data:
                        # 从 referer 获取实际访问信息
                        real_host, real_path = extract_real_access_info(log_data['referer'])
                        if not real_host or not real_path:
                            continue

                        ip = log_data['ip']

                        if ip in IP_WHITELIST:
                            print(f"白名单 IP 访问 ({IP_WHITELIST[ip]}): {ip} -> {real_path}")
                            continue

                        # 检查是否需要监控这个访问
                        if not should_monitor_access(real_host, real_path):
                            continue

                        # 记录访问
                        access_tracker.add_access(ip, current_time)

                        # 检查是否需要发送通知
                        if access_tracker.should_notify(ip, current_time):
                            # 使用 HTML 格式化消息
                            message_parts = [
                                f"<b>服务器: {SERVER_NAME}- ⚠️ {'检测到频繁访问' if MONITOR_SETTINGS['threshold_enabled'] else '检测到敏感路径访问'} </b>\n",
                                f"<b>访客IP:</b> {ip}",  # 访客 IP 地址
                            ]

                            if MONITOR_SETTINGS['threshold_enabled']:
                                message_parts.append(
                                    f"<b>警告:</b> {MONITOR_SETTINGS['burst_window']}秒内访问超过{MONITOR_SETTINGS['burst_threshold']}次")

                            message_parts.extend([
                                f"<b>时间:</b> {log_data['time']}",
                                f"<b>访问页面:</b> {real_host}{real_path}",
                                f"<b>UA:</b> {log_data['useragent']}"
                            ])

                            message = "\n".join(message_parts)
                            send_telegram_notification(message)

                file_size = f.tell()

        except Exception as e:
            print(f"监控过程中出错: {str(e)}")
            # 发送错误通知
            error_message = (
                f"<b>⚠️ 监控脚本错误</b>\n"
                f"<b>服务器:</b> {SERVER_NAME}\n"
                f"<b>时间:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                f"<b>错误信息:</b> {str(e)}"
            )
            send_telegram_notification(error_message)

        time.sleep(1)


if __name__ == "__main__":
    monitor_log()
