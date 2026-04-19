# 粤学通（Cantonese Learning）

本仓库包含 **Flutter 移动应用**（`cantonese_app/`）与 **FastAPI 粤语助手后端**（`backend/`）。应用提供普通话转粤语、粤拼/注音、粤语解释（大模型）、以及基于后端的语音朗读等功能。

## 目录结构

| 目录 | 说明 |
|------|------|
| `cantonese_app/` | Flutter 客户端（Android / iOS / 桌面等） |
| `backend/` | FastAPI：粤拼、TTS、可选代理说明等 |
| `.github/workflows/ios-ipa.yml` | GitHub Actions：在 macOS 上构建**未签名** iOS IPA（供 Sideloadly 等侧载） |

## 客户端使用说明

1. 使用 Android Studio / VS Code / Flutter SDK 打开 `cantonese_app/`。
2. 运行：`flutter pub get`，然后 `flutter run`。
3. 在应用内 **设置**（右下角齿轮）中配置：
   - **Base URL**：OpenAI 兼容 API 根地址（需以 `/v1` 结尾或应用会自动补全），例如 `https://api.siliconflow.cn/v1`。
   - **API Key**：对应服务商的密钥。
   - **模型**：点击「获取模型列表」后选择，或手动填写模型 ID。
   - **粤语助手后端（粤拼 / 语音）**：客户端已内置默认服务（与 `https://can.aiexplorerxj.top/docs` 为同一套部署；实际请求使用去掉 `/docs` 后的 API 根地址），**无需在设置中填写**。

### 功能说明（简要）

- **翻译**：普通话 → 粤语（大模型），可选粤拼与朗读（依赖后端）。
- **注音**：输入粤语文本，仅调用后端粤拼与 TTS，不经过大模型。
- **解释**：粤语内容详解（大模型）；支持流式输出与部分模型的「思考」字段展示。

### 从设置返回后配置不生效？

已修复：从设置页返回首页时，各 Tab 会**自动重新读取**本地保存的 API Key 与模型，无需冷启动。

---

## 后端搭建（粤语助手 API）

详细接口与字段说明见 [`backend/README.md`](backend/README.md)。

### 最简步骤

```bash
cd backend
pip install -r requirements.txt
python main.py
# 或: uvicorn main:app --host 0.0.0.0 --port 6783
```

默认文档：<http://localhost:6783/docs>  

生产环境请：

- 使用 **HTTPS**（反向代理如 Nginx + Let’s Encrypt），应用商店审核通常**不鼓励**明文 HTTP 传输用户数据或 API 调用。
- 按需限制 CORS、配置防火墙与密钥管理。

---

## 打包

### Android APK（本机 Windows / macOS / Linux 均可）

```bash
cd cantonese_app
flutter pub get
flutter build apk --release
```

产物：`cantonese_app/build/app/outputs/flutter-apk/app-release.apk`。

### 应用图标

源图：`cantonese_app/assets/logo.png`。修改图标后请重新生成各平台 launcher 图标：

```bash
cd cantonese_app
dart run flutter_launcher_icons
```

然后再执行 `flutter build apk` / `flutter build ios`，否则安装包仍可能使用旧图标。

### iOS IPA

- **本机**：需在 **macOS + Xcode** 下于 `cantonese_app` 中执行 `flutter build ipa`（或 Archive），并配置签名与证书。
- **CI**：推送至 GitHub 后，在仓库 **Actions** 中运行 **Build unsigned iOS IPA (Sideloadly)**，在 Artifacts 中下载未签名 IPA（供个人侧载，**非** App Store 上架包）。

---

## 上架与审核（Google Play / App Store）

以下为常见注意点，**不构成法律或审核承诺**：

1. **图标**：需符合各平台尺寸与内容规范；本仓库已配置 `flutter_launcher_icons` 的 `remove_alpha_ios: true` 以符合 iOS 对图标透明通道的常见要求。若 `logo.png` 含第三方商标或敏感内容，请自行调整。
2. **HTTP 后端**：客户端连接 **HTTP** 存在明文传输与中间人风险；商店审核常要求敏感数据走 **HTTPS**、隐私政策中说明数据收集与传输方式。若仅作演示，建议说明「用户自行部署后端」或提供 HTTPS 端点。
3. **隐私政策与权限**：若使用麦克风、网络、存储等，请在商店资料与隐私政策中声明用途。
4. **大模型 API**：若使用第三方 AI 服务，建议在应用内或商店说明中披露数据来源与合规要求。

---

## 开源协议与贡献

以仓库内实际 LICENSE 为准（若未添加，请自行补充）。
