import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _backendUrlController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isSaving = false;
  bool _isLoadingModels = false;
  bool _enableJyutping = true;
  bool _enableTts = true;

  List<String> _availableModels = [];
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _baseUrlController.text = prefs.getString('base_url') ?? 'https://api.siliconflow.cn/v1';
      _backendUrlController.text = prefs.getString('backend_url') ?? '';
      _enableJyutping = prefs.getBool('enable_jyutping') ?? true;
      _enableTts = prefs.getBool('enable_tts') ?? true;
      _selectedModel = prefs.getString('model_name');
    });
  }

  Future<void> _persistFeatureFlags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_jyutping', _enableJyutping);
    await prefs.setBool('enable_tts', _enableTts);
  }

  Future<void> _fetchModels() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入 API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_baseUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入 Base URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingModels = true;
      _availableModels = [];
      _selectedModel = null;
    });

    try {
      final models = await _apiService.getModels(
        apiKey: _apiKeyController.text,
        baseUrlApi: _baseUrlController.text,
      );

      setState(() {
        _availableModels = models;
        if (models.isNotEmpty) {
          _selectedModel = models[0];
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功获取 ${models.length} 个模型'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取模型列表失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入 API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_baseUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入 Base URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedModel == null || _selectedModel!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择或输入模型名称'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_key', _apiKeyController.text);
      await prefs.setString('base_url', _baseUrlController.text);
      await prefs.setString('backend_url', _backendUrlController.text.trim());
      await prefs.setBool('enable_jyutping', _enableJyutping);
      await prefs.setBool('enable_tts', _enableTts);
      await prefs.setString('model_name', _selectedModel!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API 配置说明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'API 配置说明',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '本应用需要调用 AI API 才能使用翻译和解释功能。\n'
                    '翻译页的粤拼与朗读可在下方开关中单独开启；开启时需要可访问的自建后端（FastAPI）。\n\n'
                    '支持 OpenAI 兼容的 API 服务，如：\n'
                    '• SiliconFlow (https://api.siliconflow.cn/v1)\n'
                    '• OpenAI (https://api.openai.com/v1)\n'
                    '• 其他兼容服务',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Base URL 输入
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL *',
                border: OutlineInputBorder(),
                hintText: 'https://api.siliconflow.cn/v1',
                prefixIcon: Icon(Icons.link),
              ),
            ),

            const SizedBox(height: 16),

            // 后端服务（粤拼 + 语音）
            TextField(
              controller: _backendUrlController,
              decoration: InputDecoration(
                labelText: '后端服务地址（粤拼 / 语音）',
                border: const OutlineInputBorder(),
                hintText: 'http://154.217.244.39:6783',
                prefixIcon: const Icon(Icons.cloud),
                helperText: (_enableJyutping || _enableTts)
                    ? '需可访问 /api/jyutping 与 /api/audio；与仓库 backend 部署一致'
                    : '已关闭粤拼与语音时可不填',
              ),
            ),

            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('翻译页：粤拼标注', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('开启后调用后端生成粤拼（需后端可用）', style: TextStyle(fontSize: 12)),
              value: _enableJyutping,
              onChanged: (v) async {
                setState(() => _enableJyutping = v);
                await _persistFeatureFlags();
              },
              activeThumbColor: Colors.red.shade700,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            SwitchListTile(
              title: const Text('翻译页：语音朗读', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('开启后调用后端 edge-tts 生成音频', style: TextStyle(fontSize: 12)),
              value: _enableTts,
              onChanged: (v) async {
                setState(() => _enableTts = v);
                await _persistFeatureFlags();
              },
              activeThumbColor: Colors.red.shade700,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),

            const SizedBox(height: 16),

            // API Key 输入
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key *',
                border: OutlineInputBorder(),
                hintText: '输入你的 API Key',
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),

            const SizedBox(height: 16),

            // 获取模型列表按钮
            ElevatedButton.icon(
              onPressed: _isLoadingModels ? null : _fetchModels,
              icon: _isLoadingModels
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isLoadingModels ? '获取中...' : '获取模型列表'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // 模型选择下拉框
            if (_availableModels.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: const InputDecoration(
                  labelText: '选择模型 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.model_training),
                ),
                items: _availableModels.map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(
                      model,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value;
                  });
                },
              )
            else
              // 如果没有模型列表，显示手动输入框
              TextField(
                decoration: const InputDecoration(
                  labelText: '模型名称 *',
                  border: OutlineInputBorder(),
                  hintText: '点击上方按钮获取模型列表',
                  prefixIcon: Icon(Icons.model_training),
                ),
                enabled: false,
              ),

            const SizedBox(height: 24),

            // 保存按钮
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('保存设置', style: TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 24),

            // 当前配置信息
            if (_selectedModel != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          '当前配置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildConfigItem('Base URL', _baseUrlController.text),
                    if (_backendUrlController.text.isNotEmpty)
                      _buildConfigItem('后端', _backendUrlController.text),
                    _buildConfigItem('API Key', '${_apiKeyController.text.substring(0, 8)}...'),
                    _buildConfigItem('模型', _selectedModel ?? '未选择'),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 关于
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '关于',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '粤语学习助手 v1.0.0\n\n'
                    '功能：\n'
                    '• 普通话转粤语（模型）\n'
                    '• 可选：粤拼（后端）与朗读（后端）\n'
                    '• 粤语解释（模型）',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }
}
