import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../route_observer.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({super.key});

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> with RouteAware {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String _explanation = '';
  String _reasoningText = '';

  /// 是否展示「思考」文本（流式 reasoning_content 等）
  bool _showReasoning = true;

  /// 0 关闭 / 1 轻 / 2 中 / 3 重：影响流式请求的 temperature、max_tokens
  int _reasoningDepth = 2;

  int _elapsedSec = 0;
  Timer? _elapsedTimer;

  String _apiKey = '';
  String _modelName = '';
  String _baseUrl = '';

  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _elapsedTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var depth = prefs.getInt('explain_reasoning_depth');
    final migrated = prefs.getBool('explain_reasoning_4level') ?? false;
    if (!migrated) {
      if (depth == null) {
        depth = 2;
        await prefs.setInt('explain_reasoning_depth', depth);
      } else if (depth >= 0 && depth <= 2) {
        depth = depth + 1;
        await prefs.setInt('explain_reasoning_depth', depth);
      }
      await prefs.setBool('explain_reasoning_4level', true);
    }
    final int resolvedDepth = ((depth ?? 2).clamp(0, 3) as num).toInt();
    setState(() {
      _prefsLoaded = true;
      _apiKey = prefs.getString('api_key') ?? '';
      _modelName = prefs.getString('model_name') ?? '';
      _baseUrl = prefs.getString('base_url') ?? 'https://api.siliconflow.cn/v1';
      _showReasoning = prefs.getBool('explain_show_reasoning') ?? true;
      _reasoningDepth = resolvedDepth;
    });
  }

  Future<void> _persistExplainUiPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('explain_show_reasoning', _showReasoning);
    await prefs.setInt('explain_reasoning_depth', _reasoningDepth);
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

    await _loadSettings();

    _elapsedTimer?.cancel();
    setState(() {
      _isLoading = true;
      _explanation = '';
      _reasoningText = '';
      _elapsedSec = 0;
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSec++);
    });

    final contentBuf = StringBuffer();
    final reasoningBuf = StringBuffer();

    Future<void> fallbackNonStream() async {
      final result = await _apiService.explain(
        text: _textController.text,
        apiKey: _apiKey,
        modelName: _modelName,
        baseUrlApi: _baseUrl,
      );
      if (mounted) {
        setState(() {
          _explanation = (result['explanation'] ?? '').toString();
        });
      }
    }

    try {
      var streamFailed = false;
      await for (final chunk in _apiService.explainStream(
        text: _textController.text,
        apiKey: _apiKey,
        modelName: _modelName,
        baseUrlApi: _baseUrl,
        reasoningDepth: _reasoningDepth,
      )) {
        if (!mounted) return;
        if (chunk.error != null) {
          streamFailed = true;
          break;
        }
        if (chunk.contentDelta != null) {
          contentBuf.write(chunk.contentDelta);
        }
        if (chunk.reasoningDelta != null) {
          reasoningBuf.write(chunk.reasoningDelta);
        }
        setState(() {
          _explanation = contentBuf.toString();
          _reasoningText = reasoningBuf.toString();
        });
        if (chunk.done) break;
      }

      if (!mounted) return;

      // 流失败或正文始终为空时，回退到非流式请求（部分服务商不支持 stream）
      if (streamFailed || contentBuf.isEmpty) {
        await fallbackNonStream();
      }
    } catch (e) {
      if (mounted) {
        try {
          await fallbackNonStream();
        } catch (e2) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('解释失败: $e2')),
          );
        }
      }
    } finally {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clear() {
    setState(() {
      _textController.clear();
      _explanation = '';
      _reasoningText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('粤语解释'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
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
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 8),
                      child: Text(
                        '生成选项',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: const Text('显示思考过程'),
                      subtitle: const Text(
                        '若模型支持流式推理字段，会显示在下方灰色区域（非所有模型都有）',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _showReasoning,
                      onChanged: _isLoading
                          ? null
                          : (v) {
                              setState(() => _showReasoning = v);
                              _persistExplainUiPrefs();
                            },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          const Text('思考程度'),
                          Expanded(
                            child: Slider(
                              value: _reasoningDepth.toDouble(),
                              min: 0,
                              max: 3,
                              divisions: 3,
                              label: ['关闭', '轻', '中', '重'][_reasoningDepth],
                              onChanged: _isLoading
                                  ? null
                                  : (v) {
                                      setState(() => _reasoningDepth = v.round());
                                      _persistExplainUiPrefs();
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        '「关闭」时降低温度与输出上限，优先速度；其余档位逐步提高。',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 按钮行
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_prefsLoaded) ? null : _explain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: !_prefsLoaded && !_isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '生成中… ${_elapsedSec}s',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
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

            if (_showReasoning && _reasoningText.isNotEmpty) ...[
              const Text(
                '🧠 模型思考（流式）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.grey.shade200,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _reasoningText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

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
            if (_explanation.isEmpty && _reasoningText.isEmpty && !_isLoading) ...[
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
}
