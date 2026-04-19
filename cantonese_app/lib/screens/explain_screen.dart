import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({super.key});

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _explanation = '';

  String _apiKey = '';
  String _modelName = '';
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
      _modelName = prefs.getString('model_name') ?? '';
      _baseUrl = prefs.getString('base_url') ?? 'https://api.siliconflow.cn/v1';
    });
  }

  Future<void> _explain() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要解释的粤语内容')),
      );
      return;
    }

    if (_apiKey.isEmpty || _modelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 API Key 和模型')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _explanation = '';
    });

    try {
      final result = await _apiService.explain(
        text: _textController.text,
        apiKey: _apiKey,
        modelName: _modelName,
        baseUrlApi: _baseUrl,
      );

      setState(() {
        _explanation = result['explanation'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解释失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clear() {
    setState(() {
      _textController.clear();
      _explanation = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('粤语解释'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 输入框
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: '输入粤语（词汇或句子）',
                border: OutlineInputBorder(),
                hintText: '例如：乜嘢、搵食、你做緊乜？',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 按钮行
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _explain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('获取解释', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _clear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                  ),
                  child: const Text('清空', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 结果显示
            if (_explanation.isNotEmpty) ...[
              const Text(
                '📖 AI 解释',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(
                    data: _explanation,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 15, height: 1.6),
                      h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      listBullet: const TextStyle(fontSize: 15, height: 1.6),
                      code: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        backgroundColor: Colors.grey.shade200,
                      ),
                      blockquote: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.grey.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // 使用说明
            if (_explanation.isEmpty && !_isLoading) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTip('在上方文本框输入您想了解的粤语词汇或句子'),
                    _buildTip('点击"获取解释"按钮'),
                    _buildTip('AI 会用普通话详细解释这个粤语表达'),
                    _buildTip('包括含义、用法、文化背景等信息'),
                    const SizedBox(height: 12),
                    Text(
                      '适用场景：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScenario('不理解某个粤语词汇的含义'),
                    _buildScenario('想知道粤语俚语的文化背景'),
                    _buildScenario('学习粤语日常用语'),
                    _buildScenario('了解粤语与普通话的对应关系'),
                    const SizedBox(height: 12),
                    Text(
                      '示例：',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '输入：乜嘢\n解释：AI 会告诉您"乜嘢"的意思是"什么"，以及如何使用',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
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
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenario(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
