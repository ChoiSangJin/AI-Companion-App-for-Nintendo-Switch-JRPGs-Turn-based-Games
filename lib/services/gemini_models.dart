import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract final class GeminiLinks {
  static final usage = Uri.https('aistudio.google.com', '/usage');
  static final apiKeys = Uri.https('aistudio.google.com', '/apikey');
  static final keyHelp = Uri.https(
    'ai.google.dev',
    '/gemini-api/docs/api-key',
    {'hl': 'ko'},
  );
  static final models = Uri.https('ai.google.dev', '/gemini-api/docs/models', {
    'hl': 'ko',
  });
  static final pricing = Uri.https(
    'ai.google.dev',
    '/gemini-api/docs/pricing',
    {'hl': 'ko'},
  );
  static final regions = Uri.https(
    'ai.google.dev',
    '/gemini-api/docs/available-regions',
    {'hl': 'ko'},
  );
}

class GeminiModel {
  const GeminiModel({
    required this.id,
    required this.name,
    required this.version,
  });
  final String id, name;
  final List<int> version;
  bool get preview =>
      RegExp(r'(^|-)(preview|exp|experimental)(-|$)').hasMatch(id);
  bool get alias => id.endsWith('-latest') || version.isEmpty;
  String get kind => id.contains('flash-lite')
      ? 'Flash Lite · 가벼운 응답'
      : id.contains('flash')
      ? 'Flash · 빠른 공략 조회'
      : id.contains('pro')
      ? 'Pro · 복잡한 공략 분석'
      : 'Gemini · 일반 공략 모델';
  int get _variant => id.contains('flash-lite')
      ? 1
      : id.contains('flash')
      ? 0
      : id.contains('pro')
      ? 2
      : 3;
  static GeminiModel? fromApi(Map<String, dynamic> data) {
    final name = data['name'];
    final methods = data['supportedGenerationMethods'];
    if (name is! String ||
        !name.startsWith('models/') ||
        methods is! List ||
        !methods.contains('generateContent')) {
      return null;
    }
    final id = name.substring('models/'.length);
    if (!RegExp(r'^gemini-[a-zA-Z0-9._-]+$').hasMatch(id) ||
        RegExp(
          r'(image|audio|tts|live|vision|embedding|computer-use|research|robotics)',
        ).hasMatch(id)) {
      return null;
    }
    final match = RegExp(r'^gemini-(\d+)(?:\.(\d+))?[-.]').firstMatch(id);
    final version = match == null
        ? <int>[]
        : [int.parse(match[1]!), int.parse(match[2] ?? '0')];
    if (version.isEmpty && !id.endsWith('-latest')) return null;
    // The app uses the Google Search tool from Gemini 2 and later.
    if (version.isNotEmpty && version.first < 2) return null;
    return GeminiModel(
      id: id,
      name:
          data['displayName'] is String &&
              (data['displayName'] as String).trim().isNotEmpty
          ? data['displayName'] as String
          : id,
      version: List.unmodifiable(version),
    );
  }

  static int newestFirst(GeminiModel a, GeminiModel b) {
    if (a.alias != b.alias) return a.alias ? 1 : -1;
    for (var i = 0; i < 2; i++) {
      final difference = (b.version.length > i ? b.version[i] : -1).compareTo(
        a.version.length > i ? a.version[i] : -1,
      );
      if (difference != 0) return difference;
    }
    if (a.preview != b.preview) return a.preview ? 1 : -1;
    final variant = a._variant.compareTo(b._variant);
    if (variant != 0) return variant;
    // A dated/revision suffix is only a tie-breaker, not a release-date claim.
    return b.id.compareTo(a.id);
  }
}

class GeminiModelList {
  GeminiModelList(Iterable<GeminiModel> entries)
    : models = List.unmodifiable(
        entries.toList()..sort(GeminiModel.newestFirst),
      );
  final List<GeminiModel> models;
  List<GeminiModel> get stable =>
      models.where((m) => !m.preview && !m.alias).toList();
  List<GeminiModel> get additional =>
      models.where((m) => m.preview || m.alias).toList();
  GeminiModel? get connectionCandidate =>
      stable
          .where((m) => m.id.contains('flash') && !m.id.contains('lite'))
          .firstOrNull ??
      stable.where((m) => m.id.contains('flash')).firstOrNull ??
      recommended;
  GeminiModel? get recommended =>
      stable.firstOrNull ??
      models.where((m) => !m.alias).firstOrNull ??
      models.firstOrNull;
}

