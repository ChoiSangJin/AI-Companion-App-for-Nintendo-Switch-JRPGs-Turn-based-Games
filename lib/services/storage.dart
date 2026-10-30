import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/pinned_goal.dart';

class LocalStore {
  LocalStore(this.preferences);
  final SharedPreferences preferences;
  List<GameProfile> games = [];
  List<GuideData> guides = [];
  List<PinnedGoal> goals = [];
  Future<void> _goalWrites = Future.value();
  Future<T> _serializeGoalWrite<T>(Future<T> Function() operation) {
    final next = _goalWrites.then((_) => operation());
    _goalWrites = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  PinnedGoal? pinnedItem(GuideData guide, GuideItem item) => goals
      .where((g) => g.sourceKey == PinnedGoal.keyFor(guide, item))
      .firstOrNull;
  Future<void> _commitGoals(List<PinnedGoal> next) async {
    final previous = goals;
    goals = next;
    try {
      await save();
    } catch (_) {
      goals = previous;
      rethrow;
    }
  }

  Future<PinnedGoal> pinItem(GuideData guide, GuideItem item) =>
      _serializeGoalWrite(() async {
        final existing = pinnedItem(guide, item);
        if (existing != null) return existing;
        final goal = PinnedGoal.fromGuide(guide, item);
        await _commitGoals([...goals, goal]);
        return goal;
      });
  Future<void> updateGoal(PinnedGoal next) => _serializeGoalWrite(() async {
    final index = goals.indexWhere((g) => g.id == next.id);
    if (index < 0) throw StateError('고정이 해제된 목표입니다.');
    final updated = List<PinnedGoal>.of(goals);
    updated[index] = next;
    await _commitGoals(updated);
  });
  Future<void> removeGoal(String id) => _serializeGoalWrite(
    () => _commitGoals(goals.where((g) => g.id != id).toList()),
  );
  Future<PinnedGoal> addManualGoal(
    GameProfile game,
    String title,
    String action,
    String memo,
  ) => _serializeGoalWrite(() async {
    if (title.trim().isEmpty || action.trim().isEmpty) {
      throw const FormatException('목표 이름과 할 일을 입력하세요.');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final guide = GuideData(
      id: 'manual-$id',
      gameId: game.id,
      title: title.trim(),
      category: 'checklist',
      summary: '직접 작성한 목표',
      items: [GuideItem(label: title.trim(), value: action.trim())],
      progress: game.progress,
      contextRules: game.rules,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    final goal = PinnedGoal(
      id: id,
      sourceKey: 'manual-$id',
      guide: guide,
      title: title.trim(),
      memo: memo.trim(),
      manual: true,
    );
    await _commitGoals([...goals, goal]);
    return goal;
  });
  Future<void> deleteGame(String id) => _serializeGoalWrite(() async {
    final oldGames = games, oldGuides = guides, oldGoals = goals;
    final oldSelected = selectedId;
    games = games.where((g) => g.id != id).toList();
    guides = guides.where((g) => g.gameId != id).toList();
    goals = goals.where((g) => g.gameId != id).toList();
    if (selectedId == id) selectedId = games.firstOrNull?.id;
    try {
      await save();
    } catch (_) {
      games = oldGames;
      guides = oldGuides;
      goals = oldGoals;
      selectedId = oldSelected;
      rethrow;
    }
  });
  String? selectedId;
  String model = 'gemini-2.5-flash';
  GuideData? cachedGuide(String contextKey) =>
      guides.where((g) => g.contextKey == contextKey).firstOrNull;
  void putGuide(GuideData guide) {
    if (guide.contextKey.isNotEmpty) {
      guides.removeWhere((g) => g.contextKey == guide.contextKey);
    }
    guides.insert(0, guide);
  }

  void load() {
    final raw = preferences.getString('companion.v1');
    if (raw == null) return;
    // Do not silently overwrite corrupt data. The startup screen reports it.
    final j = jsonDecode(raw) as Map<String, dynamic>;
    games = (j['games'] as List)
        .map((g) => GameProfile.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList();
    guides = (j['guides'] as List)
        .map((g) => GuideData.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList();
    goals = (j['goals'] as List? ?? [])
        .map((g) => PinnedGoal.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList();
    selectedId = j['selectedId'] as String?;
    model = j['model'] as String? ?? model;
    if (!games.any((g) => g.id == selectedId)) {
      selectedId = games.firstOrNull?.id;
    }
  }

  Future<void> save() async {
    final ok = await preferences.setString(
      'companion.v1',
      jsonEncode({
        'games': games.map((g) => g.toJson()).toList(),
        'guides': guides.map((g) => g.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'selectedId': selectedId,
        'model': model,
      }),
    );
    if (!ok) throw StateError('로컬 저장 실패. 저장 공간을 확인하세요.');
  }
}
