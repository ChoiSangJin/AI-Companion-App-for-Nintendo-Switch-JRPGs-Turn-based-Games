import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_companion/models/models.dart';
import 'package:switch_companion/services/ai_settings_repository.dart';
import 'package:switch_companion/services/gemini_models.dart';
import 'package:switch_companion/services/storage.dart';
import 'package:switch_companion/widgets/ai_setup_page.dart';

Map<String, dynamic> model(
  String id, {
  String? name,
  List<String> methods = const ['generateContent'],
}) => {
  'name': 'models/$id',
  'displayName': name ?? id,
  'supportedGenerationMethods': methods,
};
http.Response response(Object body, {int status = 200}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response groundedResponse() => response({
  'candidates': [
    {
      'finishReason': 'STOP',
      'content': {
        'parts': [
          {'text': '공식 API 키 안내'},
        ],
      },
      'groundingMetadata': {
        'groundingChunks': [
          {
            'web': {'uri': 'https://ai.google.dev/'},
          },
        ],
      },
    },
  ],
});

GeminiModelsService fakeCatalog() => GeminiModelsService(
  client: MockClient(
    (request) async => request.method == 'POST'
        ? groundedResponse()
        : response({
            'models': [
              model('gemini-2.5-flash', name: '기존 모델'),
              model('gemini-10.0-pro', name: '새 Pro'),
              model('gemini-10.0-flash', name: '최신 Flash'),
              model('gemini-11.0-flash-preview', name: '미리보기 모델'),
            ],
          }),
  ),
);

class BrokenStore extends LocalStore {
  BrokenStore(super.preferences);
  bool fail = false;
  @override
  Future<void> save() async {
    if (fail) throw StateError('disk full');
    await super.save();
  }
}

Future<void> openPage(
  WidgetTester tester, {
  required GeminiModelsService service,
  String initialKey = '',
  String initialModel = 'gemini-2.5-flash',
  SaveAiSettings? save,
  Future<bool> Function(Uri)? openLink,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => AiSetupPage(
                  initialKey: initialKey,
                  initialModel: initialModel,
                  service: service,
                  onSave: save ?? (_, _) async {},
                  openLink: openLink,
                ),
              ),
            ),
            child: const Text('설정 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('설정 열기'));
  await tester.pumpAndSettle();
}

Future<void> fetchModels(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('키 확인하고 공식 모델 불러오기'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('키 확인하고 공식 모델 불러오기'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'connection candidate prefers stable Flash over a newer general model',
    () {
      final list = GeminiModelList([
        GeminiModel.fromApi(model('gemini-4.0-argon'))!,
        GeminiModel.fromApi(model('gemini-3.8-flash'))!,
        GeminiModel.fromApi(model('gemini-4.1-flash-preview'))!,
      ]);
      expect(list.connectionCandidate!.id, 'gemini-3.8-flash');
    },
  );
  for (final entry in {
    'FreeTierRequestsPerDay': '무료 할당량이 0',
    'GenerateRequestsPerDay': '일일 한도',
    'GenerateRequestsPerMinute': '짧은 시간',
  }.entries) {
    test('quota metadata distinguishes ${entry.key} without raw message', () {
      final error = response({
        'error': {
          'message': 'secret-key must not appear',
          'details': [
            {
              '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
              'violations': [
                {'quotaId': entry.key, 'quotaValue': '0'},
              ],
            },
          ],
        },
      }, status: 429);
      final message = GeminiModelsService.quotaMessage(error);
      expect(message, contains(entry.value));
      expect(message, isNot(contains('secret-key')));
    });
  }
  test(
    'unknown quota metadata does not invent a retry or free-tier diagnosis',
    () {
      final message = GeminiModelsService.quotaMessage(
        http.Response('secret', 429),
      );
      expect(message, contains('확인되지 않았습니다'));
      expect(message, isNot(contains('secret')));
    },
  );
  testWidgets(
    'failed search blocks save; selecting another Flash can recover',
    (tester) async {
      var calls = 0, saves = 0;
      final api = GeminiModelsService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return response({
              'models': [model('gemini-3.8-flash'), model('gemini-3.7-flash')],
            });
          }
          calls++;
          if (request.url.path.contains('3.8')) {
            return response({
              'error': {
                'details': [
                  {
                    '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
                    'violations': [
                      {'quotaId': 'FreeTierRequestsPerDay', 'quotaValue': '0'},
                    ],
                  },
                ],
              },
            }, status: 429);
          }
          return groundedResponse();
        }),
      );
      addTearDown(api.close);
      await openPage(
        tester,
        service: api,
        initialKey: 'key',
        save: (_, _) async {
          saves++;
        },
      );
      await tester.tap(find.text('이 설정으로 저장'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(calls, 1);
      expect(find.textContaining('무료 할당량이 0'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('gemini-3.7-flash'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('gemini-3.7-flash')),
        alignment: 0.35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('gemini-3.7-flash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 설정으로 저장'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(saves, 1);
    },
  );

  test('official links use first-party HTTPS pages', () {
    expect(
      GeminiLinks.apiKeys.toString(),
      'https://aistudio.google.com/apikey',
    );
    for (final link in [
      GeminiLinks.keyHelp,
      GeminiLinks.models,
      GeminiLinks.pricing,
      GeminiLinks.regions,
    ]) {
      expect(link.scheme, 'https');
      expect(link.host, 'ai.google.dev');
    }
  });
  test(
    'models are fetched across pages with header authentication, filtered and numerically ranked',
    () async {
      var calls = 0;
      final api = GeminiModelsService(
        client: MockClient((r) async {
          calls++;
          expect(r.url.host, 'generativelanguage.googleapis.com');
          expect(r.url.path, '/v1beta/models');
          expect(r.headers['x-goog-api-key'], 'test-key');
          expect(r.url.queryParameters.containsKey('key'), false);
          if (calls == 1) {
            return response({
              'models': [
                model('gemini-3.1-pro'),
                model('gemini-10.0-flash'),
                model('gemini-10.0-flash-image'),
                model('gemini-10.0-pro', methods: ['embedContent']),
              ],
              'nextPageToken': 'page-two',
            });
          }
          expect(r.url.queryParameters['pageToken'], 'page-two');
          return response({
            'models': [
              model('gemini-11.0-flash-preview'),
              model('gemini-3.1-pro'),
              model('gemini-flash-latest'),
              model('gemini-1.5-flash'),
              model('gemini-10.0-flash-tts'),
              model('gemini-10.0-flash-live'),
            ],
          });
        }),
      );
      addTearDown(api.close);
      final result = await api.listModels(' test-key ');
      expect(calls, 2);
      expect(result.models.map((m) => m.id), [
        'gemini-11.0-flash-preview',
        'gemini-10.0-flash',
        'gemini-3.1-pro',
        'gemini-flash-latest',
      ]);
      expect(result.recommended!.id, 'gemini-10.0-flash');
      expect(result.additional.length, 2);
    },
  );
  test(
    'new Gemini text families do not require a hardcoded model list',
    () async {
      final api = GeminiModelsService(
        client: MockClient(
          (_) async => response({
            'models': [model('gemini-4.2-standard')],
          }),
        ),
      );
      addTearDown(api.close);
      final result = await api.listModels('key');
      expect(result.recommended!.id, 'gemini-4.2-standard');
    },
  );
  test(
    'stable Flash precedes Pro in the same generation; preview fallback is labelled',
    () {
      final list = GeminiModelList(
        [
          'gemini-3.1-pro',
          'gemini-3.1-flash-lite',
          'gemini-3.1-flash',
        ].map((id) => GeminiModel.fromApi(model(id))!),
      );
      expect(list.recommended!.id, 'gemini-3.1-flash');
      final onlyPreview = GeminiModelList([
        GeminiModel.fromApi(model('gemini-4.0-pro-preview'))!,
      ]);
      expect(onlyPreview.recommended!.preview, true);
      expect(onlyPreview.stable, isEmpty);
    },
  );
  test(
    'repeated pagination and empty compatible model lists fail without partial recommendations',
    () async {
      for (final body in [
        {
          'models': [model('gemini-3.0-flash')],
          'nextPageToken': 'loop',
        },
        {
          'models': [
            model('embedding-001', methods: ['embedContent']),
          ],
        },
      ]) {
        final api = GeminiModelsService(
          client: MockClient((_) async => response(body)),
        );
        addTearDown(api.close);
        await expectLater(api.listModels('key'), throwsFormatException);
      }
    },
  );
  for (final code in [400, 401, 403, 429, 500]) {
    test(
      'HTTP $code provides a safe error without echoing credential or response body',
      () async {
        final api = GeminiModelsService(
          client: MockClient(
            (_) async => response({'error': 'private-key-value'}, status: code),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          api.listModels('private-key-value'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              isNot(contains('private-key-value')),
            ),
          ),
        );
      },
    );
  }
  test(
    'search connection test sends only a public question and requires a complete grounded answer',
    () async {
      var calls = 0;
      final api = GeminiModelsService(
        client: MockClient((r) async {
          calls++;
          final body = jsonDecode(r.body) as Map;
          expect(body['tools'][0]['googleSearch'], isEmpty);
          expect(
            body['contents'][0]['parts'][0]['text'],
            contains('API 키 발급 페이지'),
          );
          expect(r.body, isNot(contains('private-key')));
          expect(r.url.queryParameters.containsKey('key'), false);
          return response({
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': '공식 안내 주소'},
                  ],
                },
                if (calls == 1)
                  'groundingMetadata': {
                    'groundingChunks': [
                      {
                        'web': {'uri': 'https://aistudio.google.com/apikey'},
                      },
                    ],
                  },
              },
            ],
          });
        }),
      );
      addTearDown(api.close);
      await api.testSearch('private-key', 'gemini-3.0-flash');
      await expectLater(
        api.testSearch('private-key', 'gemini-3.0-flash'),
        throwsFormatException,
      );
    },
  );
  test(
    'saving or deleting keys preserves goals and failed preferences save restores the prior secure key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = BrokenStore(await SharedPreferences.getInstance());
      const game = GameProfile(id: 'g', name: '게임');
      store.games.add(game);
      store.selectedId = game.id;
      await store.addManualGoal(game, '목표', '할 일', '메모');
      var key = 'old-key';
      final repo = AiSettingsRepository(
        store: store,
        readKey: () async => key,
        writeKey: (value) async {
          key = value ?? '';
        },
      );
      await repo.save('new-key', 'gemini-3.0-flash');
      expect(key, 'new-key');
      expect(store.model, 'gemini-3.0-flash');
      expect(
        store.preferences.getString('companion.v1'),
        isNot(contains('new-key')),
      );
      store.fail = true;
      await expectLater(
        repo.save('failed-key', 'gemini-4.0-flash'),
        throwsStateError,
      );
      expect(key, 'new-key');
      expect(store.model, 'gemini-3.0-flash');
      expect(store.goals.single.title, '목표');
      store.fail = false;
      await repo.save('', 'gemini-3.0-flash');
      expect(key, '');
      expect((LocalStore(store.preferences)..load()).goals.length, 1);
    },
  );
  testWidgets(
    'beginner opens AI Studio, fetches official models and saves the newest stable choice',
    (tester) async {
      final api = fakeCatalog();
      addTearDown(api.close);
      Uri? opened;
      String? savedKey, savedModel;
      await openPage(
        tester,
        service: api,
        openLink: (uri) async {
          opened = uri;
          return true;
        },
        save: (key, model) async {
          savedKey = key;
          savedModel = model;
        },
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '이 설정으로 저장'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('AI Studio에서 API 키 만들기'));
      await tester.pumpAndSettle();
      expect(opened, GeminiLinks.apiKeys);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('api-key-input')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('api-key-input')),
        'test-key',
      );
      await fetchModels(tester);
      await tester.tap(find.text('이 설정으로 저장'));
      await tester.pumpAndSettle();
      expect(savedKey, 'test-key');
      expect(savedModel, 'gemini-10.0-flash');
      expect(find.text('설정 열기'), findsOneWidget);
    },
  );
  testWidgets(
    'existing model is retained and latest recommendation is offered explicitly',
    (tester) async {
      final api = fakeCatalog();
      addTearDown(api.close);
      String? savedModel;
      await openPage(
        tester,
        service: api,
        initialKey: 'existing-key',
        save: (_, model) async => savedModel = model,
      );
      expect(find.text('선택: 기존 모델'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('최신 Flash 후보 선택: 최신 Flash'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('최신 Flash 후보 선택: 최신 Flash')),
        alignment: 0.35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('최신 Flash 후보 선택: 최신 Flash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이 설정으로 저장'));
      await tester.pumpAndSettle();
      expect(savedModel, 'gemini-10.0-flash');
    },
  );
  testWidgets('a stale response cannot validate a different pasted key', (
    tester,
  ) async {
    final delayed = Completer<http.Response>();
    final api = GeminiModelsService(client: MockClient((_) => delayed.future));
    addTearDown(api.close);
    await openPage(tester, service: api);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('api-key-input')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('api-key-input')),
      'first-key',
    );
    await tester.ensureVisible(find.text('키 확인하고 공식 모델 불러오기'));
    await tester.tap(find.text('키 확인하고 공식 모델 불러오기'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('api-key-input')));
    await tester.enterText(
      find.byKey(const ValueKey('api-key-input')),
      'second-key',
    );
    delayed.complete(
      response({
        'models': [model('gemini-3.0-flash')],
      }),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '이 설정으로 저장'))
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'API key deletion is explicit and confirmed separately from model saving',
    (tester) async {
      final api = fakeCatalog();
      addTearDown(api.close);
      String? saved;
      await openPage(
        tester,
        service: api,
        initialKey: 'existing-key',
        save: (key, _) async => saved = key,
      );
      await tester.scrollUntilVisible(
        find.text('저장한 API 키 삭제'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('저장한 API 키 삭제')),
        alignment: 0.35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장한 API 키 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await Scrollable.ensureVisible(
        tester.element(find.text('저장한 API 키 삭제')),
        alignment: 0.35,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장한 API 키 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('키 삭제'));
      await tester.pumpAndSettle();
      expect(saved, '');
    },
  );
  testWidgets('failed save keeps entered settings available for retry', (
    tester,
  ) async {
    final api = fakeCatalog();
    addTearDown(api.close);
    await openPage(
      tester,
      service: api,
      initialKey: 'existing-key',
      save: (_, _) async => throw StateError('storage'),
    );
    await tester.tap(find.text('이 설정으로 저장'));
    await tester.pumpAndSettle();
    expect(find.text('AI 연결 안내'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('연결 정보를 저장하지 못했습니다'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '이 설정으로 저장'))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('clipboard is read only after the explicit paste action', (
    tester,
  ) async {
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            reads++;
            return {'text': '  pasted-test-key  '};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final api = fakeCatalog();
    addTearDown(api.close);
    await openPage(tester, service: api);
    expect(reads, 0);
    await tester.scrollUntilVisible(
      find.text('복사한 키 붙여넣기'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('복사한 키 붙여넣기'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('api-key-input')))
          .controller!
          .text,
      'pasted-test-key',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '이 설정으로 저장'))
          .onPressed,
      isNull,
    );
  });
}
