import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/planner.dart';

class PaldeaData {
  PaldeaData.fromJson(Map<String, dynamic> j)
    : typeChart = (j['typeChart'] as Map).map(
        (k, v) => MapEntry(k as String, Map<String, num>.from(v as Map)),
      ),
      revision = j['revision'] as String,
      scope = j['scope'] as String,
      lines = (j['lines'] as List)
          .map((p) => PokemonLine.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      route = (j['route'] as List)
          .map((p) => RouteStop.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList() {
    if (lines.map((l) => l.id).toSet().length != lines.length ||
        route.map((r) => r.id).toSet().length != route.length ||
        lines.any((l) => l.conditions.length != l.forms.length - 1)) {
      throw const FormatException('공략 데이터가 올바르지 않습니다.');
    }
  }
  final Map<String, Map<String, num>> typeChart;
  double effectiveness(String attack, List<String> defense) => defense
      .toSet()
      .fold(1.0, (value, type) => value * typeChart[attack]![type]!);
  final String revision, scope;
  final List<PokemonLine> lines;
  final List<RouteStop> route;
  static Future<PaldeaData> load() async => PaldeaData.fromJson(
    jsonDecode(await rootBundle.loadString('assets/data/paldea.json'))
        as Map<String, dynamic>,
  );
  PokemonLine line(String id) => lines.firstWhere((p) => p.id == id);
  List<PokemonLine> available(String edition, String? starter) => lines
      .where(
        (l) =>
            l.versions.contains(edition) &&
            (!l.starter || starter == null || starter == l.id),
      )
      .toList();
  List<PokemonLine> recommended(String edition, String? starter) {
    final ids = switch (starter) {
      'sprigatito' => [
        'sprigatito',
        'fletchling',
        'pawmi',
        'azurill',
        'tinkatink',
        'nacli',
      ],
      'fuecoco' => [
        'fuecoco',
        'magikarp',
        'smoliv',
        'pawmi',
        'tinkatink',
        'gible',
      ],
      'quaxly' => [
        'quaxly',
        'fletchling',
        'smoliv',
        'pawmi',
        'tinkatink',
        'nacli',
      ],
      _ => <String>[],
    };
    return available(edition, starter).where((l) => ids.contains(l.id)).toList()
      ..sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
  }
}
