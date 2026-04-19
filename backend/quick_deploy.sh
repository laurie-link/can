#!/bin/bash
# 快速部署脚本 - Debian 服务器
# 使用方法: sudo bash quick_deploy.sh

set -e

echo "🚀 开始部署粤语学习助手后端服务..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 配置变量
APP_DIR="/opt/cantonese-backend"
APP_USER="www-data"
DOMAIN=""  # 如果有域名，在这里设置

echo -e "${YELLOW}步骤 1/7: 更新系统包...${NC}"
apt update && apt upgrade -y

echo -e "${YELLOW}步骤 2/7: 安装必要软件...${NC}"
apt install -y python3 python3-pip python3-venv git nginx supervisor ufw

echo -e "${YELLOW}步骤 3/7: 配置防火墙...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "${YELLOW}步骤 4/7: 创建应用目录...${NC}"
mkdir -p $APP_DIR
mkdir -p $APP_DIR/backend/static/audio
chown -R $APP_USER:$APP_USER $APP_DIR

echo -e "${YELLOW}步骤 5/7: 设置 Python 环境...${NC}"
cd $APP_DIR
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip

echo -e "${GREEN}✅ 基础环境配置完成！${NC}"
echo -e "${YELLOW}请手动执行以下步骤：${NC}"
echo ""
echo "1. 将 backend 目录的文件上传到 $APP_DIR/backend/"
echo "2. 运行: cd $APP_DIR && source venv/bin/activate && pip install -r requirements.txt"
echo "3. 运行: bash setup_supervisor.sh"
echo "4. 运行: bash setup_nginx.sh"
echo ""
echo "或者继续运行完整配置脚本..."

read -p "是否继续配置 Supervisor 和 Nginx? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}步骤 6/7: 配置 Supervisor...${NC}"
    
    # 创建日志目录
    mkdir -p /var/log/cantonese-backend
    chown $APP_USER:$APP_USER /var/log/cantonese-backend
    
    # 创建 Supervisor 配置
    cat > /etc/supervisor/conf.d/cantonese-backend.conf << EOF
[program:cantonese-backend]
command=$APP_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 6783 --workers 4
directory=$APP_DIR/backend
user=$APP_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/cantonese-backend/error.log
stdout_logfile=/var/log/cantonese-backend/access.log
environment=PATH="$APP_DIR/venv/bin"
EOF

    supervisorctl reread
    supervisorctl update
    
    echo -e "${YELLOW}步骤 7/7: 配置 Nginx...${NC}"
    
    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 创建 Nginx 配置
    cat > /etc/nginx/sites-available/cantonese-backend << EOF
server {
    listen 80;
    server_name $SERVER_IP ${DOMAIN:-_};

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:6783;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /static/ {
        alias $APP_DIR/backend/static/;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # 启用站点
    ln -sf /etc/nginx/sites-available/cantonese-backend /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试并重启 Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    echo -e "${GREEN}✅ 配置完成！${NC}"
    echo ""
    echo "服务器地址: http://$SERVER_IP"
    if [ ! -z "$DOMAIN" ]; then
        echo "域名地址: http://$DOMAIN"
    fi
    echo ""
    echo "下一步："
    echo "1. 将 backend 目录的文件复制到 $APP_DIR/backend/"
    echo "2. 运行: cd $APP_DIR && source venv/bin/activate && pip install -r requirements.txt"
    echo "3. 运行: supervisorctl start cantonese-backend"
    echo "4. 在手机应用中配置后端地址: http://$SERVER_IP"
fi

echo -e "${GREEN}🎉 部署脚本执行完成！${NC}"

