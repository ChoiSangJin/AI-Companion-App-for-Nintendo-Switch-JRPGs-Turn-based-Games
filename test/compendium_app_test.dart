import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_companion/main.dart';
import 'package:switch_companion/models/compendium.dart';
import 'package:switch_companion/services/compendium_store.dart';
import 'package:switch_companion/services/fusion_engine.dart';
import 'package:switch_companion/widgets/fusion_pages.dart';

late Map<String, GameData> games;
Future<CompendiumStore> fresh({
  Map<String, Object> initial = const {},
  Future<bool> Function(String, String)? write,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  return CompendiumStore(
    await SharedPreferences.getInstance(),
    games,
    write: write,
  )..load();
}

Future<void> openApp(
  WidgetTester tester,
  CompendiumStore s, {
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
    tester.view.resetViewInsets();
  });
  await tester.pumpWidget(AtlusApp(store: s));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (!tester.binding.hasScheduledFrame) break;
  }
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .35);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await settle(tester);
}

Future<void> noOp(Future<void> Function() action) async {
  await action();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    games = {
      for (final id in GameData.supported)
        id: GameData.fromJson(
          jsonDecode(File('assets/megaten/$id.json').readAsStringSync())
              as Map<String, dynamic>,
        ),
    };
  });
  test(
    'all four offline asset bundles and Korean/English aliases work',
    () async {
      final bundled = await GameData.loadAll();
      expect(bundled.length, 4);
      expect(bundled.values.fold<int>(0, (n, g) => n + g.demons.length), 906);
      expect(bundled['p3r']!.byId['Jack Frost']!.matches('잭프로스트'), true);
      expect(bundled['p3r']!.byId['Jack Frost']!.matches('jack frost'), true);
      expect(
        bundled['p3r']!.sourceUrl('Jack Frost').path,
        contains('/personas/'),
      );
      expect(
        bundled['smt5v']!.sourceUrl('Jack Frost').path,
        contains('/demons/'),
      );
    },
  );
  test(
    'DLC defaults are edition specific and grouped into installation packs',
    () async {
      final s = await fresh();
      expect(s.profile('p3r').dlc, isEmpty);
      expect(s.profile('smt5v').dlc, isEmpty);
      expect(s.profile('p5r').dlc.length, 13);
      expect(games['p3r']!.dlc.first.members.length, greaterThan(1));
      expect(games['smt5v']!.dlc.length, 2);
    },
  );
  test(
    'registration targets DLC and selected game persist separately',
    () async {
      final s = await fresh();
      await s.register('p3r', 'Pixie', true);
      await s.favorite('p3r', 'Alice', true);
      await s.allDlc('p3r', true);
      await s.selectGame('p5r');
      await s.favorite('p5r', 'Satanael', true);
      final loaded = CompendiumStore(s.preferences, games)..load();
      expect(loaded.selected, 'p5r');
      expect(loaded.profile('p3r').registered, {'Pixie'});
      expect(loaded.profile('p3r').favorites, {'Alice'});
      expect(loaded.profile('p5r').favorites, {'Satanael'});
      expect(loaded.profile('p5r').registered, isEmpty);
    },
  );
  test(
    'disabling DLC keeps saved targets but excludes disabled ingredients and results',
    () async {
      final s = await fresh();
      await s.allDlc('p3r', true);
      await s.favorite('p3r', 'Arsene', true);
      await s.register('p3r', 'Arsene', true);
      await s.allDlc('p3r', false);
      expect(s.profile('p3r').favorites, contains('Arsene'));
      final engine = FusionEngine(games['p3r']!, s.profile('p3r').dlc);
      expect(engine.ids.contains('Arsene'), false);
      expect(engine.reverse('Arsene'), isEmpty);
      expect(engine.forward('Arsene', 'Pixie'), isNull);
    },
  );
  test('failed disk writes rollback and allow later retries', () async {
    var fail = false;
    final s = await fresh(write: (_, value) async => !fail);
    await s.register('p3r', 'Pixie', true);
    final before = s.backup();
    fail = true;
    await expectLater(s.favorite('p3r', 'Alice', true), throwsStateError);
    expect(s.backup(), before);
    fail = false;
    await s.favorite('p3r', 'Alice', true);
    expect(s.profile('p3r').favorites, {'Alice'});
  });
  test('queued writes keep explicit game IDs across a game switch', () async {
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
    final switching = s.selectGame('p5r');
    final register = s.register('p3r', 'Pixie', true);
    gate.complete(true);
    await Future.wait([switching, register]);
    expect(s.selected, 'p5r');
    expect(s.profile('p3r').registered, {'Pixie'});
    expect(s.profile('p5r').registered, isEmpty);
  });
  test(
    'backup round trip rejects unknown demons without destroying records',
    () async {
      final s = await fresh();
      await s.favorite('p3r', 'Alice', true);
      final before = s.backup();
      await s.favorite('p3r', 'Alice', false);
      await s.restore(before);
      expect(s.profile('p3r').favorites, {'Alice'});
      for (final raw in ['broken', before.replaceAll('Alice', 'Not-a-Demon')]) {
        await expectLater(s.restore(raw), throwsFormatException);
        expect(s.backup(), before);
      }
    },
  );
  test(
    'old Paldea and companion storage remains byte-for-byte untouched',
    () async {
      final s = await fresh(
        initial: {
          'paldea.planner.v1': 'broken old paldea',
          'companion.v1': 'old guides',
        },
      );
      await s.favorite('p3r', 'Alice', true);
      expect(s.preferences.getString('paldea.planner.v1'), 'broken old paldea');
      expect(s.preferences.getString('companion.v1'), 'old guides');
      expect(s.archives.length, 2);
    },
  );
  test('older registry snapshots fill newly supported game defaults', () async {
    final s = await fresh();
    await s.favorite('p3r', 'Alice', true);
    final j = jsonDecode(s.backup()) as Map<String, dynamic>;
    (j['profiles'] as Map).remove('p4g');
    await s.restore(jsonEncode(j));
    expect(s.profile('p4g').favorites, isEmpty);
    expect(s.profile('p3r').favorites, {'Alice'});
  });
  test('corrupt current save is reported and not overwritten', () async {
    SharedPreferences.setMockInitialValues({CompendiumStore.key: 'broken'});
    final prefs = await SharedPreferences.getInstance();
    expect(
      () => (CompendiumStore(prefs, games)..load()),
      throwsFormatException,
    );
    expect(prefs.getString(CompendiumStore.key), 'broken');
  });
  test(
    'reverse filters registered ingredients and never invents accident-only outputs',
    () {
      final g = games['p3r']!, e = FusionEngine(g, {});
      final recipe = e.reverse('Jack Frost').first;
      expect(
        e
            .reverse('Jack Frost', owned: recipe.inputs.toSet())
            .any((r) => r.key == recipe.key),
        true,
      );
      expect(e.reverse('Jack Frost', owned: {recipe.inputs.first}), isEmpty);
      expect(e.reverse('Jack Frost', maxLevel: 1), isEmpty);
      final smt = FusionEngine(games['smt5v']!, {});
      for (final id in ['Amabie', 'Hare of Inaba', 'Kinmamon']) {
        expect(smt.reverse(id), isEmpty);
        expect(games['smt5v']!.byId[id]!.acquisition, 'accident');
      }
    },
  );
  test(
    'fixed large recipes and treasure current-level boundaries are handled',
    () {
      final p4 = FusionEngine(games['p4g']!, {});
      expect(p4.reverse('Izanagi-no-Okami').single.inputs.length, 12);
      final p5 = FusionEngine(games['p5r']!, {});
      expect(p5.forward('Regent', 'Pixie'), isNull);
      expect(
        p5.forward('Regent', 'Pixie', currentLevel: 10)?.result,
        'Saki Mitama',
      );
      expect(p5.forward('Regent', 'Pixie', currentLevel: 1), isNull);
      expect(p5.forward('Pixie', 'Pixie'), isNull);
    },
  );
  test(
    'reverse triples run under bounded search and reproduce valid results',
    () {
      final e = FusionEngine(games['p4g']!, {});
      expect(e.reverseTriple('Pixie'), isEmpty);
      final samples =
          jsonDecode(
                File('test/fixtures/upstream_triples.json').readAsStringSync(),
              )
              as List;
      final target = (samples.first as Map)['result'] as String;
      final results = e.reverseTriple(target, limit: 5);
      expect(results, isNotEmpty);
      for (final recipe in results) {
        expect(e.triple(recipe.inputs)?.result, target);
      }
      expect(e.reverseTriple('Izanagi-no-Okami'), isEmpty);
    },
  );
  testWidgets('Korean search opens real reverse recipes and saves a target', (
    tester,
  ) async {
    final s = await fresh();
    await openApp(tester, s);
    await tester.enterText(
      find.byKey(const ValueKey('demon-search')),
      '잭 프로스트',
    );
    await settle(tester);
    await tapVisible(tester, find.byKey(const ValueKey('demon-Jack Frost')));
    await settle(tester);
    expect(find.byType(RecipeCard), findsWidgets);
    await tester.tap(find.byTooltip('합체 목표 저장'));
    await settle(tester);
    expect(s.profile('p3r').favorites, {'Jack Frost'});
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('내 전서'));
    await settle(tester);
    expect(find.byKey(const ValueKey('demon-Jack Frost')), findsOneWidget);
  });
  testWidgets('switching game exposes only the requested four editions', (
    tester,
  ) async {
    final s = await fresh();
    await openApp(tester, s);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    for (final g in games.values) {
      expect(find.text(g.name), findsWidgets);
    }
    expect(find.textContaining('Persona 6'), findsNothing);
    await tester.tap(find.text(games['smt5v']!.name).last);
    await settle(tester);
    expect(s.selected, 'smt5v');
    expect(find.text('악마 전서'), findsOneWidget);
  });
  testWidgets('registration and DLC disabled saved entries remain usable', (
    tester,
  ) async {
    final s = await fresh();
    await s.allDlc('p3r', true);
    await s.favorite('p3r', 'Arsene', true);
    await s.allDlc('p3r', false);
    await openApp(tester, s);
    await tester.tap(find.text('내 전서'));
    await settle(tester);
    expect(find.textContaining('DLC 설정에서 제외됨'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('demon-Arsene')));
    expect(find.textContaining('현재 DLC 설정에서 제외된 항목'), findsOneWidget);
    expect(find.byType(RecipeCard), findsNothing);
  });
  testWidgets('forward picker calculates a real fixed pair', (tester) async {
    final s = await fresh();
    await openApp(tester, s);
    await tester.tap(find.text('합체 계산'));
    await settle(tester);
    for (final id in ['Rangda', 'Barong']) {
      await tapVisible(tester, find.text('페르소나 선택').first);
      await tester.enterText(
        find.byKey(const ValueKey('ingredient-search')),
        id,
      );
      await settle(tester);
      await tapVisible(tester, find.byKey(ValueKey('demon-$id')));
    }
    await tapVisible(tester, find.text('계산 결과'));
    expect(
      find.text('시바 · Lv.${games['p3r']!.byId['Shiva']!.level}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'SMT ordinary and special recipe cards support large phone text',
    (tester) async {
      final s = await fresh();
      await s.selectGame('smt5v');
      await openApp(tester, s, size: const Size(360, 800), scale: 1.5);
      await tester.enterText(
        find.byKey(const ValueKey('demon-search')),
        'Alice',
      );
      await settle(tester);
      await tapVisible(tester, find.byKey(const ValueKey('demon-Alice')));
      await tester.scrollUntilVisible(
        find.byType(RecipeCard),
        220,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await settle(tester);
      expect(find.byType(RecipeCard), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('능력·스킬'),
        -220,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('능력·스킬')),
        alignment: .3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('능력·스킬'));
      await settle(tester);
      expect(find.text('기본 능력치'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search remains scrollable with keyboard and enlarged fonts', (
    tester,
  ) async {
    final s = await fresh();
    await openApp(tester, s, size: const Size(360, 740), scale: 1.5);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('demon-search')), '픽시');
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('DLC settings persist per pack and large special recipe fits', (
    tester,
  ) async {
    final s = await fresh();
    await openApp(tester, s);
    await tester.tap(find.byTooltip('이 작품 DLC 설정'));
    await settle(tester);
    await tapVisible(tester, find.text('전체 포함'));
    expect(s.profile('p3r').dlc.length, games['p3r']!.dlc.length);
    await tester.pageBack();
    await settle(tester);
    await s.selectGame('p4g');
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('demon-search')),
      'Izanagi-no-Okami',
    );
    await settle(tester);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('demon-Izanagi-no-Okami')),
    );
    expect(find.byType(RecipeCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('release stays offline with update-compatible application ID', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:label="합체전서"'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(
      File('android/app/build.gradle.kts').readAsStringSync(),
      contains('applicationId = "com.choisangjin.switchcompanion"'),
    );
  });
  testWidgets(
    'P4G triple reverse uses registered materials in a background search',
    (tester) async {
      final samples =
          jsonDecode(
                File('test/fixtures/upstream_triples.json').readAsStringSync(),
              )
              as List;
      final sample = samples.cast<Map>().firstWhere(
        (j) => !games['p4g']!.special.containsKey(j['result']),
      );
      final s = await fresh();
      await s.selectGame('p4g');
      for (final id in List<String>.from(sample['inputs'] as List)) {
        await s.register('p4g', id, true);
      }
      await openApp(tester, s);
      await tester.enterText(
        find.byKey(const ValueKey('demon-search')),
        sample['result'] as String,
      );
      await settle(tester);
      await tapVisible(
        tester,
        find.byKey(ValueKey('demon-${sample['result']}')),
      );
      await tapVisible(tester, find.text('등록한 재료로만 찾기'));
      await tapVisible(tester, find.text('일반 3신 조합'));
      expect(find.byType(RecipeCard), findsWidgets);
      final cards = tester.widgetList<RecipeCard>(find.byType(RecipeCard));
      expect(
        cards.every(
          (c) =>
              c.recipe.inputs.length == 3 &&
              c.recipe.inputs.every(s.profile('p4g').registered.contains),
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
