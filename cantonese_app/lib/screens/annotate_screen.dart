import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../app_constants.dart';
import '../route_observer.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';

/// 注音：仅调用后端粤拼 + TTS，不走大模型
class AnnotateScreen extends StatefulWidget {
  const AnnotateScreen({super.key});

  @override
  State<AnnotateScreen> createState() => _AnnotateScreenState();
}

class _AnnotateScreenState extends State<AnnotateScreen> with RouteAware {
  final TextEditingController _textController = TextEditingController();
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _loading = false;
  String _jyutping = '';
  String? _audioUrl;


  @override
  void initState() {
    super.initState();
    _loadBackend();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadBackend();
  }

  void _loadBackend() {
    if (!mounted) return;
    setState(() {
      _apiService.backendBaseUrl = AppConstants.backendApiRoot;
    });
  }

  Future<void> _annotate() async {
    _loadBackend();
    if (!mounted) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入要注音的粤语文本')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _jyutping = '';
      _audioUrl = null;
    });

    try {
      final jp = await _apiService.requestJyutpingAnnotation(text);
      final audioUrl = await _apiService.generateAudio(text);

      if (!mounted) return;
      setState(() {
        _jyutping = jp;
        _audioUrl = audioUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注音失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playAudio() async {
    final url = _audioUrl;
    if (url == null) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  void _clear() {
    setState(() {
      _textController.clear();
      _jyutping = '';
      _audioUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('粤语注音'),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: '输入粤语文本',
                  border: OutlineInputBorder(),
                  hintText: '例如：今日天氣幾好。',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _annotate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('生成注音与读音', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _clear,
                    child: const Text('清空'),
                  ),
                ],
              ),
              if (_jyutping.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  '粤拼（Jyutping）',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _jyutping,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('朗读', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    if (_audioUrl != null)
                      FilledButton.icon(
                        onPressed: _playAudio,
                        icon: const Icon(Icons.volume_up),
                        label: const Text('播放'),
                      )
                    else
                      Text(
                        '语音未生成（请检查后端 /api/audio）',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}
