# Flutter 前端开发指南

本指南将帮助你使用 Flutter 为粤语学习助手开发移动端应用。

## 前置要求

1. **安装 Flutter SDK**
   - 下载：https://flutter.dev/docs/get-started/install
   - 配置环境变量
   - 验证安装：`flutter doctor`

2. **安装开发工具**
   - Android Studio（Android 开发）
   - Xcode（iOS 开发，仅 macOS）
   - VS Code + Flutter 插件（推荐）

3. **后端 API 运行**
   - 确保后端 API 已启动（`cd backend && python main.py`）
   - API 地址：http://localhost:8000

## 创建 Flutter 项目

```bash
# 创建新项目
flutter create cantonese_app
cd cantonese_app

# 测试运行
flutter run
```

## 项目结构

```
cantonese_app/
├── lib/
│   ├── main.dart              # 应用入口
│   ├── models/                # 数据模型
│   │   ├── translate_request.dart
│   │   ├── translate_response.dart
│   │   └── ...
│   ├── services/              # API 服务
│   │   └── api_service.dart
│   ├── screens/               # 页面
│   │   ├── home_screen.dart
│   │   ├── translate_screen.dart
│   │   ├── jyutping_screen.dart
│   │   └── explain_screen.dart
│   ├── widgets/               # 组件
│   │   ├── audio_player.dart
│   │   └── ...
│   └── utils/                 # 工具类
│       └── constants.dart
├── pubspec.yaml               # 依赖配置
└── android/ios/              # 平台特定配置
```

## 添加依赖

编辑 `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # HTTP 请求
  http: ^1.1.0
  dio: ^5.4.0

  # 状态管理
  provider: ^6.1.1
  # 或使用 riverpod: ^2.4.9
  # 或使用 bloc: ^8.1.3

  # 音频播放
  audioplayers: ^5.2.1

  # 本地存储
  shared_preferences: ^2.2.2

  # UI 组件
  flutter_spinkit: ^5.2.0

  # JSON 序列化
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

运行：
```bash
flutter pub get
```

## 核心代码示例

### 1. API 服务类 (lib/services/api_service.dart)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // 本地开发：使用 10.0.2.2（Android 模拟器）或实际 IP
  // 生产环境：替换为实际服务器地址
  static const String baseUrl = 'http://10.0.2.2:8000';

  // 翻译 API
  Future<Map<String, dynamic>> translate({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
    bool slangMode = false,
  }) async {
    final url = Uri.parse('$baseUrl/api/translate');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'api_key': apiKey,
        'model_name': modelName,
        'base_url': baseUrlApi,
        'slang_mode': slangMode,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('翻译失败: ${response.body}');
    }
  }

  // 粤拼标注 API
  Future<Map<String, dynamic>> jyutping(String text) async {
    final url = Uri.parse('$baseUrl/api/jyutping');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('粤拼标注失败');
    }
  }

  // 粤语解释 API
  Future<Map<String, dynamic>> explain({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
  }) async {
    final url = Uri.parse('$baseUrl/api/explain');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'api_key': apiKey,
        'model_name': modelName,
        'base_url': baseUrlApi,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('解释失败');
    }
  }

  // 语音生成 API
  Future<String> generateAudio(String text, {String voice = 'zh-HK-HiuMaanNeural'}) async {
    final url = Uri.parse('$baseUrl/api/audio');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'voice': voice,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return '$baseUrl${data['audio_url']}';
    } else {
      throw Exception('语音生成失败');
    }
  }

  // 获取模型列表 API
  Future<List<String>> getModels({
    required String apiKey,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
  }) async {
    final url = Uri.parse('$baseUrl/api/models');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'api_key': apiKey,
        'base_url': baseUrlApi,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['models']);
    } else {
      throw Exception('获取模型列表失败');
    }
  }
}
```

### 2. 翻译页面示例 (lib/screens/translate_screen.dart)

```dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({Key? key}) : super(key: key);

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = false;
  bool _slangMode = true;

  String _cantonese = '';
  String _jyutping = '';
  String? _slang;
  String? _slangJyutping;
  String? _note;
  String? _audioUrl;
  String? _slangAudioUrl;

  // 从 SharedPreferences 读取
  String _apiKey = '';
  String _modelName = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    // 从本地存储加载 API 配置
    // 使用 shared_preferences
  }

  Future<void> _translate() async {
    if (_textController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.translate(
        text: _textController.text,
        apiKey: _apiKey,
        modelName: _modelName,
        slangMode: _slangMode,
      );

      setState(() {
        _cantonese = result['cantonese'];
        _jyutping = result['jyutping'];
        _slang = result['slang'];
        _slangJyutping = result['slang_jyutping'];
        _note = result['note'];
      });

      // 生成语音
      if (_cantonese.isNotEmpty) {
        final audioUrl = await _apiService.generateAudio(_cantonese);
        setState(() {
          _audioUrl = audioUrl;
        });
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('翻译失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _playAudio(String? url) async {
    if (url == null) return;
    await _audioPlayer.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('普通话转粤语'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 打开设置页面
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 输入框
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: '输入普通话',
                border: OutlineInputBorder(),
                hintText: '例如：你在干什么？',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 俚语模式开关
            SwitchListTile(
              title: const Text('启用地道俚语/黑话'),
              value: _slangMode,
              onChanged: (value) {
                setState(() {
                  _slangMode = value;
                });
              },
            ),

            // 翻译按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _translate,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('翻译'),
            ),

            const SizedBox(height: 24),

            // 结果显示
            if (_cantonese.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标准版
                      Text(
                        _slang != null ? '📖 标准口语' : '粤语翻译',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _cantonese,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          if (_audioUrl != null)
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              onPressed: () => _playAudio(_audioUrl),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _jyutping,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),

                      // 俚语版（如果有）
                      if (_slang != null && _slang!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          '🔥 地道黑话',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _slang!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        if (_slangJyutping != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _slangJyutping!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],

                      // 文化注释
                      if (_note != null && _note!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _note!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
```

### 3. 主应用入口 (lib/main.dart)

```dart
import 'package:flutter/material.dart';
import 'screens/translate_screen.dart';
import 'screens/jyutping_screen.dart';
import 'screens/explain_screen.dart';

void main() {
  runApp(const CantoneseApp());
}

class CantoneseApp extends StatelessWidget {
  const CantoneseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '粤语学习助手',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TranslateScreen(),
    const JyutpingScreen(),
    const ExplainScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: '翻译',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.text_fields),
            label: '粤拼',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: '解释',
          ),
        ],
      ),
    );
  }
}
```

## 运行和调试

### 1. 连接后端 API

在 Android 模拟器中：
```dart
static const String baseUrl = 'http://10.0.2.2:8000';
```

在真机上（替换为电脑实际 IP）：
```dart
static const String baseUrl = 'http://192.168.1.100:8000';
```

### 2. 运行应用

```bash
# 查看可用设备
flutter devices

# 在特定设备上运行
flutter run -d <device_id>

# Android
flutter run -d android

# iOS (仅 macOS)
flutter run -d ios
```

### 3. 调试

```bash
# 热重载
r

# 热重启
R

# 查看日志
flutter logs
```

## 打包发布

### Android APK

```bash
# 构建 APK
flutter build apk --release

# 生成的文件位于：
# build/app/outputs/flutter-apk/app-release.apk
```

### iOS App (仅 macOS)

```bash
# 构建 iOS
flutter build ios --release

# 在 Xcode 中打开进行签名和发布
open ios/Runner.xcworkspace
```

## 状态管理建议

推荐使用 **Provider** 或 **Riverpod** 进行状态管理：

### 使用 Provider 示例：

```dart
// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  String _apiKey = '';
  String _modelName = '';
  String _baseUrl = 'https://api.siliconflow.cn/v1';

  String get apiKey => _apiKey;
  String get modelName => _modelName;
  String get baseUrl => _baseUrl;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    _modelName = prefs.getString('model_name') ?? '';
    _baseUrl = prefs.getString('base_url') ?? 'https://api.siliconflow.cn/v1';
    notifyListeners();
  }

  Future<void> saveSettings({
    required String apiKey,
    required String modelName,
    required String baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
    await prefs.setString('model_name', modelName);
    await prefs.setString('base_url', baseUrl);

    _apiKey = apiKey;
    _modelName = modelName;
    _baseUrl = baseUrl;
    notifyListeners();
  }
}
```

在 main.dart 中注册：

```dart
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider()..loadSettings(),
      child: const CantoneseApp(),
    ),
  );
}
```

## 下一步

1. 完善其他页面（粤拼标注、粤语解释）
2. 添加设置页面（保存 API 配置）
3. 实现对话历史记录功能
4. 优化 UI/UX 设计
5. 添加错误处理和加载状态
6. 进行性能优化
7. 准备应用图标和启动屏幕
8. 提交到 App Store / Google Play

## 常见问题

**Q: 无法连接后端 API？**
A: 确保后端正在运行，检查防火墙设置，使用正确的 IP 地址。

**Q: 音频无法播放？**
A: 检查网络连接，确保音频 URL 正确，检查音频播放器权限。

**Q: 如何处理中文显示问题？**
A: 确保使用 UTF-8 编码，在 API 响应中使用 `utf8.decode(response.bodyBytes)`。

## 资源链接

- Flutter 官方文档：https://flutter.dev/docs
- Flutter 中文网：https://flutter.cn
- Pub.dev 包管理：https://pub.dev
- API 设计参考：backend/README.md
