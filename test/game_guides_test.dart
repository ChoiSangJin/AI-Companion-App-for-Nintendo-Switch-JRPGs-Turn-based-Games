import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_companion/data/game_catalog.dart';
import 'package:switch_companion/main.dart';
import 'package:switch_companion/models/models.dart';
import 'package:switch_companion/services/gemini.dart';
import 'package:switch_companion/services/guide_repository.dart';
import 'package:switch_companion/services/storage.dart';
import 'package:switch_companion/widgets/game_picker.dart';

GameDefinition entry(String id) => gameCatalog.singleWhere((g) => g.id == id);
Map<String, dynamic> payload(
  String category, {
  String? scope,
  bool checked = false,
}) => {
  'title': '확인한 공략',
  'category': category,
  'summary': '짧은 추천',
  'scope': ?scope,
  'items': [
    {
      'label': '디미트리',
      'value': '최종 직업',
      'note': '선택 루트 확인',
      'isChecked': checked,
      'reason': '역할 보완',
      'availability': '해당 구간에서 입수',
      'deadline': '선택 구간 종료 전',
      'alternatives': ['대체 직업'],
      'steps': [
        {'label': '초기', 'value': '기초 직업', 'condition': '숙련도 조건 확인'},
      ],
    },
  ],
};
http.Response grounded(Map<String, dynamic> data) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'candidates': [
        {
          'finishReason': 'STOP',
          'content': {
            'parts': [
              {'text': jsonEncode(data)},
            ],
          },
          'groundingMetadata': {
            'groundingChunks': [
              {
                'web': {'title': '공략 출처', 'uri': 'https://example.com/guide'},
              },
            ],
          },
        },
      ],
    }),
  ),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
GuideData cached(
  GameProfile game,
  GuideTopic topic, {
  String target = '',
  String model = 'gemini-2.5-flash',
}) => GuideData.fromJson({
  ...payload(topic.id),
  'id': '${topic.id}-$target',
  'gameId': game.id,
  'contextKey': GeminiService.contextKey(game, topic, target, model),
  'topic': topic.id,
  'target': target,
  'progress': topic == GuideTopic.roster ? '' : game.progress,
  'contextRules': game.rules,
  'createdAt': '2026-10-29T00:00:00Z',
});
Future<LocalStore> emptyStore() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStore(await SharedPreferences.getInstance());
}

class FailingStore extends LocalStore {
  FailingStore(super.preferences);
  bool fail = false;
  @override
  Future<void> save() async {
    if (fail) throw StateError('disk full');
    await super.save();
  }
}

