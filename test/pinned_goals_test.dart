import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_companion/main.dart';
import 'package:switch_companion/models/models.dart';
import 'package:switch_companion/models/pinned_goal.dart';
import 'package:switch_companion/services/storage.dart';
import 'package:switch_companion/widgets/goal_board.dart';
import 'package:switch_companion/widgets/guide_page.dart';
import 'package:switch_companion/data/game_catalog.dart';

const game = GameProfile(
  id: 'game',
  name: '파이어 엠블렘 인게이지',
  rules: '하드',
  progress: '5장',
);
GuideData guide({
  String gameId = 'game',
  String context = 'context',
  bool steps = true,
}) => GuideData(
  id: 'source',
  gameId: gameId,
  title: '원본 육성 공략',
  category: steps ? 'build' : 'party',
  summary: '확인한 공략',
  contextKey: context,
  topic: steps ? 'build' : 'party',
  target: '주인공',
  progress: '5장',
  contextRules: '하드',
  createdAt: '2026-10-30T00:00:00Z',
  items: [
    GuideItem(
      label: '주인공',
      value: '목표 직업',
      availability: '초반에 확보',
      deadline: '구간 종료 전',
      steps: steps
          ? const [
              GuideStep(label: '초기', value: '초기 직업', condition: '기초 조건'),
              GuideStep(label: '상위', value: '최종 직업', condition: '상위 조건'),
            ]
          : const [],
    ),
  ],
);
Future<LocalStore> storeWithGame() async {
  SharedPreferences.setMockInitialValues({});
  final store = LocalStore(await SharedPreferences.getInstance());
  store.games.add(game);
  store.selectedId = game.id;
  return store;
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
    'build card identifies the selected character when the source labels a job',
    () async {
      final store = await storeWithGame();
      final source = guide();
      source.items[0] = GuideItem(
        label: '추천 상위 직업',
        value: '최종 직업',
        steps: source.items.single.steps,
      );
      final goal = await store.pinItem(source, source.items.single);
      expect(goal.title, '주인공');
      expect(goal.item.label, '추천 상위 직업');
    },
  );

  test(
    'pin is a deep snapshot with independent progress and context',
    () async {
      final store = await storeWithGame();
      final source = guide();
      store.guides.add(source);
      final goal = await store.pinItem(source, source.items.single);
      source.items[0] = GuideItem(label: '변경된 캐릭터', value: '변경된 추천');
      await store.updateGoal(goal.setStep(0, true));
      expect(store.goals.single.item.label, '주인공');
      expect(store.goals.single.item.steps[1].condition, '상위 조건');
      expect(store.goals.single.guide.progress, '5장');
      expect(store.goals.single.guide.contextRules, '하드');
      store.guides.clear();
      await store.save();
      final restored = LocalStore(store.preferences)..load();
      expect(restored.guides, isEmpty);
      expect(restored.goals.single.completedSteps, [true, false]);
      expect(restored.goals.single.item.value, '목표 직업');
    },
  );
  test(
    'parallel duplicate pins do not reset progress or create duplicates',
    () async {
      final store = await storeWithGame();
      final source = guide();
      final results = await Future.wait(
        List.generate(3, (_) => store.pinItem(source, source.items.single)),
      );
      expect(store.goals.length, 1);
      expect(results.map((g) => g.id).toSet().length, 1);
      await store.updateGoal(store.goals.single.setStep(0, true));
      await store.pinItem(source, source.items.single);
      expect(store.goals.single.completedSteps, [true, false]);
    },
  );
  test('step completion, undo and independent tasks survive restart', () async {
    final store = await storeWithGame();
    final source = guide();
    var goal = await store.pinItem(source, source.items.single);
    goal = goal.setStep(1, true);
    expect(goal.nextStepIndex, 0);
    goal = goal.setStep(0, true);
    expect(goal.isComplete, true);
    goal = goal.setStep(0, false);
    expect(goal.nextStepIndex, 0);
    expect(goal.completedSteps[1], true);
    await store.updateGoal(goal.copyWith(memo: '내 조건'));
    final manual = await store.addManualGoal(game, '퀘스트', '마을 방문', '자기 전 확인');
    await store.updateGoal(manual.copyWith(done: true));
    final restored = LocalStore(store.preferences)..load();
    expect(restored.goals.first.completedSteps, [false, true]);
    expect(restored.goals.first.memo, '내 조건');
    expect(restored.goals.last.manual, true);
    expect(restored.goals.last.isComplete, true);
    expect(() => restored.goals.first.setStep(2, true), throwsRangeError);
  });
  test('different source contexts and games have separate goals', () async {
    final store = await storeWithGame();
    for (final source in [
      guide(),
      guide(context: 'other-progress'),
      guide(gameId: 'other'),
    ]) {
      await store.pinItem(source, source.items.single);
    }
    expect(store.goals.length, 3);
    expect(store.goals.map((g) => g.sourceKey).toSet().length, 3);
  });
  test(
    'old saves without goals remain readable and malformed goal state is preserved for recovery',
    () async {
      final store = await storeWithGame();
      await store.save();
      final raw =
          jsonDecode(store.preferences.getString('companion.v1')!)
              as Map<String, dynamic>;
      raw.remove('goals');
      await store.preferences.setString('companion.v1', jsonEncode(raw));
      final legacy = LocalStore(store.preferences)..load();
      expect(legacy.goals, isEmpty);
      expect(legacy.games.single.name, game.name);
      final source = guide();
      final goal = PinnedGoal.fromGuide(source, source.items.single).toJson();
      goal['completedSteps'] = [true];
      raw['goals'] = [goal];
      final corrupt = jsonEncode(raw);
      await store.preferences.setString('companion.v1', corrupt);
      expect(() => LocalStore(store.preferences).load(), throwsFormatException);
      expect(store.preferences.getString('companion.v1'), corrupt);
    },
  );
  test('failed goal writes roll back and do not poison later writes', () async {
    final initial = await storeWithGame();
    final store = FailingStore(initial.preferences)..games.add(game);
    final source = guide();
    final original = await store.pinItem(source, source.items.single);
    store.fail = true;
    await expectLater(
      store.updateGoal(original.setStep(0, true)),
      throwsStateError,
    );
    expect(store.goals.single.completedSteps, [false, false]);
    await expectLater(store.removeGoal(original.id), throwsStateError);
    expect(store.goals.single.id, original.id);
    store.fail = false;
    await store.updateGoal(original.setStep(0, true));
    expect(
      (LocalStore(store.preferences)..load()).goals.single.completedSteps,
      [true, false],
    );
  });
  test(
    'deleting a game removes only its goals, with failure rollback',
    () async {
      final initial = await storeWithGame();
      final store = FailingStore(initial.preferences)
        ..games.addAll([game, const GameProfile(id: 'other', name: '다른 게임')])
        ..selectedId = game.id;
      for (final source in [guide(), guide(gameId: 'other')]) {
        store.guides.add(source);
        await store.pinItem(source, source.items.single);
      }
      store.fail = true;
      await expectLater(store.deleteGame(game.id), throwsStateError);
      expect(store.games.length, 2);
      expect(store.goals.length, 2);
      expect(store.selectedId, game.id);
      store.fail = false;
      await store.deleteGame(game.id);
      final loaded = LocalStore(store.preferences)..load();
      expect(loaded.games.single.id, 'other');
      expect(loaded.goals.single.gameId, 'other');
      expect(loaded.guides.single.gameId, 'other');
    },
  );
  test(
    'manual goals require an action and do not create an AI guide',
    () async {
      final store = await storeWithGame();
      await expectLater(
        store.addManualGoal(game, '', '할 일', ''),
        throwsFormatException,
      );
      await expectLater(
        store.addManualGoal(game, '제목', ' ', ''),
        throwsFormatException,
      );
      await store.addManualGoal(game, '내 목표', '포획하기', '오프라인');
      expect(store.guides, isEmpty);
      expect(store.goals.single.item.value, '포획하기');
    },
  );
  testWidgets(
    'saved guide pin appears on the board, advances and can be undone',
    (tester) async {
      final store = await storeWithGame();
      final source = guide();
      store.guides.add(source);
      await store.save();
      await tester.pumpWidget(CompanionApp(store: store));
      await tester.tap(find.text('내 공략집'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('내 목표에 고정'));
      await tester.tap(find.byTooltip('내 목표에 고정'));
      await tester.pumpAndSettle();
      expect(store.goals.length, 1);
      await tester.tap(find.text('내 현황판'));
      await tester.pumpAndSettle();
      expect(find.text('다음: 초기 직업'), findsOneWidget);
      await tester.ensureVisible(find.text('이 단계 완료'));
      await tester.tap(find.text('이 단계 완료'));
      await tester.pumpAndSettle();
      expect(find.text('다음: 최종 직업'), findsOneWidget);
      expect(store.goals.single.completedSteps, [true, false]);
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('주인공'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('주인공'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      expect(store.goals.single.completedSteps, [false, false]);
      expect(source.items.single.isChecked, false);
    },
  );
  testWidgets('manual task completes, reopens and edits offline', (
    tester,
  ) async {
    final store = await storeWithGame();
    await tester.pumpWidget(CompanionApp(store: store));
    await tester.tap(find.text('직접 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '내 포획 목표');
    await tester.enterText(find.byType(TextField).at(1), '초반 지역 방문');
    await tester.enterText(find.byType(TextField).at(2), '통신 없이');
    await tester.tap(find.text('목표 추가'));
    await tester.pumpAndSettle();
    expect(store.goals.single.manual, true);
    expect(store.guides, isEmpty);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('완료한 목표 (1)'), findsOneWidget);
    await tester.tap(find.text('완료한 목표 (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('내 포획 목표'));
    await tester.tap(find.text('내 포획 목표'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('목표 이름·메모 편집'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '두 번째 지역 방문');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('두 번째 지역 방문'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      (LocalStore(store.preferences)..load()).goals.single.isComplete,
      false,
    );
    expect(store.goals.single.memo, '통신 없이');
  });
  testWidgets('failed progress save leaves the old step available', (
    tester,
  ) async {
    final initial = await storeWithGame();
    final store = FailingStore(initial.preferences)
      ..games.add(game)
      ..selectedId = game.id;
    final source = guide();
    await store.pinItem(source, source.items.single);
    store.fail = true;
    await tester.pumpWidget(CompanionApp(store: store));
    await tester.ensureVisible(find.text('이 단계 완료'));
    await tester.tap(find.text('이 단계 완료'));
    await tester.pumpAndSettle();
    expect(find.text('다음: 초기 직업'), findsOneWidget);
    expect(store.goals.single.completedSteps, [false, false]);
    expect(find.text('목표 진행을 저장하지 못했습니다. 다시 시도하세요.'), findsOneWidget);
  });
  testWidgets('goal detail unpin is confirmed and preserves original guide', (
    tester,
  ) async {
    final store = await storeWithGame();
    final source = guide();
    store.guides.add(source);
    final goal = await store.pinItem(source, source.items.single);
    await tester.pumpWidget(
      MaterialApp(
        home: GoalDetailPage(store: store, goalId: goal.id),
      ),
    );
    await tester.tap(find.byTooltip('목표 고정 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(store.goals.length, 1);
    await tester.tap(find.byTooltip('목표 고정 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고정 해제'));
    await tester.pumpAndSettle();
    expect(store.goals, isEmpty);
    expect(store.guides.single.id, source.id);
  });
  testWidgets(
    'guided result pins once and does not request another AI answer',
    (tester) async {
      final store = await storeWithGame();
      final source = guide();
      store.guides.add(source);
      await tester.pumpWidget(
        MaterialApp(
          home: GuidePage(
            game: game,
            topic: GuideTopic.build,
            initialGuide: source,
            store: store,
            persist: store.save,
            load: (_, _, _) async => throw StateError('must stay offline'),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('내 목표에 고정'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('내 목표에 고정'));
      await tester.pumpAndSettle();
      expect(store.goals.length, 1);
      expect(find.text('내 목표에 고정됨'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '내 목표에 고정됨'),
      );
      expect(button.onPressed, isNull);
    },
  );
  testWidgets('phone layout keeps multiple goals separate from another game', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await storeWithGame();
    for (var i = 0; i < 6; i++) {
      await store.addManualGoal(
        game,
        '목표 $i',
        '해당 구간에서 포획하고 필요한 재료와 조건을 확인하기',
        '',
      );
    }
    await store.addManualGoal(
      const GameProfile(id: 'other', name: '다른 게임'),
      '다른 게임 목표',
      '구분하기',
      '',
    );
    await tester.pumpWidget(CompanionApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('진행 중 6개 · 완료 0개'), findsOneWidget);
    expect(find.text('다른 게임 목표'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('공략 찾기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
