import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = false;
  bool _extrasLoading = false;
  bool _slangMode = true;

  bool _enableJyutping = true;
  bool _enableTts = true;

  String _cantonese = '';
  String _jyutping = '';
  String? _slang;
  String? _slangJyutping;
  String? _note;
  String? _audioUrl;
  String? _slangAudioUrl;

  String _apiKey = '';
  String _modelName = '';
  String _baseUrl = '';
  String _backendUrl = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
      _modelName = prefs.getString('model_name') ?? '';
      _baseUrl = prefs.getString('base_url') ?? 'https://api.siliconflow.cn/v1';
      _backendUrl = prefs.getString('backend_url') ?? '';
      _enableJyutping = prefs.getBool('enable_jyutping') ?? true;
      _enableTts = prefs.getBool('enable_tts') ?? true;
      _apiService.backendBaseUrl =
          _backendUrl.trim().isEmpty ? null : _backendUrl.trim();
    });
  }

  Future<void> _handleBackendUnavailableOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('backend_failure_dialog_shown') ?? false;
    if (!shown && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('后端不可用'),
          content: const Text(
            '无法连接后端以生成粤拼或语音。\n\n'
            '已自动关闭「粤拼标注」与「语音朗读」，之后将只使用模型翻译。\n'
            '可在设置中重新开启并检查后端地址。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      await prefs.setBool('backend_failure_dialog_shown', true);
    }
    await prefs.setBool('enable_jyutping', false);
    await prefs.setBool('enable_tts', false);
    if (mounted) {
      setState(() {
        _enableJyutping = false;
        _enableTts = false;
      });
    }
  }

  Future<void> _translate() async {
    if (_textController.text.isEmpty) {
      _showSnackBar('请输入要翻译的文本', Colors.orange);
      return;
    }

    if (_apiKey.isEmpty || _modelName.isEmpty) {
      _showSnackBar('请先在设置中配置 API Key 和模型', Colors.orange);
      return;
    }

    await _loadSettings();

    final needBackend = _enableJyutping || _enableTts;
    if (needBackend && _backendUrl.trim().isEmpty) {
      _showSnackBar('请填写后端地址，或在设置中关闭粤拼/语音', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _extrasLoading = false;
      _cantonese = '';
      _jyutping = '';
      _slang = null;
      _slangJyutping = null;
      _note = null;
      _audioUrl = null;
      _slangAudioUrl = null;
    });

    try {
      final modelResult = await _apiService.translateModelOnly(
        text: _textController.text,
        apiKey: _apiKey,
        modelName: _modelName,
        baseUrlApi: _baseUrl,
        slangMode: _slangMode,
      );

      final cantonese = (modelResult['cantonese'] ?? '').toString();
      final rawSlang = modelResult['slang'];
      final slangStr = rawSlang == null
          ? null
          : rawSlang.toString().trim().isEmpty
              ? null
              : rawSlang.toString();

      if (!mounted) return;
      setState(() {
        _cantonese = cantonese;
        _slang = slangStr;
        _note = (modelResult['note'] ?? '').toString();
        _isLoading = false;
        _extrasLoading = needBackend;
      });

      if (!needBackend) {
        return;
      }

      var backendFailed = false;

      if (_enableJyutping) {
        try {
          if (cantonese.isNotEmpty) {
            final jp = await _apiService.requestJyutpingAnnotation(cantonese);
            if (mounted) setState(() => _jyutping = jp);
          }
          if (slangStr != null && slangStr.isNotEmpty) {
            final sjp = await _apiService.requestJyutpingAnnotation(slangStr);
            if (mounted) setState(() => _slangJyutping = sjp);
          }
        } catch (_) {
          backendFailed = true;
          await _handleBackendUnavailableOnce();
        }
      }

      if (!backendFailed && _enableTts) {
        try {
          if (cantonese.isNotEmpty) {
            final audioUrl = await _apiService.generateAudio(cantonese);
            if (audioUrl == null) {
              backendFailed = true;
            } else if (mounted) {
              setState(() => _audioUrl = audioUrl);
            }
          }
          if (!backendFailed &&
              slangStr != null &&
              slangStr.isNotEmpty) {
            final slangAudioUrl = await _apiService.generateAudio(slangStr);
            if (slangAudioUrl == null) {
              backendFailed = true;
            } else if (mounted) {
              setState(() => _slangAudioUrl = slangAudioUrl);
            }
          }
          if (backendFailed) {
            await _handleBackendUnavailableOnce();
          }
        } catch (_) {
          await _handleBackendUnavailableOnce();
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('翻译失败: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _extrasLoading = false;
        });
      }
    }
  }

  Future<void> _playAudio(String? url) async {
    if (url == null) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      _showSnackBar('正在播放...', Colors.green, duration: 1);
    } catch (e) {
      _showSnackBar('播放失败: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color, {int duration = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red.shade50, Colors.orange.shade50, Colors.pink.shade50],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('🗣️ 普通话转粤语', style: TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.orange.shade400],
              ),
            ),
          ),
          elevation: 0,
          centerTitle: true,
        ),
        body: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInputCard(),
                const SizedBox(height: 20),
                _buildTranslateButton(),
                const SizedBox(height: 24),
                if (_cantonese.isNotEmpty) _buildResultCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.red.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.red.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_note, color: Colors.red.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  '输入普通话',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: '例如：你在干什么？',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 4,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: SwitchListTile(
                title: const Text('🔥 启用地道俚语/黑话', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('开启后会显示更地道的市井俚语', style: TextStyle(fontSize: 12)),
                value: _slangMode,
                onChanged: (value) => setState(() => _slangMode = value),
                activeThumbColor: Colors.orange.shade700,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton() {
    final busy = _isLoading || _extrasLoading;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: busy
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [Colors.red.shade500, Colors.orange.shade500],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: busy ? null : _translate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: busy
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.translate, size: 24),
                  SizedBox(width: 12),
                  Text('开始翻译', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 12,
      shadowColor: Colors.orange.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.orange.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_extrasLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.orange.shade600,
                  backgroundColor: Colors.orange.shade100,
                ),
              ),
            _buildResultSection(
              title: _slang != null && _slang!.isNotEmpty ? '📖 标准口语' : '✨ 粤语翻译',
              content: _cantonese,
              jyutping: _jyutping,
              audioUrl: _audioUrl,
              color: Colors.red,
            ),
            if (_slang != null && _slang!.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(thickness: 2),
              const SizedBox(height: 20),
              _buildResultSection(
                title: '🔥 地道黑话',
                content: _slang!,
                jyutping: _slangJyutping,
                audioUrl: _slangAudioUrl,
                color: Colors.orange,
              ),
            ],
            if (_note != null && _note!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '老广笔记',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _note!,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection({
    required String title,
    required String content,
    String? jyutping,
    String? audioUrl,
    required MaterialColor color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.3,
                ),
              ),
            ),
            if (audioUrl != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.shade400, color.shade600]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.white, size: 28),
                  onPressed: () => _playAudio(audioUrl),
                ),
              ),
          ],
        ),
        if (jyutping != null && jyutping.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.shade200),
            ),
            child: SelectableText(
              jyutping,
              style: TextStyle(
                fontSize: 15,
                fontFamily: 'monospace',
                color: color.shade900,
                height: 1.6,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