void main() {
  test(
    'series search returns exact Switch editions and unique catalog identities',
    () {
      final pokemon = searchGames('포켓몬');
      expect(pokemon.length, greaterThan(8));
      expect(pokemon.every((g) => g.style == GameStyle.pokemon), true);
      expect(pokemon.any((g) => g.name.contains('스칼렛')), true);
      expect(pokemon.any((g) => g.name.contains('바이올렛')), true);
      expect(pokemon.any((g) => g.platform == 'Nintendo Switch 2'), true);
      expect(searchGames('3DS'), isEmpty);
      expect(searchGames('파엠').map((g) => g.id), contains('fe-fortunes-weave'));
      expect(searchGames('페르소나').length, 3);
      expect(gameCatalog.map((g) => g.id).toSet().length, gameCatalog.length);
      expect(
        gameCatalog.every((g) => Uri.parse(g.reference).scheme == 'https'),
        true,
      );
    },
  );
  test('menus and progression controls are selected by game systems', () {
    expect(entry('fe-engage').topics, contains(GuideTopic.roster));
    expect(entry('pokemon-violet').topics, isNot(contains(GuideTopic.roster)));
    expect(entry('pokemon-violet').topics, contains(GuideTopic.party));
    expect(entry('persona-4-golden').progressOptions, contains('5월'));
    expect(entry('fe-engage').progressOptions, isEmpty);
    expect(entry('fe-fortunes-weave').verifyAvailability, true);
    expect(
      definitionFor(const GameProfile(id: 'legacy', name: '페르소나 4 골든'))?.style,
      GameStyle.calendar,
    );
  });
  test(
    'legacy save upgrades without losing games, guides or completion',
    () async {
      SharedPreferences.setMockInitialValues({
        'companion.v1': jsonEncode({
          'games': [
            {'id': 'old', 'name': '페르소나 4 골든', 'rules': '기존 조건'},
          ],
          'guides': [
            {
              'id': 'old-guide',
              'gameId': 'old',
              'title': '기존 공략',
              'category': 'checklist',
              'summary': '기존',
              'items': [
                {'label': '기존 할 일', 'value': '완료', 'isChecked': true},
              ],
            },
          ],
          'selectedId': 'old',
          'model': 'gemini-2.5-flash',
        }),
      });
      final store = LocalStore(await SharedPreferences.getInstance())..load();
      store.games[0] = store.games[0].copyWith(progress: '5월');
      await store.save();
      final loaded = LocalStore(store.preferences)..load();
      expect(loaded.selectedId, 'old');
      expect(loaded.games.single.progress, '5월');
      expect(loaded.games.single.rules, '기존 조건');
      expect(loaded.guides.single.items.single.isChecked, true);
    },
  );
  test(
    'rich recommendations roundtrip, search and reject malformed fields',
    () {
      final game = entry(
        'fe-engage',
      ).profile().copyWith(rules: '하드', progress: '5장');
      final guide = cached(game, GuideTopic.build, target: '디미트리');
      final restored = GuideData.fromJson(guide.toJson());
      expect(restored.items.single.steps.single.condition, '숙련도 조건 확인');
      expect(restored.items.single.searchText, contains('대체 직업'));
      expect(restored.contextRules, '하드');
      expect(restored.progress, '5장');
      expect(
        () => GuideItem.fromJson({'label': 'x', 'value': 'y', 'steps': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => GuideItem.fromJson({
          'label': 'x',
          'value': 'y',
          'alternatives': [1],
        }),
        throwsFormatException,
      );
    },
  );
  test('cache separates edition, character, rules, model and progression', () {
    final a = entry('pokemon-scarlet').profile();
    final b = entry('pokemon-violet').profile();
    String key(GameProfile g, {String target = '', String model = 'model'}) =>
        GeminiService.contextKey(g, GuideTopic.party, target, model);
    expect(key(a), isNot(key(b)));
    expect(key(a), isNot(key(a.copyWith(progress: '3장'))));
    expect(key(a), isNot(key(a.copyWith(rules: 'DLC 있음'))));
    expect(key(a), isNot(key(a, model: 'other')));
    expect(key(a, target: 'A'), isNot(key(a, target: 'B')));
    expect(
      GeminiService.contextKey(a, GuideTopic.roster, '', 'm'),
      GeminiService.contextKey(
        a.copyWith(progress: '3장'),
        GuideTopic.roster,
        '',
        'm',
      ),
    );
  });
  test(
    'guided request injects exact edition, progression and task schema',
    () async {
      final game = entry(
        'persona-4-golden',
      ).profile().copyWith(progress: '5월', rules: '첫 회차');
      final api = GeminiService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          final context =
              jsonDecode(body['contents'][0]['parts'][0]['text'] as String)
                  as Map;
          expect(context['game'], game.name);
          expect(context['progress'], '5월');
          expect(context['customRules'], '첫 회차');
          expect(context['category'], 'missables');
          expect(context['scopeRule'], contains('미래'));
          expect(context['task'], contains('deadline'));
          expect(body['tools'][0]['googleSearch'], isEmpty);
          return grounded(payload('missables', scope: '5월'));
        }),
      );
      addTearDown(api.close);
      final guide = await api.request(
        key: 'key',
        model: 'model',
        game: game,
        category: 'missables',
        text: '',
        convert: false,
        topic: GuideTopic.missables,
      );
      expect(guide.isChecklist, true);
      expect(guide.progress, '5월');
      expect(guide.contextRules, '첫 회차');
      expect(guide.sources.single['uri'], 'https://example.com/guide');
    },
  );
  test(
    'wrong progression and unavailable games never become saved recommendations',
    () async {
      for (final data in [
        payload('missables', scope: '6월'),
        {'status': 'unavailable'},
      ]) {
        final store = await emptyStore();
        final game = entry(
          'persona-4-golden',
        ).profile().copyWith(progress: '5월');
        final api = GeminiService(
          client: MockClient((_) async => grounded(data)),
        );
        addTearDown(api.close);
        await expectLater(
          GuideRepository(
            store,
            api,
          ).load(game: game, topic: GuideTopic.missables, key: 'key'),
          throwsFormatException,
        );
        expect(store.guides, isEmpty);
      }
    },
  );
  test(
    'missing progression or character is rejected before spending an API request',
    () async {
      var calls = 0;
      final store = await emptyStore();
      final api = GeminiService(
        client: MockClient((_) async {
          calls++;
          return grounded(payload('party'));
        }),
      );
      addTearDown(api.close);
      final repo = GuideRepository(store, api);
      final game = entry('persona-4-golden').profile();
      await expectLater(
        repo.load(game: game, topic: GuideTopic.missables, key: 'key'),
        throwsFormatException,
      );
      await expectLater(
        repo.load(game: game, topic: GuideTopic.build, key: 'key'),
        throwsFormatException,
      );
      expect(calls, 0);
    },
  );
  test(
    'grounded results autosave and work offline after restart without an API key',
    () async {
      var calls = 0;
      final store = await emptyStore();
      final game = entry('pokemon-violet').profile();
      final api = GeminiService(
        client: MockClient((_) async {
          calls++;
          return grounded(payload('party'));
        }),
      );
      addTearDown(api.close);
      final first = await GuideRepository(
        store,
        api,
      ).load(game: game, topic: GuideTopic.party, key: 'key');
      final loaded = LocalStore(store.preferences)..load();
      final offline = GeminiService(
        client: MockClient(
          (_) async => throw StateError('must not access network'),
        ),
      );
      addTearDown(offline.close);
      final again = await GuideRepository(
        loaded,
        offline,
      ).load(game: game, topic: GuideTopic.party, key: '');
      expect(again.id, first.id);
      expect(calls, 1);
      expect(again.items.single.alternatives, ['대체 직업']);
    },
  );
  test(
    'refresh preserves checked tasks and failed refresh keeps previous guide',
    () async {
      final store = await emptyStore();
      final game = entry('persona-4-golden').profile().copyWith(progress: '5월');
      final old = cached(game, GuideTopic.missables);
      old.items.first.isChecked = true;
      store.putGuide(old);
      await store.save();
      final api = GeminiService(
        client: MockClient(
          (_) async => grounded(payload('missables', scope: '5월')),
        ),
      );
      addTearDown(api.close);
      final updated = await GuideRepository(store, api).load(
        game: game,
        topic: GuideTopic.missables,
        key: 'key',
        refresh: true,
      );
      expect(updated.items.single.isChecked, true);
      expect(store.guides.length, 1);
      final failed = GeminiService(
        client: MockClient((_) async => http.Response('unavailable', 500)),
      );
      addTearDown(failed.close);
      await expectLater(
        GuideRepository(store, failed).load(
          game: game,
          topic: GuideTopic.missables,
          key: 'key',
          refresh: true,
        ),
        throwsFormatException,
      );
      expect(store.guides.single.id, updated.id);
    },
  );
  testWidgets('Pokemon search selects edition and shows relevant dashboard', (
    tester,
  ) async {
    final store = await emptyStore();
    await tester.pumpWidget(CompanionApp(store: store));
    await tester.tap(find.text('게임 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '포켓몬');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('포켓몬스터 스칼렛'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('포켓몬스터 스칼렛'));
    await tester.pumpAndSettle();
    expect(store.games.single.catalogId, 'pokemon-scarlet');
    expect(find.text('스토리 추천 파티'), findsOneWidget);
    expect(find.text('캐릭터별 추천 직업·육성'), findsNothing);
    expect(
      (LocalStore(store.preferences)..load()).selectedId,
      'pokemon-scarlet',
    );
  });
  testWidgets('picker platform filter excludes original Switch editions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GamePickerPage()));
    await tester.tap(find.text('Switch 2'));
    await tester.pumpAndSettle();
    expect(find.text('포켓몬스터 스칼렛'), findsNothing);
    expect(
      find.text('Pokémon LEGENDS Z-A Nintendo Switch 2 Edition'),
      findsOneWidget,
    );
  });
  testWidgets('cached character roster drills into offline job tree', (
    tester,
  ) async {
    final store = await emptyStore();
    final game = entry('fe-three-houses').profile();
    store.games.add(game);
    store.selectedId = game.id;
    store.putGuide(cached(game, GuideTopic.roster));
    store.putGuide(cached(game, GuideTopic.build, target: '디미트리'));
    await store.save();
    await tester.pumpWidget(CompanionApp(store: store));
    await tester.tap(find.text('캐릭터별 추천 직업·육성'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('디미트리'));
    await tester.pumpAndSettle();
    expect(find.text('초기 · 기초 직업'), findsOneWidget);
    expect(find.text('숙련도 조건 확인'), findsOneWidget);
    expect(find.textContaining('자동 저장됨'), findsOneWidget);
  });
  testWidgets(
    'Persona missables require a month, persist it and load its cached checklist',
    (tester) async {
      final store = await emptyStore();
      final game = entry('persona-4-golden').profile();
      store.games.add(game);
      store.selectedId = game.id;
      store.putGuide(
        cached(game.copyWith(progress: '5월'), GuideTopic.missables),
      );
      await store.save();
      await tester.pumpWidget(CompanionApp(store: store));
      await tester.scrollUntilVisible(
        find.text('놓치기 쉬운 요소'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('놓치기 쉬운 요소'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('현재 월 선택'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5월').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('확인 구간: 5월'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final loaded = LocalStore(store.preferences)..load();
      expect(loaded.games.single.progress, '5월');
      expect(loaded.guides.single.items.single.isChecked, true);
    },
  );
  test('wrong topic and incomplete structured builds are rejected', () async {
    final game = entry('fe-three-houses').profile();
    final bad = payload('build');
    (bad['items'] as List).first['steps'] = [];
    for (final response in [payload('party'), bad]) {
      final store = await emptyStore();
      final api = GeminiService(
        client: MockClient((_) async => grounded(response)),
      );
      addTearDown(api.close);
      await expectLater(
        GuideRepository(
          store,
          api,
        ).load(game: game, topic: GuideTopic.build, target: '디미트리', key: 'key'),
        throwsFormatException,
      );
      expect(store.guides, isEmpty);
    }
  });
  test('failed autosave restores the previous offline guide', () async {
    final initial = await emptyStore();
    final store = FailingStore(initial.preferences);
    final game = entry('pokemon-violet').profile();
    final old = cached(game, GuideTopic.party);
    store.putGuide(old);
    await store.save();
    store.fail = true;
    final api = GeminiService(
      client: MockClient((_) async => grounded(payload('party'))),
    );
    addTearDown(api.close);
    await expectLater(
      GuideRepository(
        store,
        api,
      ).load(game: game, topic: GuideTopic.party, key: 'key', refresh: true),
      throwsStateError,
    );
    expect(store.guides.single, same(old));
    expect((LocalStore(store.preferences)..load()).guides.single.id, old.id);
  });
  testWidgets(
    'catalog selection reuses an existing manual game and its guides',
    (tester) async {
      final store = await emptyStore();
      const old = GameProfile(
        id: 'existing',
        name: '페르소나 4 골든',
        rules: '첫 회차',
        progress: '5월',
      );
      store.games.add(old);
      store.selectedId = old.id;
      store.putGuide(cached(old, GuideTopic.missables));
      await store.save();
      await tester.pumpWidget(CompanionApp(store: store));
      await tester.scrollUntilVisible(
        find.text('다른 게임 찾기'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('다른 게임 찾기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '페르소나 4');
      await tester.pumpAndSettle();
      await tester.tap(find.text('페르소나 4 골든'));
      await tester.pumpAndSettle();
      expect(store.games.length, 1);
      expect(store.games.single.id, 'existing');
      expect(store.games.single.progress, '5월');
      expect(store.games.single.rules, '첫 회차');
      expect(store.guides.single.gameId, 'existing');
    },
  );
  testWidgets(
    'offline guide edits preserve the structured path and rich search',
    (tester) async {
      final store = await emptyStore();
      final game = entry('fe-three-houses').profile();
      store.games.add(game);
      store.selectedId = game.id;
      store.putGuide(cached(game, GuideTopic.build, target: '디미트리'));
      await store.save();
      await tester.pumpWidget(CompanionApp(store: store));
      await tester.tap(find.text('내 공략집'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('수정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '내 육성 경로');
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      final reloaded = LocalStore(store.preferences)..load();
      expect(reloaded.guides.single.title, '내 육성 경로');
      expect(
        reloaded.guides.single.items.single.steps.single.condition,
        '숙련도 조건 확인',
      );
      expect(reloaded.guides.single.target, '디미트리');
      await tester.drag(find.byType(ListView).last, const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '숙련도');
      await tester.pumpAndSettle();
      expect(find.text('내 육성 경로'), findsOneWidget);
    },
  );
}
