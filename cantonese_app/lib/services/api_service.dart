import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

/// 流式解释：正文增量与可选「思考」增量（兼容带 reasoning_content 的模型）
class ExplainStreamChunk {
  ExplainStreamChunk({
    this.contentDelta,
    this.reasoningDelta,
    this.done = false,
    this.error,
  });

  final String? contentDelta;
  final String? reasoningDelta;
  final bool done;
  final String? error;
}

class ApiService {
  /// 后端根地址，例如 https://your-server.com:6783（无尾斜杠）
  /// 用于 `/api/jyutping`、`/api/audio`
  String? backendBaseUrl;

  ApiService({this.backendBaseUrl});

  /// 规范化 API Base URL（确保以 /v1 结尾）
  String _normalizeBaseUrl(String baseUrl) {
    baseUrl = baseUrl.trim();
    if (baseUrl.isEmpty) {
      return 'https://api.siliconflow.cn/v1';
    }
    baseUrl = baseUrl.replaceAll(RegExp(r'/$'), '');
    if (!baseUrl.endsWith('/v1')) {
      baseUrl = '$baseUrl/v1';
    }
    return baseUrl;
  }

  String _backendRoot() {
    final root = backendBaseUrl?.trim();
    if (root == null || root.isEmpty) {
      throw Exception(
        '请先在设置中填写后端服务地址（需已部署粤语助手 API，提供 /api/jyutping）',
      );
    }
    return root.replaceAll(RegExp(r'/$'), '');
  }

  /// 调用远程粤拼服务（与后端 `POST /api/jyutping` 一致）
  Future<String> requestJyutpingAnnotation(String text) async {
    if (text.trim().isEmpty) return '';
    final base = _backendRoot();
    final url = Uri.parse('$base/api/jyutping');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode != 200) {
      throw Exception('粤拼服务 HTTP ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['jyutping'] ?? '').toString();
  }

  /// 仅调用大模型完成翻译（不请求后端粤拼 / 语音）
  Future<Map<String, dynamic>> translateModelOnly({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
    bool slangMode = false,
  }) async {
    final baseUrl = _normalizeBaseUrl(baseUrlApi);
    final url = Uri.parse('$baseUrl/chat/completions');

    String systemPrompt;
    String userPrompt;

    if (slangMode) {
      systemPrompt =
          'You are a native Cantonese linguistics expert (Old Guang). Your task is to translate Mandarin to Cantonese and provide detailed information.';
      userPrompt = '''
Role: You are a native Cantonese linguistics expert (Old Guang).

Task: Translate Mandarin to Cantonese.

Input: "$text"

Requirements:
1. "cantonese": Standard colloquial Cantonese (e.g., 100 yuan -> 一百蚊).
2. "slang": VERY local, street slang if available (e.g., 100 yuan -> 一旧水, Police -> 差佬/阿Sir, Boss -> 老細, Work/Earn money -> 搵食, Very good -> 好犀利/好巴闭). If no specific slang exists, strictly return null.
3. "note": Explain the difference and cultural context in Simplified Chinese (普通话). Use clear and concise language. (optional, can be empty).

Do not include jyutping fields; the client will call a dedicated Jyutping service.

Common slang examples:
- Money: 10元->一草嘢, 100元->一旧水, 1000元->一撇水, 10000元->一皮嘢/一鸡嘢
- People: 警察->差佬/阿Sir, 老板->老細
- Actions: 工作->搵食, 吃饭->食嘢

Output JSON (NO markdown code blocks):
{
    "cantonese": "...",
    "slang": "..." or null,
    "note": "..."
}
''';
    } else {
      systemPrompt =
          'You are a Cantonese translation expert. Translate Mandarin to colloquial Cantonese.';
      userPrompt = '''请将以下普通话翻译成地道的粤语（口语，非书面语）。
只需要输出粤语翻译结果，不要任何解释、注释或额外内容。
使用繁体中文。

普通话：$text

粤语：''';
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode != 200) {
      String errorDetail = '';
      try {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorData['message'] != null) {
          errorDetail = errorData['message'];
        } else if (errorData['error'] != null) {
          errorDetail = errorData['error'].toString();
        } else {
          errorDetail = response.body;
        }
      } catch (e) {
        errorDetail = response.body.length > 500
            ? response.body.substring(0, 500)
            : response.body;
      }
      throw Exception('HTTP ${response.statusCode}: $errorDetail');
    }

    final resultData = jsonDecode(utf8.decode(response.bodyBytes));

    if (resultData['choices'] == null || resultData['choices'].isEmpty) {
      throw Exception('API响应格式错误：未找到choices字段');
    }

    final resultText = resultData['choices'][0]['message']['content'].trim();

    if (slangMode) {
      try {
        String cleanText = resultText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final result = Map<String, dynamic>.from(
          jsonDecode(cleanText) as Map,
        );
        return {
          'cantonese': (result['cantonese'] ?? '').toString(),
          'slang': result['slang'],
          'note': (result['note'] ?? '').toString(),
        };
      } catch (e) {
        return {
          'cantonese': resultText,
          'slang': null,
          'note': '',
        };
      }
    }

    return {
      'cantonese': resultText,
      'slang': null,
      'note': '',
    };
  }

