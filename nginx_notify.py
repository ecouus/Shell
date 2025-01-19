# !/usr/bin/env python3
import time
import requests
import json
from pathlib import Path
import re
from datetime import datetime

# 配置项
NGINX_LOG = "/var/log/nginx/access.log"
BARK_KEY = "YOUR_DEVICE_KEY"
BARK_URL = "YOUR_BARK_URL/push"
SERVER_NAME = "YOUR_SERVER_NAME"
ICON_URL = "https://i.miji.bid/2025/01/19/0f00a9130d2457850e7f94c55d510111.png"  # 图标URL

# 要监控的网站和路径配置
MONITOR_SITES = {
    "example.com": ["/dashboard/login", "/api/v1/profile"],
    # 添加更多网站和路径
}


def send_bark_notification(title, message):
    """发送 Bark 通知 (POST请求)"""
    try:
        json_data = {
            "title": title,
            "device_key": BARK_KEY,
            "body": message,
            "group": "nginx_monitor",
            "icon": ICON_URL
        }

        headers = {
            "Content-Type": "application/json"
        }

        response = requests.post(
            BARK_URL,
            headers=headers,
            json=json_data
        )

        if response.status_code == 200:
            print(f"通知发送成功: {title}")
        else:
            print(f"通知发送失败: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"发送通知时出错: {str(e)}")


def parse_nginx_log_line(line):
    """解析 Nginx 日志行"""
    try:
        # 根据你的日志格式调整正则表达式
        pattern = r'(?P<ip>[\d\.]+) - - \[(?P<time>.*?)\] "(?P<method>\w+) (?P<path>.*?) HTTP/.*?" (?P<status>\d+) (?P<bytes>\d+) "(?P<referer>.*?)" "(?P<useragent>.*?)"'
        match = re.match(pattern, line)
        if match:
            data = match.groupdict()
            # 从 referer 中提取 host
            if data['referer'].startswith('https://'):
                data['host'] = data['referer'].split('/')[2]
            else:
                data['host'] = ''
            return data
        return None
    except Exception as e:
        print(f"解析日志行时出错: {str(e)}")
        return None


def check_monitored_access(host, path):
    """检查是否访问监控的网站路径"""
    if host in MONITOR_SITES:
        return any(monitored_path in path for monitored_path in MONITOR_SITES[host])
    return False


def monitor_log():
    """监控日志文件"""
    log_file = Path(NGINX_LOG)
    if not log_file.exists():
        print(f"错误: 日志文件不存在 {NGINX_LOG}")
        return

    file_size = log_file.stat().st_size
    print(f"开始监控 Nginx 访问日志... ({SERVER_NAME})")
    print("当前监控的网站和路径:")
    for site, paths in MONITOR_SITES.items():
        print(f"- {site}: {', '.join(paths)}")

    while True:
        try:
            with open(NGINX_LOG, 'r') as f:
                current_size = log_file.stat().st_size
                if current_size < file_size:
                    file_size = 0

                f.seek(file_size)

                for line in f:
                    log_data = parse_nginx_log_line(line)
                    if log_data:
                        host = log_data['host']
                        path = log_data['path']

                        if check_monitored_access(host, path):
                            title = f"{SERVER_NAME} - 检测到敏感路径访问"
                            message = (
                                f"服务器：{SERVER_NAME}\n"
                                f"网站: {host}\n"
                                f"路径: {path}\n"
                                f"来源: {log_data['referer']}\n"
                                f"IP: {log_data['ip']}\n"
                                f"时间: {log_data['time']}\n"
                                f"状态码: {log_data['status']}\n"
                                f"User-Agent: {log_data['useragent']}"
                            )
                            send_bark_notification(title, message)

                file_size = f.tell()

        except Exception as e:
            print(f"监控过程中出错: {str(e)}")

        time.sleep(1)


if __name__ == "__main__":
    monitor_log()
