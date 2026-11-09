import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:switch_companion/models/compendium.dart';
import 'package:switch_companion/services/fusion_engine.dart';

void main() {
  final games = {
    for (final id in GameData.supported)
      id: GameData.fromJson(
        jsonDecode(File('assets/megaten/$id.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
  };
  test(
    'all recipes reference existing demons and target only four requested editions',
    () {
      expect(games.keys.toList(), ['p3r', 'p4g', 'p5r', 'smt5v']);
      for (final g in games.values) {
        expect(g.demons.length, greaterThan(190));
        expect(g.byId.containsKey('Tao Isonokami A'), false);
        for (final e in g.special.entries) {
          expect(g.byId.containsKey(e.key), true);
          expect(e.value.every(g.byId.containsKey), true);
        }
      }
      expect(games['p4g']!.byId.containsKey('Izanagi-no-Okami'), true);
    },
  );
  final fixtures =
      jsonDecode(File('test/fixtures/upstream_pairs.json').readAsStringSync())
          as List;
  for (final raw in fixtures) {
    final j = raw as Map;
    final game = j['game'] as String;
    final enabled = Set<String>.from(j['enabled'] as List);
    test('upstream normal fusion parity $game DLC ${enabled.length}', () {
      final engine = FusionEngine(games[game]!, enabled);
      final names = List<String>.from(j['names'] as List);
      var count = 0;
      final errors = <String>[];
      for (final tuple in j['pairs'] as List) {
        final a = names[tuple[0] as int],
            b = names[tuple[1] as int],
            expected = names[tuple[2] as int];
        final override =
            engine.pairSpecials[a.compareTo(b) < 0 ? '$a|$b' : '$b|$a'];
        if (override != null && override != expected) continue;
        final result = engine.forward(a, b)?.result;
        if (result != expected && errors.length < 12) {
          errors.add('$a + $b: $result != $expected');
        }
        count++;
      }
      final allowed = (j['pairs'] as List)
          .map(
            (t) =>
                '${names[t[0] as int]}|${names[t[1] as int]}=>${names[t[2] as int]}',
          )
          .toSet();
      final nonElements = engine.available
          .where((d) => !engine.isElement(d.id))
          .toList();
      for (var x = 0; x < nonElements.length; x++) {
        for (var y = x + 1; y < nonElements.length; y++) {
          final a = nonElements[x].id,
              b = nonElements[y].id,
              r = engine.forward(a, b);
          if (r == null) continue;
          final k = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
          if (!allowed.contains('$k=>${r.result}') && errors.length < 12) {
            errors.add('extra result $k => ${r.result}');
          }
        }
      }
      expect(errors, isEmpty, reason: errors.join('\n'));
      expect(count, greaterThan(1000));
    });
  }
  for (final raw in fixtures) {
    final j = raw as Map;
    final game = j['game'] as String;
    final enabled = Set<String>.from(j['enabled'] as List);
    test('upstream element fusion parity $game DLC ${enabled.length}', () {
      final engine = FusionEngine(games[game]!, enabled),
          names = List<String>.from(j['names'] as List);
      final errors = <String>[];
      for (final tuple in j['elements'] as List) {
        final a = names[tuple[0] as int],
            b = names[tuple[1] as int],
            expected = names[tuple[2] as int];
        final actual = engine.forward(a, b)?.result;
        if (actual != expected && errors.length < 10) {
          errors.add('$a + $b: $actual != $expected');
        }
      }
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }
  test('P4G upstream triple fixtures', () {
    final engine = FusionEngine(games['p4g']!, {});
    final samples =
        jsonDecode(
              File('test/fixtures/upstream_triples.json').readAsStringSync(),
            )
            as List;
    final errors = <String>[];
    for (final sample in samples) {
      final j = sample as Map;
      final ids = List<String>.from(j['inputs'] as List);
      final result = engine.triple(
        ids,
        currentLevels: j['current'] is Map
            ? Map<String, int>.from(j['current'] as Map)
            : {},
      );
      if (result?.kind == '특수 합체') continue;
      if (result?.result != j['result'] && errors.length < 12) {
        errors.add('${ids.join(' + ')}: ${result?.result} != ${j['result']}');
      }
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
