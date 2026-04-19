# 粤语学习助手 API 后端

基于 FastAPI 构建的 RESTful API，为粤语学习助手移动应用提供后端服务。

## 功能特性

- 普通话转粤语翻译（标准版 + 俚语版）
- 粤语拼音自动标注
- 粤语词汇/句子解释
- 粤语语音生成（基于 Edge-TTS）
- 获取可用 AI 模型列表

## 技术栈

- **FastAPI**: 现代高性能 Web 框架
- **PyCantonese**: 粤语语言处理库
- **Edge-TTS**: 微软边缘语音合成
- **Pydantic**: 数据验证
- **Uvicorn**: ASGI 服务器

## 项目结构

```
backend/
├── main.py                 # FastAPI 主应用
├── requirements.txt        # Python 依赖
├── models/
│   └── schemas.py         # 数据模型定义
├── services/
│   ├── translation.py     # 翻译服务
│   ├── jyutping.py        # 粤拼标注服务
│   └── audio.py           # 语音生成服务
└── static/
    └── audio/             # 生成的音频文件存储
```

## 快速开始

### 1. 安装依赖

```bash
cd backend
pip install -r requirements.txt
```

### 2. 启动服务

```bash
# 开发模式（支持热重载）
python main.py

# 或使用 uvicorn 命令
uvicorn main:app --reload --host 0.0.0.0 --port 6783
```

### 3. 访问 API 文档

启动后访问：
- Swagger UI: http://localhost:6783/docs
- ReDoc: http://localhost:6783/redoc

## API 端点

### 1. 获取模型列表

**POST** `/api/models`

请求体：
```json
{
  "api_key": "your-api-key",
  "base_url": "https://api.siliconflow.cn/v1"
}
```

响应：
```json
{
  "models": ["model1", "model2", ...]
}
```

### 2. 普通话转粤语

**POST** `/api/translate`

请求体：
```json
{
  "text": "你好吗？",
  "api_key": "your-api-key",
  "model_name": "deepseek-ai/DeepSeek-V3",
  "base_url": "https://api.siliconflow.cn/v1",
  "slang_mode": true
}
```

响应：
```json
{
  "cantonese": "你好唔好呀？",
  "jyutping": "nei5(你) hou2(好) m4(唔) hou2(好) aa3(呀) ？",
  "slang": "點呀？",
  "slang_jyutping": "dim2(點) aa3(呀) ？",
  "note": "粤语中..."
}
```

### 3. 粤拼标注

**POST** `/api/jyutping`

请求体：
```json
{
  "text": "你好"
}
```

响应：
```json
{
  "original": "你好",
  "jyutping": "nei5(你) hou2(好)"
}
```

### 4. 粤语解释

**POST** `/api/explain`

请求体：
```json
{
  "text": "乜嘢",
  "api_key": "your-api-key",
  "model_name": "deepseek-ai/DeepSeek-V3",
  "base_url": "https://api.siliconflow.cn/v1"
}
```

响应：
```json
{
  "explanation": "详细的粤语解释..."
}
```

### 5. 语音生成

**POST** `/api/audio`

请求体：
```json
{
  "text": "你好",
  "voice": "zh-HK-HiuMaanNeural"
}
```

响应：
```json
{
  "audio_url": "/static/audio/xxx.mp3",
  "message": "语音生成成功"
}
```

可用语音选项：
- `zh-HK-HiuMaanNeural` - 晓曼（女声）
- `zh-HK-HiuGaaiNeural` - 晓佳（女声）
- `zh-HK-WanLungNeural` - 云龙（男声）

## 环境变量

可选的环境变量配置：

```bash
# API 默认配置
export API_BASE_URL="https://api.siliconflow.cn/v1"
export API_KEY="your-default-api-key"
```

## 部署

### Docker 部署（推荐）

创建 `Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 6783

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "6783"]
```

构建和运行：

```bash
docker build -t cantonese-api .
docker run -p 6783:6783 cantonese-api
```

### 云平台部署

支持部署到：
- Render
- Railway
- Fly.io
- AWS / Azure / Google Cloud

## 注意事项

1. **CORS 配置**: 生产环境请在 `main.py` 中修改 CORS 允许的域名
2. **音频文件清理**: 系统会自动清理超过 24 小时的音频文件
3. **API 密钥安全**: 请妥善保管 API 密钥，不要硬编码在客户端

## 开发调试

启用调试模式：

```bash
uvicorn main:app --reload --log-level debug
```

查看实时日志来调试 API 请求。

## License

MIT License