  /// 兼容旧调用：模型 + 粤拼（会阻塞到粤拼完成）
  Future<Map<String, dynamic>> translate({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
    bool slangMode = false,
  }) async {
    final base = await translateModelOnly(
      text: text,
      apiKey: apiKey,
      modelName: modelName,
      baseUrlApi: baseUrlApi,
      slangMode: slangMode,
    );
    final cantonese = (base['cantonese'] ?? '').toString();
    final slang = base['slang'];
    final slangStr = slang == null
        ? null
        : slang.toString().trim().isEmpty
            ? null
            : slang.toString();

    String jyut = '';
    String? slangJyut;
    if (cantonese.isNotEmpty) {
      jyut = await requestJyutpingAnnotation(cantonese);
    }
    if (slangStr != null && slangStr.isNotEmpty) {
      slangJyut = await requestJyutpingAnnotation(slangStr);
    }

    return {
      'cantonese': cantonese,
      'slang': slangStr,
      'jyutping': jyut,
      'slang_jyutping': slangJyut,
      'note': base['note'] ?? '',
    };
  }

  /// 粤拼标注 API — 仅请求后端
  Future<Map<String, dynamic>> jyutping(String text) async {
    final jyut = await requestJyutpingAnnotation(text);
    return {'original': text, 'jyutping': jyut};
  }

