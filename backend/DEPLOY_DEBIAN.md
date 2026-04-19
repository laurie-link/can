# 🚀 Debian 服务器部署指南

本指南将帮助您在 Debian 服务器上部署粤语学习助手后端服务，使任何手机都能通过互联网访问。

## 📋 前置要求

- Debian 服务器（有公网 IP 或域名）
- SSH 访问权限
- root 或 sudo 权限
- Python 3.9+ 已安装

## 🔧 步骤一：服务器环境准备

### 1.1 更新系统

```bash
sudo apt update
sudo apt upgrade -y
```

### 1.2 安装 Python 和必要工具

```bash
sudo apt install -y python3 python3-pip python3-venv git nginx supervisor
```

### 1.3 配置防火墙

```bash
# 允许 SSH（如果还没配置）
sudo ufw allow 22/tcp

# 允许 HTTP 和 HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 如果需要直接访问 6783 端口（不推荐，建议用 Nginx）
sudo ufw allow 6783/tcp

# 启用防火墙
sudo ufw enable
sudo ufw status
```

## 📦 步骤二：部署应用代码

### 2.1 创建应用目录

```bash
# 创建应用目录
sudo mkdir -p /opt/cantonese-backend
sudo chown $USER:$USER /opt/cantonese-backend
cd /opt/cantonese-backend
```

### 2.2 上传代码

**方法一：使用 Git（推荐）**

```bash
# 如果代码在 Git 仓库
git clone <your-repo-url> .

# 或者直接复制文件
# 使用 scp 从本地电脑上传
# scp -r backend/* user@your-server:/opt/cantonese-backend/
```

**方法二：手动上传**

使用 `scp` 或 `rsync` 将 `backend` 目录上传到服务器：

```bash
# 从本地电脑执行
scp -r backend/* user@your-server:/opt/cantonese-backend/
```

### 2.3 创建虚拟环境

```bash
cd /opt/cantonese-backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## ⚙️ 步骤三：配置应用

### 3.1 创建配置文件

```bash
cd /opt/cantonese-backend
nano config.py
```

添加以下内容：

```python
# 服务器配置
HOST = "0.0.0.0"  # 监听所有网络接口
PORT = 6783
WORKERS = 4  # 根据服务器 CPU 核心数调整

# CORS 配置（生产环境应该限制具体域名）
ALLOWED_ORIGINS = ["*"]  # 或 ["https://yourdomain.com"]

# 日志配置
LOG_LEVEL = "info"
```

### 3.2 修改 main.py（如果需要）

确保 `main.py` 中的 CORS 配置允许来自手机的请求：

```python
# 在 main.py 中
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境建议改为具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 🌐 步骤四：配置 Nginx 反向代理（推荐）

### 4.1 创建 Nginx 配置

```bash
sudo nano /etc/nginx/sites-available/cantonese-backend
```

添加以下配置：

```nginx
server {
    listen 80;
    server_name your-domain.com;  # 替换为您的域名或 IP

    # 如果使用域名，稍后可以配置 SSL
    # server_name api.yourdomain.com;

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:6783;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 静态文件（音频文件）
    location /static/ {
        alias /opt/cantonese-backend/backend/static/;
        expires 1h;
        add_header Cache-Control "public, immutable";
    }
}
```

### 4.2 启用配置

```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/cantonese-backend /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 4.3 配置 SSL（可选但推荐）

使用 Let's Encrypt 免费 SSL 证书：

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取 SSL 证书（需要域名）
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo certbot renew --dry-run
```

## 🔄 步骤五：配置进程管理（Supervisor）

### 5.1 创建 Supervisor 配置

```bash
sudo nano /etc/supervisor/conf.d/cantonese-backend.conf
```

添加以下内容：

```ini
[program:cantonese-backend]
command=/opt/cantonese-backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 6783 --workers 4
directory=/opt/cantonese-backend/backend
user=www-data
autostart=true
autorestart=true
stderr_logfile=/var/log/cantonese-backend/error.log
stdout_logfile=/var/log/cantonese-backend/access.log
environment=PATH="/opt/cantonese-backend/venv/bin"
```

### 5.2 创建日志目录

```bash
sudo mkdir -p /var/log/cantonese-backend
sudo chown www-data:www-data /var/log/cantonese-backend
```

### 5.3 启动服务

