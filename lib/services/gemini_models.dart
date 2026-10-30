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
    final metrics = <String>{};
    String? retry;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final details = body is Map && body['error'] is Map
          ? body['error']['details']
          : null;
      if (details is List) {
        for (final detail in details.whereType<Map>()) {
          if (detail['@type'] == 'type.googleapis.com/google.rpc.RetryInfo') {
            final value = detail['retryDelay'];
            if (value is String &&
                RegExp(r'^\d{1,6}(?:\.\d{1,9})?s$').hasMatch(value)) {
              retry = value;
            }
          }
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
            // Show only our own labels, not provider-controlled message/identifiers.
            if (metric.contains('token')) metrics.add('토큰');
            if (metric.contains('request')) metrics.add('요청 수');
            if (metric.contains('ground') || metric.contains('search')) {
              metrics.add('검색 도구');
            }
          }
        }
      }
    } catch (_) {
      /* An HTTP status alone does not establish quota exhaustion. */
    }
    final message = zeroFree
        ? 'Google이 이 모델의 무료 할당량을 0으로 보고했습니다. 사용량을 다 썼다는 뜻과는 다릅니다. 프로젝트·모델의 이용 조건을 확인하세요.'
        : daily
        ? 'Google이 일일 한도 항목을 이유로 요청을 거절했습니다. 해당 모델·항목을 AI Studio에서 확인하세요. 전체 API 사용량 소진을 의미하지는 않습니다.'
        : rate
        ? 'Google이 분당 제한 항목을 이유로 요청을 거절했습니다. 전체 API 사용량이 남아 있어도 발생할 수 있습니다.'
        : '요청이 거절됐습니다 (HTTP 429). 응답에 구체적인 제한 항목이 없어 사용량 소진 여부를 확인할 수 없습니다. 일반 생성과 검색 포함 요청을 나눠 진단해 주세요.';
    return [
      message,
      if (metrics.isNotEmpty) '제한 항목: ${metrics.join(', ')}',
      if (retry != null) 'Google 재시도 안내: $retry',
    ].join('\n');
  }

  static String requestFailure(
    http.Response response, {
    required String operation,
    String? model,
  }) {
    String? status;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final value = body is Map && body['error'] is Map
          ? body['error']['status']
          : null;
      if (const {
        'RESOURCE_EXHAUSTED',
        'UNAVAILABLE',
        'INVALID_ARGUMENT',
        'PERMISSION_DENIED',
        'UNAUTHENTICATED',
        'NOT_FOUND',
        'INTERNAL',
        'DEADLINE_EXCEEDED',
      }.contains(value)) {
        status = value as String;
      }
    } catch (_) {}
    final message = response.statusCode == 429
        ? quotaMessage(response)
        : switch (response.statusCode) {
            400 => 'Google이 요청 형식 또는 선택 기능을 거절했습니다. 키 오류나 한도 소진으로 단정할 수 없습니다.',
            401 => 'API 키 인증을 확인하지 못했습니다.',
            403 => '프로젝트·키 권한 또는 이용 조건을 확인해 주세요.',
            404 => '요청한 모델을 찾지 못했습니다. 공식 목록을 새로 불러와 주세요.',
            _ => 'Google 요청을 완료하지 못했습니다. 서비스 상태와 인터넷 연결을 확인하세요.',
          };
    return [
      message,
      '진단: $operation · HTTP ${response.statusCode}${status == null ? '' : ' · $status'}',
      if (model != null && RegExp(r'^gemini-[a-zA-Z0-9._-]+$').hasMatch(model))
        '모델: $model',
    ].join('\n');
  }

  static void checkResponse(
    http.Response response, {
    String operation = '모델 목록 조회',
    String? model,
  }) {
    if (response.statusCode != 200) {
      throw FormatException(
        requestFailure(response, operation: operation, model: model),
      );
    }
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

  Future<void> testGeneration(String key, String model) async {
    final apiKey = checkedKey(key);
    if (!RegExp(r'^gemini-[a-zA-Z0-9._-]+$').hasMatch(model)) {
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
                {'text': 'Reply with OK.'},
              ],
            },
          ],
          'generationConfig': {'maxOutputTokens': 64},
        }),
      ),
    );
    checkResponse(response, operation: '일반 생성 (검색 제외)', model: model);
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map &&
          body['candidates'] is List &&
          (body['candidates'] as List).whereType<Map>().any((c) {
            final parts = c['content'] is Map ? c['content']['parts'] : null;
            return parts is List &&
                parts.whereType<Map>().any(
                  (p) =>
                      p['thought'] != true &&
                      p['text'] is String &&
                      (p['text'] as String).trim().isNotEmpty,
                );
          })) {
        return;
      }
    } catch (_) {}
    throw const FormatException(
      '일반 생성 요청은 HTTP 200으로 처리됐지만 답변을 확인하지 못했습니다. 한도 소진 오류는 아닙니다.',
    );
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
    checkResponse(response, operation: '검색 포함 생성', model: model);
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
