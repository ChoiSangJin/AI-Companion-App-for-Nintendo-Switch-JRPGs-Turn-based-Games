import 'dart:convert';
import 'package:flutter/services.dart';

class DemonSkill {
  DemonSkill.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      level = j['level'] as num;
  final String id, name;
  final num level;
}

class Demon {
  Demon.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String,
      aliases = List<String>.from(j['aliases'] as List? ?? const []),
      race = j['race'] as String,
      raceName = j['raceName'] as String,
      level = j['level'] as int,
      dlc = j['dlc'] as String?,
      acquisition = j['acquisition'] as String,
      stats = Map<String, num>.from(j['stats'] as Map),
      resists = Map<String, String>.from(j['resists'] as Map),
      skills = (j['skills'] as List)
          .map((v) => DemonSkill.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(),
      requirements = (j['requirements'] as List)
          .map((v) => Map<String, String>.from(v as Map))
          .toList();
  final String id, name, race, raceName, acquisition;
  final List<String> aliases;
  final String? dlc;
  final int level;
  final Map<String, num> stats;
  final Map<String, String> resists;
  final List<DemonSkill> skills;
  final List<Map<String, String>> requirements;
  bool matches(String query) {
    final q = query.toLowerCase().replaceAll(' ', '');
    return '$name$id$race$raceName${aliases.join(' ')}'
        .toLowerCase()
        .replaceAll(' ', '')
        .contains(q);
  }
}

class DlcGroup {
  DlcGroup.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      label = j['label'] as String,
      members = List<String>.from(j['members'] as List),
      enabledByDefault = j['default'] as bool;
  final String id, label;
  final List<String> members;
  final bool enabledByDefault;
}

class GameData {
  GameData.fromJson(this.raw)
    : id = raw['id'] as String,
      name = raw['name'] as String,
      title = raw['title'] as String,
      sourceCommit = raw['sourceCommit'] as String,
      demons = (raw['demons'] as List)
          .map((d) => Demon.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      dlc = (raw['dlc'] as List)
          .map((d) => DlcGroup.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      races = List<String>.from(raw['races'] as List),
      elements = List<String>.from(raw['elements'] as List),
      normalChart = _chart(raw['normalChart']),
      tripleChart = _chart(raw['tripleChart']),
      elementChart = (raw['elementChart'] as Map).map(
        (k, v) => MapEntry(k as String, Map<String, int>.from(v as Map)),
      ),
      special = (raw['special'] as Map).map(
        (k, v) => MapEntry(k as String, List<String>.from(v as List)),
      ) {
    byId = {for (final d in demons) d.id: d};
    if (byId.length != demons.length ||
        special.entries.any(
          (e) =>
              !byId.containsKey(e.key) ||
              e.value.any((id) => !byId.containsKey(id)),
        )) {
      throw const FormatException('전서 데이터 참조가 올바르지 않습니다.');
    }
  }
  final Map<String, dynamic> raw;
  final String id, name, title, sourceCommit;
  final List<Demon> demons;
  late final Map<String, Demon> byId;
  final List<DlcGroup> dlc;
  final List<String> races, elements;
  final Map<String, Map<String, String>> normalChart, tripleChart;
  final Map<String, Map<String, int>> elementChart;
  final Map<String, List<String>> special;
  static Map<String, Map<String, String>> _chart(dynamic j) => (j as Map).map(
    (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
  );
  Set<String> get defaultDlc =>
      dlc.where((g) => g.enabledByDefault).map((g) => g.id).toSet();
  List<Demon> available(Set<String> enabled) =>
      demons.where((d) => d.dlc == null || enabled.contains(d.dlc)).toList()
        ..sort(
          (a, b) => a.level.compareTo(b.level) != 0
              ? a.level.compareTo(b.level)
              : a.name.compareTo(b.name),
        );
  String get noun => id == 'smt5v' ? '악마' : '페르소나';
  String get shortTitle => switch (id) {
    'p3r' => 'P3 Reload',
    'p4g' => 'P4 Golden',
    'p5r' => 'P5 Royal',
    _ => 'SMT V Vengeance',
  };
  Uri sourceUrl(String demonId) => Uri.https(
    'aqiu384.github.io',
    '/megaten-fusion-tool/$id/${id == 'smt5v' ? 'demons' : 'personas'}/$demonId',
  );
  static const supported = ['p3r', 'p4g', 'p5r', 'smt5v'];
  static Future<Map<String, GameData>> loadAll() async {
    final entries = await Future.wait(
      supported.map(
        (id) async => GameData.fromJson(
          jsonDecode(await rootBundle.loadString('assets/megaten/$id.json'))
              as Map<String, dynamic>,
        ),
      ),
    );
    return {for (final g in entries) g.id: g};
  }
}

class FusionRecipe {
  const FusionRecipe({
    required this.inputs,
    required this.result,
    required this.kind,
  });
  final List<String> inputs;
  final String result, kind;
  Map<String, dynamic> toJson() => {
    'inputs': inputs,
    'result': result,
    'kind': kind,
  };
  factory FusionRecipe.fromJson(Map<String, dynamic> j) => FusionRecipe(
    inputs: List<String>.from(j['inputs'] as List),
    result: j['result'] as String,
    kind: j['kind'] as String,
  );
  String get key => '${([...inputs]..sort()).join('|')}=>$result';
}