```bash
# 重新加载 Supervisor 配置
sudo supervisorctl reread
sudo supervisorctl update

# 启动服务
sudo supervisorctl start cantonese-backend

# 查看状态
sudo supervisorctl status cantonese-backend

# 查看日志
sudo tail -f /var/log/cantonese-backend/access.log
```

## 🧪 步骤六：测试服务

### 6.1 检查服务状态

```bash
# 检查 Supervisor
sudo supervisorctl status cantonese-backend

# 检查 Nginx
sudo systemctl status nginx

# 检查端口
sudo netstat -tlnp | grep 6783
```

### 6.2 测试 API

```bash
# 测试健康检查
curl http://localhost:6783/health

# 测试根路径
curl http://localhost:6783/

# 如果配置了域名，测试外网访问
curl http://your-domain.com/health
```

### 6.3 从手机测试

在手机浏览器或应用中测试：
- `http://your-server-ip/health`
- 或 `https://your-domain.com/health`（如果配置了 SSL）

## 📱 步骤七：配置手机应用

### 7.1 获取服务器地址

**如果有域名：**
```
https://your-domain.com
```

**如果只有 IP：**
```
http://your-server-ip
```

### 7.2 在应用中配置

1. 打开应用 → 设置
2. 配置 AI API（Base URL、API Key、模型）
3. **后端服务器地址**：输入您的服务器地址
   - 例如：`https://api.yourdomain.com`
   - 或：`http://123.456.789.0`（如果只有 IP）

## 🔒 步骤八：安全加固（重要）

### 8.1 限制 CORS（生产环境）

修改 `backend/main.py`：

```python
# 只允许特定域名
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://yourdomain.com",
        "https://app.yourdomain.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
```

### 8.2 配置防火墙规则

```bash
# 只允许必要的端口
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 8.3 设置 API 密钥验证（可选）

可以在后端添加 API 密钥验证，防止未授权访问。

## 🔍 故障排查

### 问题 1：服务无法启动

```bash
# 查看 Supervisor 日志
sudo supervisorctl tail -f cantonese-backend stderr

# 检查 Python 环境
/opt/cantonese-backend/venv/bin/python --version

# 手动测试启动
cd /opt/cantonese-backend/backend
source ../venv/bin/activate
python main.py
```

### 问题 2：无法从外网访问

```bash
# 检查防火墙
sudo ufw status

# 检查 Nginx 配置
sudo nginx -t
sudo systemctl status nginx

# 检查端口监听
sudo netstat -tlnp | grep 6783
sudo netstat -tlnp | grep 80
```

### 问题 3：SSL 证书问题

```bash
# 检查证书
sudo certbot certificates

# 手动续期
sudo certbot renew
```

### 问题 4：音频文件无法访问

```bash
# 检查静态文件目录权限
ls -la /opt/cantonese-backend/backend/static/

# 确保 Nginx 可以访问
sudo chown -R www-data:www-data /opt/cantonese-backend/backend/static/
```

## 📊 监控和维护

### 查看日志

```bash
# Supervisor 日志
sudo tail -f /var/log/cantonese-backend/access.log
sudo tail -f /var/log/cantonese-backend/error.log

# Nginx 日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 重启服务

```bash
# 重启后端
sudo supervisorctl restart cantonese-backend

# 重启 Nginx
sudo systemctl restart nginx
```

### 更新代码

```bash
cd /opt/cantonese-backend
source venv/bin/activate
git pull  # 或手动更新文件
pip install -r requirements.txt
sudo supervisorctl restart cantonese-backend
```

## 🎯 快速部署脚本

创建 `deploy.sh`：

```bash
#!/bin/bash
set -e

echo "🚀 开始部署粤语学习助手后端..."

# 1. 更新代码
cd /opt/cantonese-backend
source venv/bin/activate

# 2. 更新依赖
pip install -r requirements.txt

# 3. 重启服务
sudo supervisorctl restart cantonese-backend

echo "✅ 部署完成！"
```

使用：

```bash
chmod +x deploy.sh
./deploy.sh
```

## 📝 总结

部署完成后，您的服务器将：

✅ 运行 FastAPI 后端服务  
✅ 通过 Nginx 反向代理提供 HTTP/HTTPS 访问  
✅ 使用 Supervisor 管理进程，自动重启  
✅ 支持从任何手机通过互联网访问  

**服务器地址格式：**
- 有域名：`https://your-domain.com`
- 只有 IP：`http://your-server-ip`

在手机应用中配置这个地址即可使用！