class GeminiModelsService {
  GeminiModelsService({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  void close() => client.close();
  static String checkedKey(String key) {
    final value = key.trim();
    if (value.isEmpty) {
      throw const FormatException('Google AI Studio에서 복사한 API 키를 붙여넣어 주세요.');
    }
    if (value.contains(RegExp(r'\s')) || value.startsWith('http')) {
      throw const FormatException('주소나 설명을 제외하고 API 키 값만 붙여넣어 주세요.');
    }
    return value;
  }

  Future<http.Response> _request(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const FormatException(
        'Google 연결 시간이 초과됐습니다. 인터넷을 확인하고 다시 시도해 주세요.',
      );
    } on http.ClientException {
      throw const FormatException('Google에 연결하지 못했습니다. 인터넷을 확인해 주세요.');
    }
  }

  // Read only structured quota metadata; never display Google's raw message,
  // which may contain request data or credentials.
  static String quotaMessage(http.Response response) {
    var zeroFree = false, daily = false, rate = false;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final details = body is Map && body['error'] is Map
          ? body['error']['details']
          : null;
      if (details is List) {
        for (final detail in details.whereType<Map>()) {
          if (detail['@type'] !=
              'type.googleapis.com/google.rpc.QuotaFailure') {
            continue;
          }
          final violations = detail['violations'];
          if (violations is! List) continue;
          for (final v in violations.whereType<Map>()) {
            final metric = '${v['quotaMetric'] ?? ''} ${v['quotaId'] ?? ''}'
                .toLowerCase();
            final zero = v['quotaValue'] == 0 || v['quotaValue'] == '0';
            zeroFree |=
                zero &&
                (metric.contains('free_tier') || metric.contains('freetier'));
            daily |= metric.contains('perday') || metric.contains('per_day');
            rate |=
                metric.contains('perminute') || metric.contains('per_minute');
          }
        }
      }
    } catch (_) {
      /* Missing metadata must not become a guessed diagnosis. */
    }
    if (zeroFree) {
      return '이 모델의 무료 할당량이 0으로 안내됐습니다. 처음 연결해도 사용할 수 없을 수 있어요. AI 연결 설정에서 다른 Flash 모델을 선택해 검색 연결을 확인하세요. AI Studio 사용량에서 프로젝트·모델별 한도를 확인할 수 있습니다.';
    }
    if (daily) {
      return '이 프로젝트·모델의 일일 한도에 도달했습니다. 같은 프로젝트의 다른 키로 바꿔도 한도는 늘지 않습니다. AI Studio 사용량에서 초기화 시점과 한도를 확인하세요.';
    }
    if (rate) {
      return '짧은 시간의 요청 한도에 도달했습니다. 잠시 기다린 뒤 다시 시도하세요. 반복되면 AI Studio 사용량에서 해당 모델의 한도를 확인하세요.';
    }
    return 'Google이 요청 한도를 제한했습니다. 처음 연결한 경우에도 모델의 무료 할당량이 없을 수 있습니다. 일시 제한인지 무료 한도 문제인지는 이 응답으로 확인되지 않았습니다. AI 연결 설정에서 다른 Flash 모델을 테스트하거나 AI Studio 사용량을 확인하세요.';
  }

  static void checkResponse(http.Response response) {
    if (response.statusCode == 429) {
      throw FormatException(quotaMessage(response));
    }
    checkStatus(response.statusCode);
  }

  static void checkStatus(int status) {
    if (status == 200) return;
    throw FormatException(switch (status) {
      400 || 401 => 'API 키를 확인하지 못했습니다. AI Studio에서 키 값을 다시 복사해 주세요.',
      403 =>
        '이 키의 사용 권한을 확인해 주세요. AI Studio에서 프로젝트·키 제한 및 이용 가능 지역을 확인할 수 있습니다.',
      404 => '선택한 모델을 찾지 못했습니다. 공식 모델 목록을 새로 불러와 주세요.',
      429 => 'Google 요청 한도에 도달했습니다. 잠시 후 다시 시도하거나 AI Studio의 사용량을 확인해 주세요.',
      _ => 'Google 서비스에 연결하지 못했습니다 ($status). 잠시 후 다시 시도해 주세요.',
    });
  }

