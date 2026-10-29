class GameProfile {
  const GameProfile({
    required this.id,
    required this.name,
    this.rules = '',
    this.catalogId = '',
    this.progress = '',
  });
  final String id, name, rules, catalogId, progress;
  GameProfile copyWith({String? rules, String? progress}) => GameProfile(
    id: id,
    name: name,
    rules: rules ?? this.rules,
    catalogId: catalogId,
    progress: progress ?? this.progress,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rules': rules,
    'catalogId': catalogId,
    'progress': progress,
  };
  factory GameProfile.fromJson(Map<String, dynamic> j) => GameProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    rules: j['rules'] as String? ?? '',
    catalogId: j['catalogId'] as String? ?? '',
    progress: j['progress'] as String? ?? '',
  );
}

class GuideStep {
  const GuideStep({
    required this.label,
    required this.value,
    this.condition = '',
  });
  final String label, value, condition;
  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'condition': condition,
  };
  factory GuideStep.fromJson(Map<String, dynamic> j) {
    if (j['label'] is! String ||
        j['value'] is! String ||
        (j['condition'] != null && j['condition'] is! String)) {
      throw const FormatException('육성 경로 형식이 올바르지 않습니다.');
    }
    return GuideStep(
      label: j['label'] as String,
      value: j['value'] as String,
      condition: j['condition'] as String? ?? '',
    );
  }
}

class GuideItem {
  GuideItem({
    required this.label,
    required this.value,
    this.note = '',
    this.isChecked = false,
    this.reason = '',
    this.availability = '',
    this.deadline = '',
    this.alternatives = const [],
    this.steps = const [],
  });
  final String label, value, note, reason, availability, deadline;
  final List<String> alternatives;
  final List<GuideStep> steps;
  bool isChecked;
  String get searchText => [
    label,
    value,
    note,
    reason,
    availability,
    deadline,
    ...alternatives,
    ...steps.map((s) => '${s.label} ${s.value} ${s.condition}'),
  ].join(' ');
  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'note': note,
    'isChecked': isChecked,
    'reason': reason,
    'availability': availability,
    'deadline': deadline,
    'alternatives': alternatives,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
  factory GuideItem.fromJson(Map<String, dynamic> j) {
    if (j['label'] is! String ||
        j['value'] is! String ||
        (j['note'] != null && j['note'] is! String) ||
        (j['isChecked'] != null && j['isChecked'] is! bool)) {
      throw const FormatException('항목 형식이 올바르지 않습니다.');
    }
    for (final field in ['reason', 'availability', 'deadline']) {
      if (j[field] != null && j[field] is! String) {
        throw const FormatException('공략 조건 형식이 올바르지 않습니다.');
      }
    }
    if (j['steps'] != null &&
        (j['steps'] is! List || (j['steps'] as List).length > 20)) {
      throw const FormatException('육성 단계가 올바르지 않습니다.');
    }
    if (j['alternatives'] != null &&
        (j['alternatives'] is! List ||
            (j['alternatives'] as List).any((e) => e is! String))) {
      throw const FormatException('대체 추천 형식이 올바르지 않습니다.');
    }
    return GuideItem(
      label: j['label'] as String,
      value: j['value'] as String,
      note: j['note'] as String? ?? '',
      isChecked: j['isChecked'] as bool? ?? false,
      reason: j['reason'] as String? ?? '',
      availability: j['availability'] as String? ?? '',
      deadline: j['deadline'] as String? ?? '',
      alternatives: List<String>.from(j['alternatives'] as List? ?? []),
      steps: (j['steps'] as List? ?? [])
          .map((s) => GuideStep.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
  }
}

class GuideData {
  GuideData({
    required this.id,
    required this.gameId,
    required this.title,
    required this.category,
    required this.summary,
    required this.items,
    this.sources = const [],
    this.searchEntryPoint = '',
    this.contextKey = '',
    this.topic = '',
    this.target = '',
    this.progress = '',
    this.createdAt = '',
    this.contextRules = '',
  });
  final String id, gameId, title, category, summary, searchEntryPoint;
  final String contextKey, topic, target, progress, createdAt, contextRules;
  bool get isChecklist => category == 'checklist' || category == 'missables';
  final List<GuideItem> items;
  final List<Map<String, String>> sources;
  static const categories = [
    'weakness',
    'choice',
    'synthesis',
    'checklist',
    'roster',
    'build',
    'party',
    'route',
    'missables',
  ];
  Map<String, dynamic> toJson() => {
    'id': id,
    'gameId': gameId,
    'title': title,
    'category': category,
    'summary': summary,
    'items': items.map((i) => i.toJson()).toList(),
    'sources': sources,
    'searchEntryPoint': searchEntryPoint,
    'contextKey': contextKey,
    'topic': topic,
    'target': target,
    'progress': progress,
    'createdAt': createdAt,
    'contextRules': contextRules,
  };
  factory GuideData.fromJson(Map<String, dynamic> j) {
    if (j['title'] is! String ||
        j['summary'] is! String ||
        !categories.contains(j['category']) ||
        j['items'] is! List ||
        (j['items'] as List).isEmpty ||
        (j['items'] as List).length > 200) {
      throw const FormatException('공략 응답 형식이 올바르지 않습니다.');
    }
    return GuideData(
      id: j['id'] as String,
      gameId: j['gameId'] as String,
      title: j['title'] as String,
      category: j['category'] as String,
      summary: j['summary'] as String,
      items: (j['items'] as List)
          .map((i) => GuideItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList(),
      sources: (j['sources'] as List? ?? [])
          .map((s) => Map<String, String>.from(s as Map))
          .toList(),
      searchEntryPoint: j['searchEntryPoint'] as String? ?? '',
      contextKey: j['contextKey'] as String? ?? '',
      topic: j['topic'] as String? ?? '',
      target: j['target'] as String? ?? '',
      progress: j['progress'] as String? ?? '',
      createdAt: j['createdAt'] as String? ?? '',
      contextRules: j['contextRules'] as String? ?? '',
    );
  }
}
