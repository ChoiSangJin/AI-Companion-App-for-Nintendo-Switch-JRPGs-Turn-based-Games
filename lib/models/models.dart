class GameProfile {
  const GameProfile({required this.id, required this.name, this.rules = ''});
  final String id, name, rules;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'rules': rules};
  factory GameProfile.fromJson(Map<String, dynamic> j) => GameProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    rules: j['rules'] as String? ?? '',
  );
}

class GuideItem {
  GuideItem({
    required this.label,
    required this.value,
    this.note = '',
    this.isChecked = false,
  });
  final String label, value, note;
  bool isChecked;
  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'note': note,
    'isChecked': isChecked,
  };
  factory GuideItem.fromJson(Map<String, dynamic> j) {
    if (j['label'] is! String ||
        j['value'] is! String ||
        (j['note'] != null && j['note'] is! String) ||
        (j['isChecked'] != null && j['isChecked'] is! bool)) {
      throw const FormatException('항목 형식이 올바르지 않습니다.');
    }
    return GuideItem(
      label: j['label'] as String,
      value: j['value'] as String,
      note: j['note'] as String? ?? '',
      isChecked: j['isChecked'] as bool? ?? false,
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
  });
  final String id, gameId, title, category, summary, searchEntryPoint;
  final List<GuideItem> items;
  final List<Map<String, String>> sources;
  static const categories = ['weakness', 'choice', 'synthesis', 'checklist'];
  Map<String, dynamic> toJson() => {
    'id': id,
    'gameId': gameId,
    'title': title,
    'category': category,
    'summary': summary,
    'items': items.map((i) => i.toJson()).toList(),
    'sources': sources,
    'searchEntryPoint': searchEntryPoint,
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
    );
  }
}