  /// 粤语解释 API - 直接调用 AI API，无需后端服务器
  Future<Map<String, dynamic>> explain({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
  }) async {
    final baseUrl = _normalizeBaseUrl(baseUrlApi);
    final url = Uri.parse('$baseUrl/chat/completions');

    const systemPrompt =
        'You are a Cantonese language expert. Explain Cantonese words and phrases in Mandarin Chinese with detailed cultural context.';
    final userPrompt = '''请用普通话详细解释以下粤语内容：

粤语：$text

请包括：
1. **字面意思**：逐字或逐词的字面含义
2. **实际含义**：在日常对话中的真实意思
3. **使用场景**：什么情况下使用这个表达
4. **文化背景**：相关的文化或历史背景（如有）
5. **普通话对应**：对应的普通话说法
6. **例句**：用粤语举1-2个实际使用例子，并附上普通话翻译

请用清晰、通俗易懂的普通话解释。''';

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': 0.7,
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode != 200) {
        String errorDetail = '';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            errorDetail = errorData['message'];
          } else if (errorData['error'] != null) {
            errorDetail = errorData['error'].toString();
          }
        } catch (e) {
          errorDetail = response.body.length > 500
              ? response.body.substring(0, 500)
              : response.body;
        }
        throw Exception('HTTP ${response.statusCode}: $errorDetail');
      }

      final resultData = jsonDecode(utf8.decode(response.bodyBytes));
      final explanation =
          resultData['choices'][0]['message']['content'].trim();

      return {'explanation': explanation};
    } catch (e) {
      throw Exception('解释失败: $e');
    }
  }

  /// 流式解释（SSE）。若服务端不支持 stream，调用方应回退到 [explain]。
  ///
  /// [reasoningDepth] 0=关闭 1=轻 2=中 3=重：通过 temperature / max_tokens 调节深度。
  Stream<ExplainStreamChunk> explainStream({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
    int reasoningDepth = 2,
  }) async* {
    final baseUrl = _normalizeBaseUrl(baseUrlApi);
    final url = Uri.parse('$baseUrl/chat/completions');

    const systemPrompt =
        'You are a Cantonese language expert. Explain Cantonese words and phrases in Mandarin Chinese with detailed cultural context.';
    final userPrompt = '''请用普通话详细解释以下粤语内容：

粤语：$text

请包括：
1. **字面意思**：逐字或逐词的字面含义
2. **实际含义**：在日常对话中的真实意思
3. **使用场景**：什么情况下使用这个表达
4. **文化背景**：相关的文化或历史背景（如有）
5. **普通话对应**：对应的普通话说法
6. **例句**：用粤语举1-2个实际使用例子，并附上普通话翻译

请用清晰、通俗易懂的普通话解释。''';

    final d = reasoningDepth.clamp(0, 3);
    final temperature = 0.40 + d * 0.12;
    final maxTokens = 1536 + d * 768;

    final body = <String, dynamic>{
      'model': modelName,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        final errBody = await streamed.stream.bytesToString();
        yield ExplainStreamChunk(
          error: 'HTTP ${streamed.statusCode}: ${errBody.length > 800 ? '${errBody.substring(0, 800)}…' : errBody}',
        );
        return;
      }

      var carry = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        carry += chunk;
        while (true) {
          final nl = carry.indexOf('\n');
          if (nl < 0) break;
          var line = carry.substring(0, nl);
          carry = carry.substring(nl + 1);
          line = line.trimRight();
          if (line.isEmpty) continue;
          if (line.startsWith(':')) continue;
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') {
            yield ExplainStreamChunk(done: true);
            return;
          }
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final choices = data['choices'];
            if (choices is! List || choices.isEmpty) continue;
            final first = choices[0];
            if (first is! Map<String, dynamic>) continue;
            final delta = first['delta'];
            String? c;
            String? r;
            if (delta is Map<String, dynamic>) {
              final content = delta['content'];
              if (content is String) c = content;
              final think = delta['reasoning_content'] ??
                  delta['reasoning'] ??
                  delta['thinking'];
              if (think is String) r = think;
            }
            final msg = first['message'];
            if (msg is Map<String, dynamic>) {
              final mrc = msg['reasoning_content'] ?? msg['reasoning'];
              if (mrc is String && r == null) r = mrc;
            }
            if (c != null || r != null) {
              yield ExplainStreamChunk(contentDelta: c, reasoningDelta: r);
            }
          } catch (_) {
            // 忽略单行解析失败
          }
        }
      }
      yield ExplainStreamChunk(done: true);
    } catch (e, st) {
      developer.log('explainStream error: $e\n$st', name: 'ApiService');
      yield ExplainStreamChunk(error: e.toString());
    } finally {
      client.close();
    }
  }

  /// 流式翻译（SSE），与 [translateModelOnly] 使用相同提示词；正文增量在 `contentDelta`。
  ///
  /// [reasoningDepth] 0=关闭 1=轻 2=中 3=重：调节 temperature / max_tokens。
  Stream<ExplainStreamChunk> translateModelStream({
    required String text,
    required String apiKey,
    required String modelName,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
    bool slangMode = false,
    int reasoningDepth = 2,
  }) async* {
    final baseUrl = _normalizeBaseUrl(baseUrlApi);
    final url = Uri.parse('$baseUrl/chat/completions');

    String systemPrompt;
    String userPrompt;

    if (slangMode) {
      systemPrompt =
          'You are a native Cantonese linguistics expert (Old Guang). Your task is to translate Mandarin to Cantonese and provide detailed information.';
      userPrompt = '''
Role: You are a native Cantonese linguistics expert (Old Guang).

Task: Translate Mandarin to Cantonese.

Input: "$text"

Requirements:
1. "cantonese": Standard colloquial Cantonese (e.g., 100 yuan -> 一百蚊).
2. "slang": VERY local, street slang if available (e.g., 100 yuan -> 一旧水, Police -> 差佬/阿Sir, Boss -> 老細, Work/Earn money -> 搵食, Very good -> 好犀利/好巴闭). If no specific slang exists, strictly return null.
3. "note": Explain the difference and cultural context in Simplified Chinese (普通话). Use clear and concise language. (optional, can be empty).

Do not include jyutping fields; the client will call a dedicated Jyutping service.

Common slang examples:
- Money: 10元->一草嘢, 100元->一旧水, 1000元->一撇水, 10000元->一皮嘢/一鸡嘢
- People: 警察->差佬/阿Sir, 老板->老細
- Actions: 工作->搵食, 吃饭->食嘢

Output JSON (NO markdown code blocks):
{
    "cantonese": "...",
    "slang": "..." or null,
    "note": "..."
}
''';
    } else {
      systemPrompt =
          'You are a Cantonese translation expert. Translate Mandarin to colloquial Cantonese.';
      userPrompt = '''请将以下普通话翻译成地道的粤语（口语，非书面语）。
只需要输出粤语翻译结果，不要任何解释、注释或额外内容。
使用繁体中文。

普通话：$text

粤语：''';
    }

    final d = reasoningDepth.clamp(0, 3);
    final temperature = 0.40 + d * 0.12;
    final maxTokens = 768 + d * 384;

    final body = <String, dynamic>{
      'model': modelName,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);

      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        final errBody = await streamed.stream.bytesToString();
        yield ExplainStreamChunk(
          error: 'HTTP ${streamed.statusCode}: ${errBody.length > 800 ? '${errBody.substring(0, 800)}…' : errBody}',
        );
        return;
      }

      var carry = '';
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        carry += chunk;
        while (true) {
          final nl = carry.indexOf('\n');
          if (nl < 0) break;
          var line = carry.substring(0, nl);
          carry = carry.substring(nl + 1);
          line = line.trimRight();
          if (line.isEmpty) continue;
          if (line.startsWith(':')) continue;
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') {
            yield ExplainStreamChunk(done: true);
            return;
          }
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final choices = data['choices'];
            if (choices is! List || choices.isEmpty) continue;
            final first = choices[0];
            if (first is! Map<String, dynamic>) continue;
            final delta = first['delta'];
            String? c;
            String? r;
            if (delta is Map<String, dynamic>) {
              final content = delta['content'];
              if (content is String) c = content;
              final think = delta['reasoning_content'] ??
                  delta['reasoning'] ??
                  delta['thinking'];
              if (think is String) r = think;
            }
            final msg = first['message'];
            if (msg is Map<String, dynamic>) {
              final mrc = msg['reasoning_content'] ?? msg['reasoning'];
              if (mrc is String && r == null) r = mrc;
            }
            if (c != null || r != null) {
              yield ExplainStreamChunk(contentDelta: c, reasoningDelta: r);
            }
          } catch (_) {}
        }
      }
      yield ExplainStreamChunk(done: true);
    } catch (e, st) {
      developer.log('translateModelStream error: $e\n$st', name: 'ApiService');
      yield ExplainStreamChunk(error: e.toString());
    } finally {
      client.close();
    }
  }

  /// 语音生成 - 使用后端 edge-tts；失败返回 null
  Future<String?> generateAudio(String text, {String voice = 'zh-HK-HiuMaanNeural'}) async {
    if (backendBaseUrl == null || backendBaseUrl!.trim().isEmpty) {
      return null;
    }
    try {
      final base = backendBaseUrl!.trim().replaceAll(RegExp(r'/$'), '');
      final url = Uri.parse('$base/api/audio');
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
        return '$base${data['audio_url']}';
      }
    } catch (e) {
      developer.log('后端语音服务失败: $e', name: 'ApiService');
      return null;
    }

    return null;
  }

  /// 获取模型列表 API - 直接调用 AI API，无需后端服务器
  Future<List<String>> getModels({
    required String apiKey,
    String baseUrlApi = 'https://api.siliconflow.cn/v1',
  }) async {
    final baseUrl = _normalizeBaseUrl(baseUrlApi);
    final url = Uri.parse('$baseUrl/models');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null && data['data'] is List) {
          final models = (data['data'] as List)
              .map((model) => model['id'] as String)
              .where((id) => id.isNotEmpty)
              .toList();
          return models..sort();
        }
        return [];
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('获取模型列表失败: $e');
    }
  }
}
