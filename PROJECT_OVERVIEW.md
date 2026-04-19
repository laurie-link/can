# 粤语学习助手 - 移动端项目总览

从 Streamlit Web 应用成功改造为前后端分离的移动应用架构。

## 项目架构

```
cantonese/
├── app_integrated.py          # 原始 Streamlit Web 应用（保留）
├── requirements.txt           # 原始依赖
│
├── backend/                   # FastAPI 后端（新增）
│   ├── main.py               # API 主应用
│   ├── requirements.txt      # 后端依赖
│   ├── README.md            # 后端文档
│   ├── .gitignore
│   ├── models/
│   │   └── schemas.py       # 数据模型
│   ├── services/
│   │   ├── translation.py   # 翻译服务
│   │   ├── jyutping.py      # 粤拼标注
│   │   └── audio.py         # 语音生成
│   └── static/
│       └── audio/           # 音频文件
│
├── FLUTTER_GUIDE.md          # Flutter 前端开发指南
└── PROJECT_OVERVIEW.md       # 本文档
```

## 技术栈

### 后端 (Backend)
- **FastAPI**: 高性能 Web 框架
- **PyCantonese**: 粤语语言处理
- **Edge-TTS**: 语音合成
- **Uvicorn**: ASGI 服务器

### 前端 (推荐 Flutter)
- **Flutter**: Google 跨平台 UI 框架
- **Dart**: 编程语言
- **HTTP/Dio**: 网络请求
- **Provider/Riverpod**: 状态管理
- **AudioPlayers**: 音频播放

## 功能对比

| 功能 | Streamlit 版本 | 移动端版本 |
|------|---------------|-----------|
| 普通话转粤语 | ✅ | ✅ API 实现 |
| 俚语模式 | ✅ | ✅ API 实现 |
| 粤拼标注 | ✅ | ✅ API 实现 |
| 粤语解释 | ✅ | ✅ API 实现 |
| 语音生成 | ✅ | ✅ API 实现 |
| 对话历史 | ✅ | 待前端实现 |
| 离线使用 | ❌ | 可实现（缓存） |
| 推送通知 | ❌ | 可实现 |

## 快速开始

### 1. 启动后端

```bash
# 进入后端目录
cd backend

# 安装依赖
pip install -r requirements.txt

# 启动服务
python main.py

# 访问 API 文档
# http://localhost:8000/docs
```

### 2. 开发前端（Flutter）

详见 `FLUTTER_GUIDE.md`

```bash
# 创建项目
flutter create cantonese_app

# 运行
cd cantonese_app
flutter run
```

## API 端点

### 基础信息

- **Base URL**: `http://localhost:8000`
- **文档**: `/docs` (Swagger UI)

### 端点列表

| 方法 | 路径 | 功能 |
|------|------|------|
| GET | `/` | API 信息 |
| GET | `/health` | 健康检查 |
| POST | `/api/models` | 获取模型列表 |
| POST | `/api/translate` | 普通话转粤语 |
| POST | `/api/jyutping` | 粤拼标注 |
| POST | `/api/explain` | 粤语解释 |
| POST | `/api/audio` | 语音生成 |

详细 API 文档见 `backend/README.md`

## 部署方案

### 后端部署

**选项 1: Docker**
```bash
cd backend
docker build -t cantonese-api .
docker run -p 8000:8000 cantonese-api
```

**选项 2: 云平台**
- Render: https://render.com
- Railway: https://railway.app
- Fly.io: https://fly.io
- AWS/Azure/GCP

**选项 3: VPS**
- 使用 Nginx + Uvicorn
- 配置 HTTPS (Let's Encrypt)
- 使用 systemd 或 supervisor 管理进程

### 前端部署

**Android:**
```bash
flutter build apk --release
# 发布到 Google Play Store
```

**iOS:**
```bash
flutter build ios --release
# 在 Xcode 中签名并发布到 App Store
```

## 开发路线图

### Phase 1: 后端 API（已完成 ✅）
- [x] 提取业务逻辑
- [x] 实现 FastAPI 端点
- [x] 添加 CORS 支持
- [x] API 文档

### Phase 2: Flutter 前端（进行中）
- [ ] 创建项目结构
- [ ] 实现翻译页面
- [ ] 实现粤拼页面
- [ ] 实现解释页面
- [ ] 实现设置页面
- [ ] 添加音频播放
- [ ] 本地存储集成

### Phase 3: 优化和发布
- [ ] UI/UX 优化
- [ ] 性能优化
- [ ] 错误处理
- [ ] 单元测试
- [ ] 应用图标和启动页
- [ ] 发布到应用商店

### Phase 4: 高级功能
- [ ] 离线缓存
- [ ] 收藏功能
- [ ] 学习进度追踪
- [ ] 社交分享
- [ ] 推送通知
- [ ] 暗黑模式

## 注意事项

### 安全性

1. **API 密钥管理**
   - 不要硬编码在前端
   - 使用本地安全存储（Keychain/Keystore）
   - 考虑实现自己的认证系统

2. **CORS 配置**
   - 生产环境限制允许的域名
   - 在 `backend/main.py` 中修改

3. **HTTPS**
   - 生产环境必须使用 HTTPS
   - 配置 SSL 证书

### 性能优化

1. **后端**
   - 使用 Redis 缓存翻译结果
   - 定期清理过期音频文件
   - 限流和请求配额

2. **前端**
   - 图片懒加载
   - 音频预加载
   - 分页加载历史记录

### 成本控制

- AI API 调用成本（按使用量计费）
- 服务器托管费用
- 存储费用（音频文件）

建议：
- 实现缓存减少 API 调用
- 定期清理临时文件
- 使用免费层级服务（Render, Railway）

## 测试

### 后端测试

```bash
cd backend

# 安装测试依赖
pip install pytest pytest-asyncio httpx

# 运行测试
pytest
```

### 前端测试

```bash
cd cantonese_app

# 单元测试
flutter test

# 集成测试
flutter test integration_test/
```

## 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

MIT License

## 联系方式

如有问题或建议，欢迎提交 Issue。

---

## 下一步行动

### 立即开始

1. **测试后端 API**
   ```bash
   cd backend
   pip install -r requirements.txt
   python main.py
   ```
   访问 http://localhost:8000/docs 测试 API

2. **创建 Flutter 项目**
   ```bash
   flutter create cantonese_app
   ```
   参考 `FLUTTER_GUIDE.md` 开始开发

3. **配置 API 密钥**
   - 获取 API 密钥（如 SiliconFlow）
   - 在应用中配置

### 需要帮助？

- 后端问题：查看 `backend/README.md`
- Flutter 开发：查看 `FLUTTER_GUIDE.md`
- API 文档：http://localhost:8000/docs

祝开发顺利！
