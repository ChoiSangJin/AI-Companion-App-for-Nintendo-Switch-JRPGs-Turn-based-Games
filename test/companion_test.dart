import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_companion/main.dart';
import 'package:switch_companion/models/models.dart';
import 'package:switch_companion/services/gemini.dart';
import 'package:switch_companion/services/storage.dart';

Map<String, dynamic> sample() => {
  'title': '테스트 약점',
  'category': 'weakness',
  'summary': '얼음',
  'items': [
    {'label': '속성', 'value': '얼음', 'note': '', 'isChecked': false},
  ],
};
const game = GameProfile(id: 'g1', name: '테스트 게임', rules: 'Switch 리마스터');
http.Response jsonResponse(
  String body,
  int status, {
  Map<String, String>? headers,
}) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  test('JSON and fenced JSON parse; malformed data is rejected', () {
    expect(
      GeminiService.parseObject(
        '```json\n${jsonEncode(sample())}\n```',
      )['title'],
      '테스트 약점',
    );
    expect(() => GeminiService.parseObject('[]'), throwsFormatException);
    expect(
      () => GuideItem.fromJson({'label': 3, 'value': 'x'}),
      throwsFormatException,
    );
    expect(
      () => GuideData.fromJson({...sample(), 'items': []}),
      throwsFormatException,
    );
  });
  test(
    'game, selected context, guide edits and checkbox survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      store.games.add(game);
      store.selectedId = game.id;
      store.guides.add(
        GuideData.fromJson({...sample(), 'id': 'guide', 'gameId': game.id}),
      );
      store.guides.first.items.first.isChecked = true;
      await store.save();
      final loaded = LocalStore(prefs)..load();
      expect(loaded.games.single.rules, game.rules);
      expect(loaded.selectedId, game.id);
      expect(loaded.guides.single.items.single.isChecked, true);
      loaded.guides.clear();
      await loaded.save();
      expect((LocalStore(prefs)..load()).guides, isEmpty);
    },
  );
  test('corrupt saved data raises instead of silently overwriting', () async {
    SharedPreferences.setMockInitialValues({'companion.v1': 'broken'});
    final store = LocalStore(await SharedPreferences.getInstance());
    expect(store.load, throwsFormatException);
    expect(store.preferences.getString('companion.v1'), 'broken');
  });
  test(
    'grounded request includes selected game, system rules and sources',
    () async {
      final service = GeminiService(
        client: MockClient((request) async {
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(request.url.query, isEmpty);
          expect(request.headers['x-goog-api-key'], 'test-key');
          final sent = jsonDecode(request.body) as Map;
          expect(sent['tools'][0]['googleSearch'], isEmpty);
          expect(
            sent['systemInstruction']['parts'][0]['text'],
            contains('Switch 2'),
          );
          expect(sent['contents'][0]['parts'][0]['text'], contains(game.name));
          return jsonResponse(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': '```json\n${jsonEncode(sample())}\n```'},
                    ],
                  },
                  'groundingMetadata': {
                    'groundingChunks': [
                      {
                        'web': {'title': '출처', 'uri': 'https://example.com'},
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final guide = await service.request(
        key: 'test-key',
        model: 'gemini-2.5-flash',
        game: game,
        category: 'weakness',
        text: '약점',
        convert: false,
      );
      expect(guide.gameId, game.id);
      expect(guide.sources.single['title'], '출처');
    },
  );
  test(
    'conversion excludes search tool and resets generated completion',
    () async {
      final service = GeminiService(
        client: MockClient((request) async {
          final sent = jsonDecode(request.body) as Map;
          expect(sent.containsKey('tools'), false);
          expect(
            sent['generationConfig']['responseMimeType'],
            'application/json',
          );
          final data = sample();
          data['items'][0]['isChecked'] = true;
          return jsonResponse(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': jsonEncode(data)},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      final guide = await service.request(
        key: 'key',
        model: 'gemini-2.5-flash',
        game: game,
        category: 'weakness',
        text: '순서',
        convert: true,
      );
      expect(guide.category, 'checklist');
      expect(guide.items.single.isChecked, false);
    },
  );
  for (final status in [400, 403, 404, 429, 500]) {
    test(
      'HTTP $status yields safe error without response body or key',
      () async {
        final service = GeminiService(
          client: MockClient(
            (_) async => jsonResponse('sensitive-body', status),
          ),
        );
        addTearDown(service.close);
        expect(
          service.request(
            key: 'secret',
            model: 'gemini-2.5-flash',
            game: game,
            category: 'weakness',
            text: 'x',
            convert: false,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              isNot(contains('sensitive-body')),
            ),
          ),
        );
      },
    );
  }
  test('ungrounded answers and incomplete responses are rejected', () async {
    for (final finish in ['STOP', 'MAX_TOKENS']) {
      final service = GeminiService(
        client: MockClient(
          (_) async => jsonResponse(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': finish,
                  'content': {
                    'parts': [
                      {'text': jsonEncode(sample())},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      await expectLater(
        service.request(
          key: 'key',
          model: 'gemini-2.5-flash',
          game: game,
          category: 'weakness',
          text: 'x',
          convert: false,
        ),
        throwsFormatException,
      );
      service.close();
    }
  });
  testWidgets('no preset games; add game, switch tabs and restore context', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(CompanionApp(store: store));
    expect(find.text('첫 게임 추가'), findsOneWidget);
    await tester.tap(find.text('첫 게임 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '페르소나 4 골든');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(store.games.single.name, '페르소나 4 골든');
    await tester.tap(find.text('내 공략집'));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장된 공략이 없습니다'), findsOneWidget);
    final loaded = LocalStore(store.preferences)..load();
    expect(loaded.selectedId, store.games.single.id);
  });
  testWidgets('offline checklist updates persist, hide and search work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    store.games.add(game);
    store.selectedId = game.id;
    store.guides.add(
      GuideData.fromJson({
        ...sample(),
        'id': 'offline',
        'gameId': game.id,
        'category': 'checklist',
      }),
    );
    await store.save();
    await tester.pumpWidget(CompanionApp(store: store));
    await tester.tap(find.text('내 공략집'));
    await tester.pumpAndSettle();
    expect(find.text('속성'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      (LocalStore(
        store.preferences,
      )..load()).guides.single.items.single.isChecked,
      true,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('속성'), findsNothing);
    await tester.enterText(find.byType(TextField), '없는 공략');
    await tester.pumpAndSettle();
    expect(find.text('테스트 약점'), findsNothing);
    expect(find.textContaining('저장된 공략이 없습니다'), findsOneWidget);
  });
}
