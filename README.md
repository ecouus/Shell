## 开源一键可视化shell脚本
# 安装weget curl依赖包  
yum update -y && yum install curl -y #CentOS/Fedora  
apt-get update -y && apt-get install curl -y #Debian/Ubuntu  
# 远程下载代码  
curl -sS -O https://raw.githubusercontent.com/ecouus/Shell/main/ecouu.sh && sudo chmod +x ecouu.sh && ./ecouu.sh
ln -sf ~/ecouu.sh /usr/local/bin/e