  Future<GeminiModelList> listModels(String key) async {
    final apiKey = checkedKey(key);
    final found = <String, GeminiModel>{};
    final tokens = <String>{};
    String? token;
    for (var page = 0; page < 20; page++) {
      final response = await _request(
        () => client.get(
          Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {
            'pageSize': '1000',
            'pageToken': ?token,
          }),
          headers: {'x-goog-api-key': apiKey},
        ),
      );
      checkResponse(response);
      try {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final entries = data['models'];
        if (entries is! List) {
          throw const FormatException('Google 모델 목록을 읽지 못했습니다. 다시 시도해 주세요.');
        }
        for (final entry in entries) {
          if (entry is! Map) continue;
          final model = GeminiModel.fromApi(Map<String, dynamic>.from(entry));
          if (model != null) found[model.id] = model;
        }
        final next = data['nextPageToken'];
        if (next != null && next is! String) {
          throw const FormatException('Google 모델 목록의 다음 페이지를 읽지 못했습니다.');
        }
        token = next as String?;
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException('Google 모델 목록을 읽지 못했습니다. 다시 시도해 주세요.');
      }
      if (token == null || token.isEmpty) {
        if (found.isEmpty) {
          throw const FormatException(
            '공략용 Gemini 모델을 찾지 못했습니다. AI Studio에서 키와 프로젝트를 확인해 주세요.',
          );
        }
        return GeminiModelList(found.values);
      }
      if (!tokens.add(token)) {
        throw const FormatException('Google 모델 목록 응답이 반복됐습니다. 다시 시도해 주세요.');
      }
    }
    throw const FormatException('모델 목록이 너무 길어 확인을 완료하지 못했습니다. 다시 시도해 주세요.');
  }

  Future<void> testSearch(String key, String model) async {
    final apiKey = checkedKey(key);
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
      throw const FormatException('공식 목록에서 모델을 선택해 주세요.');
    }
    final response = await _request(
      () => client.post(
        Uri.https(
          'generativelanguage.googleapis.com',
          '/v1beta/models/$model:generateContent',
        ),
        headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text':
                      'Google 검색을 사용하여 Google AI Studio의 공식 API 키 발급 페이지 주소를 확인하고 짧게 답하세요.',
                },
              ],
            },
          ],
          'tools': [
            {'googleSearch': <String, dynamic>{}},
          ],
        }),
      ),
    );
    if (response.statusCode == 400) {
      throw const FormatException(
        '선택한 모델의 검색 요청을 처리하지 못했습니다. 다른 추천 모델을 선택하거나 공식 지원 기능을 확인해 주세요.',
      );
    }
    checkResponse(response);
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final candidates = data['candidates'] as List? ?? [];
      final supported = candidates.any(
        (c) =>
            c is Map &&
            c['finishReason'] == 'STOP' &&
            (((c['content'] as Map?)?['parts'] as List?) ?? []).any(
              (p) =>
                  p is Map &&
                  p['thought'] != true &&
                  p['text'] is String &&
                  (p['text'] as String).trim().isNotEmpty,
            ) &&
            ((c['groundingMetadata'] as Map?)?['groundingChunks'] as List? ??
                    [])
                .any((chunk) {
                  final uri = Uri.tryParse(
                    (chunk as Map)['web']?['uri'] as String? ?? '',
                  );
                  return uri != null &&
                      uri.scheme == 'https' &&
                      uri.host.isNotEmpty;
                }),
      );
      if (!supported) {
        throw const FormatException(
          '검색 출처가 있는 응답을 받지 못했습니다. 다시 테스트하거나 다른 추천 모델을 선택해 주세요.',
        );
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('모델의 검색 응답을 확인하지 못했습니다. 다른 모델을 선택해 주세요.');
    }
  }
}
