import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  /// 初始化 TTS 服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _flutterTts = FlutterTts();
    
    // 设置语言为粤语（香港）
    await _flutterTts!.setLanguage('zh-HK');
    
    // 设置语音参数
    await _flutterTts!.setSpeechRate(0.5); // 语速
    await _flutterTts!.setVolume(1.0); // 音量
    await _flutterTts!.setPitch(1.0); // 音调

    _isInitialized = true;
  }

  /// 检查是否支持粤语
  Future<bool> isCantoneseSupported() async {
    await initialize();
    
    try {
      final languages = await _flutterTts!.getLanguages;
      // 检查是否支持粤语相关语言代码
      final supportedCodes = ['zh-HK', 'zh-TW', 'yue', 'zh'];
      return languages.any((lang) => 
        supportedCodes.any((code) => lang.toString().toLowerCase().contains(code.toLowerCase()))
      );
    } catch (e) {
      return false;
    }
  }

  /// 播放文本（使用系统 TTS）
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 停止之前的播放
      await _flutterTts!.stop();
      
      // 播放新文本
      await _flutterTts!.speak(text);
    } catch (e) {
      throw Exception('语音播放失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    if (_flutterTts != null) {
      await _flutterTts!.pause();
    }
  }

  /// 释放资源
  void dispose() {
    _flutterTts?.stop();
    _flutterTts = null;
    _isInitialized = false;
  }
}



