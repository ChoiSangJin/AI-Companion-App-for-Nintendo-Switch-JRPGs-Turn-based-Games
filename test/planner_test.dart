import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_companion/data/paldea.dart';
import 'package:switch_companion/main.dart';
import 'package:switch_companion/services/planner_store.dart';
import 'package:switch_companion/widgets/planner_pages.dart';

late PaldeaData data;
Future<PlannerStore> fresh({
  Map<String, Object> initial = const {},
  Future<bool> Function(String, String)? write,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  return PlannerStore(await SharedPreferences.getInstance(), data, write: write)
    ..load();
}

Future<void> app(
  WidgetTester tester,
  PlannerStore store, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(PaldeaApp(store: store));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.35);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    data = PaldeaData.fromJson(
      jsonDecode(File('assets/data/paldea.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });
  test(
    'bundled guides have valid edition branches and 18 ordered objectives',
    () {
      expect(data.lines.length, 24);
      expect(data.route.length, 18);
      expect(
        [
          for (final kind in ['체육관', '주인', '스타단'])
            data.route.where((r) => r.kind == kind).length,
        ],
        [8, 5, 5],
      );
      expect(
        data.route.map((r) => r.level),
        orderedEquals([...data.route.map((r) => r.level)]..sort()),
      );
      expect(
        data.available('scarlet', 'sprigatito').any((l) => l.id == 'bagon'),
        false,
      );
      expect(
        data.available('violet', 'sprigatito').any((l) => l.id == 'larvitar'),
        false,
      );
      expect(data.line('charcadet-scarlet').conditions.single, contains('동미러'));
      expect(data.line('charcadet-violet').conditions.single, contains('데인차'));
      expect(data.line('pawmi').conditions.last, contains('1,000보'));
      expect(data.line('mankey').conditions.last, contains('20회'));
      for (final l in data.lines) {
        expect(l.forms.length - 1, l.conditions.length);
        expect(Uri.parse(l.source).scheme, 'https');
      }
      for (final starter in ['sprigatito', 'fuecoco', 'quaxly']) {
        final rec = data.recommended('scarlet', starter);
        expect(rec.length, 6);
        expect(rec.first.id, starter);
        expect(rec.where((l) => l.starter).length, 1);
      }
    },
  );
  test('search resolves Korean evolution names English and dex numbers', () {
    final line = data.line('sprigatito');
    for (final q in ['마스카나', 'Meowscarada', '908']) {
      expect(line.matches(q), true);
    }
    expect(line.matches('없는포켓몬'), false);
  });
  test(
    'type chart handles fourfold weaknesses immunity and duplicate types',
    () {
      expect(data.effectiveness('얼음', ['땅', '드래곤']), 4);
      expect(data.effectiveness('전기', ['땅', '물']), 0);
      expect(data.effectiveness('격투', ['고스트']), 0);
      expect(data.effectiveness('불꽃', ['풀', '풀']), 2);
      expect(data.effectiveness('페어리', ['악', '드래곤']), 4);
      expect(data.typeChart.length, 18);
      for (final row in data.typeChart.values) {
        expect(row.length, 18);
      }
    },
  );
  test('legacy data including corrupt old JSON remains untouched', () async {
    for (final raw in [
      'broken',
      jsonEncode({'games': [], 'guides': [], 'goals': []}),
    ]) {
      final s = await fresh(initial: {'companion.v1': raw});
      await s.addTask('새 기록', '');
      expect(s.legacyRaw, raw);
      expect(s.preferences.getString('companion.v1'), raw);
    }
  });
  test(
    'party evolution route and tasks reload independently per edition',
    () async {
      final s = await fresh();
      await s.chooseStarter('sprigatito');
      await s.addMember('sprigatito');
      await s.updateMember('sprigatito', evolution: 1, memo: '풀 파트너');
      await s.completeRoute('cortondo', true);
      await s.addTask('회복 도구', '10개');
      await s.selectEdition('violet');
      expect(s.adventure.party, isEmpty);
      await s.chooseStarter('fuecoco');
      await s.addMember('fuecoco');
      final loaded = PlannerStore(s.preferences, data)..load();
      expect(loaded.edition, 'violet');
      expect(loaded.adventure.party.single.lineId, 'fuecoco');
      await loaded.selectEdition('scarlet');
      expect(loaded.adventure.party.single.evolution, 1);
      expect(loaded.adventure.party.single.memo, '풀 파트너');
      expect(loaded.adventure.completed, {'cortondo'});
      expect(loaded.adventure.tasks.single.title, '회복 도구');
    },
  );
  test(
    'six slots deduplication exclusive versions and starter choice enforced',
    () async {
      final s = await fresh();
      await expectLater(s.addMember('sprigatito'), throwsFormatException);
      await expectLater(s.addMember('bagon'), throwsFormatException);
      for (final id in [
        'pawmi',
        'nacli',
        'smoliv',
        'tinkatink',
        'mankey',
        'ralts',
      ]) {
        await s.addMember(id);
      }
      await s.addMember('pawmi');
      expect(s.adventure.party.length, 6);
      await expectLater(s.addMember('magikarp'), throwsFormatException);
      await s.removeMember('ralts');
      await s.addMember('magikarp');
      expect(s.adventure.party.last.lineId, 'magikarp');
    },
  );
  test(
    'capture undo clears evolution and impossible steps never persist',
    () async {
      final s = await fresh();
      await s.addMember('pawmi');
      await expectLater(
        s.updateMember('pawmi', evolution: 1),
        throwsFormatException,
      );
      await s.updateMember('pawmi', captured: true, evolution: 2);
      await expectLater(
        s.updateMember('pawmi', evolution: 3),
        throwsFormatException,
      );
      expect(s.adventure.party.single.evolution, 2);
      await s.updateMember('pawmi', captured: false);
      expect(s.adventure.party.single.evolution, 0);
    },
  );
  test(
    'manual tasks edit complete reopen and source pins deduplicate',
    () async {
      final s = await fresh();
      await expectLater(s.addTask(' ', ''), throwsFormatException);
      await s.addTask('포획 준비', '', sourceId: 'pawmi');
      await s.addTask('중복', '', sourceId: 'pawmi');
      expect(s.adventure.tasks.length, 1);
      final id = s.adventure.tasks.single.id;
      await s.updateTask(id, done: true, title: '볼 구매', memo: '10개');
      expect(s.adventure.tasks.single.done, true);
      await s.updateTask(id, done: false);
      expect(s.adventure.tasks.single.done, false);
      await s.removeTask(id);
      expect(s.adventure.tasks, isEmpty);
    },
  );
  test(
    'failed disk write leaves committed state intact and permits retry',
    () async {
      var fail = false;
      final saved = <String>[];
      final s = await fresh(
        write: (_, value) async {
          if (fail) return false;
          saved.add(value);
          return true;
        },
      );
      await s.addMember('pawmi');
      final previous = s.backup();
      fail = true;
      await expectLater(
        s.updateMember('pawmi', captured: true),
        throwsStateError,
      );
      expect(s.backup(), previous);
      expect(saved.last, jsonEncode(s.state.toJson()));
      fail = false;
      await s.updateMember('pawmi', captured: true);
      expect(s.adventure.party.single.captured, true);
    },
  );
  test(
    'queued writes retain the originating adventure across version switches',
    () async {
      final gate = Completer<bool>();
      var first = true;
      final s = await fresh(
        write: (_, value) async {
          if (first) {
            first = false;
            return gate.future;
          }
          return true;
        },
      );
      final switching = s.selectEdition('violet');
      final oldScreenTask = s.addTask('스칼렛 화면에서 추가', '');
      gate.complete(true);
      await Future.wait([switching, oldScreenTask]);
      expect(s.adventure.tasks, isEmpty);
      expect(s.state.adventures['scarlet']!.tasks.single.title, '스칼렛 화면에서 추가');
    },
  );
  test(
    'backup restores both profiles and rejects malformed imports without loss',
    () async {
      final s = await fresh();
      await s.addMember('pawmi');
      await s.completeRoute('klawf', true);
      final snapshot = s.backup();
      await s.removeMember('pawmi');
      await s.restore(snapshot);
      expect(s.adventure.party.single.lineId, 'pawmi');
      expect(s.adventure.completed, {'klawf'});
      for (final invalid in [
        'broken',
        '{"schema":99}',
        snapshot.replaceAll('klawf', 'invalid-route'),
      ]) {
        await expectLater(s.restore(invalid), throwsA(anything));
        expect(s.backup(), snapshot);
      }
    },
  );
  test('corrupt current save is reported without overwriting', () async {
    SharedPreferences.setMockInitialValues({PlannerStore.storageKey: 'broken'});
    final prefs = await SharedPreferences.getInstance();
    expect(() => (PlannerStore(prefs, data)..load()), throwsFormatException);
    expect(prefs.getString(PlannerStore.storageKey), 'broken');
  });
  testWidgets('offline onboarding search pin and evolution flow', (
    tester,
  ) async {
    final s = await fresh();
    await app(tester, s);
    expect(find.text('팔데아 플래너'), findsOneWidget);
    expect(find.textContaining('API 키'), findsNothing);
    await tapVisible(tester, find.text('나오하'));
    expect(s.adventure.starter, 'sprigatito');
    await tester.tap(find.text('파티 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pokemon-search')),
      '마스카나',
    );
    await tester.pumpAndSettle();
    expect(find.text('나오하'), findsOneWidget);
    await tester.tap(find.text('나오하'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('내 파티에 추가'));
    expect(s.adventure.party.single.captured, true);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 현황판'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('진화 완료'));
    expect(s.adventure.party.single.evolution, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('next objective advances and route checkbox can undo', (
    tester,
  ) async {
    final s = await fresh();
    await app(tester, s);
    await tapVisible(tester, find.text('목표 완료'));
    expect(s.adventure.completed, {'cortondo'});
    expect(find.text('암벽의 주인'), findsOneWidget);
    await tester.tap(find.text('진행 루트'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.bySemanticsLabel('세르클마을 체육관 완료'));
    expect(s.adventure.completed, isEmpty);
  });
  testWidgets('manual task creates and completes on small phone', (
    tester,
  ) async {
    final s = await fresh();
    await app(tester, s, size: const Size(360, 740));
    await tapVisible(tester, find.byTooltip('할 일 추가'));
    await tester.enterText(find.byType(TextFormField).first, '몬스터볼 구매');
    await tester.enterText(find.byType(TextFormField).last, '10개 준비');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(s.adventure.tasks.single.title, '몬스터볼 구매');
    await tapVisible(tester, find.text('몬스터볼 구매'));
    expect(s.adventure.tasks.single.done, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('edition toggle separates parties without deleting Scarlet', (
    tester,
  ) async {
    final s = await fresh();
    await s.addMember('pawmi');
    await app(tester, s);
    await tester.tap(find.text('바이올렛'));
    await tester.pumpAndSettle();
    expect(s.adventure.party, isEmpty);
    await tester.tap(find.text('스칼렛'));
    await tester.pumpAndSettle();
    expect(s.adventure.party.single.lineId, 'pawmi');
  });
  testWidgets('legacy archive tolerates corrupt previous data', (tester) async {
    final s = await fresh(initial: {'companion.v1': 'broken'});
    await app(tester, s);
    await tester.tap(find.byTooltip('기록·앱 안내'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('이전 앱 기록 열람'));
    expect(find.textContaining('원본은 보존되어 있습니다'), findsOneWidget);
    expect(s.legacyRaw, 'broken');
  });
  testWidgets('dashboard catalog detail and route fit enlarged phone text', (
    tester,
  ) async {
    final s = await fresh();
    await s.addMember('pawmi');
    await app(tester, s, size: const Size(360, 800), scale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('파티 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pokemon-search')), '빠모');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('pokemon-pawmi')));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('진행 루트'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('type calculator combines dual defenses', (tester) async {
    final s = await fresh();
    await tester.pumpWidget(MaterialApp(home: TypeMatchupPage(store: s)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('땅'));
    await tester.tap(find.text('드래곤'));
    await tester.pumpAndSettle();
    expect(find.text('얼음 ×4'), findsOneWidget);
  });
  test(
    'release manifest is offline and identity supports existing upgrades',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, isNot(contains('android.permission.INTERNET')));
      expect(manifest, contains('android:label="팔데아 플래너"'));
      expect(
        File('android/app/build.gradle.kts').readAsStringSync(),
        contains('applicationId = "com.choisangjin.switchcompanion"'),
      );
      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('flutter_secure_storage')),
      );
    },
  );
  test('offline data is included in the actual Flutter asset bundle', () async {
    final bundled = await PaldeaData.load();
    expect(bundled.lines.length, 24);
    expect(bundled.route.length, 18);
  });
  testWidgets(
    'populated legacy goals retain memo condition and completed steps',
    (tester) async {
      final raw = jsonEncode({
        'games': [
          {'name': '포켓몬스터 스칼렛'},
        ],
        'guides': [],
        'goals': [
          {
            'title': '기존 육성 목표',
            'memo': '이전 메모',
            'done': false,
            'completedSteps': [true],
            'guide': {
              'summary': '원래 저장한 요약',
              'items': [
                {
                  'label': '이전 캐릭터',
                  'value': '이전 목표',
                  'steps': [
                    {'label': '첫 단계', 'value': '육성', 'condition': '원래 전직 조건'},
                  ],
                },
              ],
            },
          },
        ],
      });
      final s = await fresh(initial: {'companion.v1': raw});
      await tester.pumpWidget(MaterialApp(home: LegacyRecords(raw: raw)));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('완료 · 기존 육성 목표'));
      expect(find.text('이전 메모'), findsOneWidget);
      expect(find.textContaining('원래 전직 조건'), findsOneWidget);
      expect(s.legacyRaw, raw);
    },
  );
}
