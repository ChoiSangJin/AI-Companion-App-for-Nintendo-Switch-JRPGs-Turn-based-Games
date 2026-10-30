import 'dart:convert';
import 'models.dart';

/// User-owned progress is independent from mutable AI guide results.
class PinnedGoal {
  PinnedGoal({
    required this.id,
    required this.sourceKey,
    required this.guide,
    required this.title,
    this.memo = '',
    this.done = false,
    List<bool>? completedSteps,
    this.manual = false,
  }) : completedSteps = List.unmodifiable(
         completedSteps ?? List.filled(guide.items.single.steps.length, false),
       );
  final String id, sourceKey, title, memo;
  final GuideData guide;
  final bool done, manual;
  final List<bool> completedSteps;
  GuideItem get item => guide.items.single;
  String get gameId => guide.gameId;
  bool get hasSteps => item.steps.isNotEmpty;
  bool get isComplete => hasSteps ? completedSteps.every((v) => v) : done;
  int get nextStepIndex => completedSteps.indexWhere((v) => !v);
  int get completedCount => completedSteps.where((v) => v).length;
  static String keyFor(GuideData guide, GuideItem item) => jsonEncode([
    guide.gameId,
    guide.contextKey.isEmpty ? guide.id : guide.contextKey,
    item.label.trim(),
    item.value.trim(),
  ]);
  factory PinnedGoal.fromGuide(GuideData guide, GuideItem item) => PinnedGoal(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sourceKey: keyFor(guide, item),
    title: item.label,
    done: item.isChecked,
    guide: GuideData.fromJson({
      ...guide.toJson(),
      'items': [item.toJson()],
    }),
    completedSteps: List.filled(item.steps.length, item.isChecked),
  );
  PinnedGoal copyWith({
    String? title,
    String? memo,
    bool? done,
    List<bool>? completedSteps,
    GuideData? guide,
  }) => PinnedGoal(
    id: id,
    sourceKey: sourceKey,
    guide: guide ?? this.guide,
    title: title ?? this.title,
    memo: memo ?? this.memo,
    done: done ?? this.done,
    completedSteps: completedSteps ?? this.completedSteps,
    manual: manual,
  );
  PinnedGoal setStep(int index, bool value) {
    if (index < 0 || index >= completedSteps.length) {
      throw RangeError.index(index, completedSteps);
    }
    final next = List<bool>.of(completedSteps);
    next[index] = value;
    return copyWith(completedSteps: next);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceKey': sourceKey,
    'title': title,
    'memo': memo,
    'done': done,
    'manual': manual,
    'completedSteps': completedSteps,
    'guide': guide.toJson(),
  };
  factory PinnedGoal.fromJson(Map<String, dynamic> j) {
    final guide = GuideData.fromJson(
      Map<String, dynamic>.from(j['guide'] as Map),
    );
    final steps = j['completedSteps'];
    if (guide.items.length != 1 ||
        j['id'] is! String ||
        j['sourceKey'] is! String ||
        j['title'] is! String ||
        (j['memo'] != null && j['memo'] is! String) ||
        (j['done'] != null && j['done'] is! bool) ||
        (j['manual'] != null && j['manual'] is! bool) ||
        steps is! List ||
        steps.length != guide.items.single.steps.length ||
        steps.any((s) => s is! bool)) {
      throw const FormatException('고정한 목표의 진행 기록을 읽을 수 없습니다.');
    }
    return PinnedGoal(
      id: j['id'] as String,
      sourceKey: j['sourceKey'] as String,
      guide: guide,
      title: j['title'] as String,
      memo: j['memo'] as String? ?? '',
      done: j['done'] as bool? ?? false,
      manual: j['manual'] as bool? ?? false,
      completedSteps: List<bool>.from(steps),
    );
  }
}
