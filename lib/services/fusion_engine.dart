// Fusion rules adapted from aqiu384/megaten-fusion-tool (Unlicense).
// Canonical IDs remain English. Learned/current level never replaces base level
// in a normal average; P4G triple ordering and P5R treasure fusion are exceptions.
import '../models/compendium.dart';

class FusionEngine {
  FusionEngine(this.game, this.enabledDlc) {
    available = game.available(enabledDlc);
    ids = available.map((d) => d.id).toSet();
    for (final d in available) {
      if (!game.special.containsKey(d.id)) {
        (results[d.race] ??= []).add(d);
      }
    }
    for (final list in results.values) {
      list.sort((a, b) => a.level.compareTo(b.level));
    }
    for (final entry in game.special.entries) {
      if (entry.value.length == 3 &&
          ids.contains(entry.key) &&
          entry.value.every(ids.contains)) {
        tripleSpecials[([...entry.value]..sort()).join('|')] = entry.key;
      }
      if (entry.value.length == 2 &&
          ids.contains(entry.key) &&
          entry.value.every(ids.contains)) {
        pairSpecials[_pair(entry.value[0], entry.value[1])] = entry.key;
      }
    }
  }
  final GameData game;
  final Set<String> enabledDlc;
  late final List<Demon> available;
  late final Set<String> ids;
  final Map<String, List<Demon>> results = {};
  final Map<String, String> pairSpecials = {};
  final Map<String, String> tripleSpecials = {};
  Map<String, List<FusionRecipe>>? _reverse;
  static String _pair(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
  bool isElement(String id) => game.elements.contains(id);
  FusionRecipe? forward(String first, String second, {int? currentLevel}) {
    if (first == second || !ids.contains(first) || !ids.contains(second)) {
      return null;
    }
    final special = pairSpecials[_pair(first, second)];
    if (special != null) {
      return FusionRecipe(
        inputs: [first, second],
        result: special,
        kind: '특수 합체',
      );
    }
    final a = game.byId[first]!, b = game.byId[second]!;
    final ae = isElement(first), be = isElement(second);
    String? result;
    var kind = '2신 합체';
    if (ae && be) {
      if (game.id != 'p5r') return null;
      final race = game.normalChart[a.race]?[b.race];
      final pool = results[race] ?? [];
      if (pool.isNotEmpty) {
        result =
            (pool.where((d) => d.level > (a.level + b.level) / 2).firstOrNull ??
                    pool.last)
                .id;
      }
      kind = '보마 합체';
    } else if (ae || be) {
      final element = ae ? a : b, normal = ae ? b : a;
      final offset = game.elementChart[element.id]?[normal.race];
      if (offset == null || offset == 0) return null;
      final pool = results[normal.race] ?? [];
      if (pool.isEmpty) return null;
      final level = game.id == 'p5r'
          ? (currentLevel ?? normal.level)
          : normal.level;
      if (currentLevel != null &&
          (currentLevel < normal.level || currentLevel > 99)) {
        return null;
      }
      final exact = pool.indexWhere((d) => d.level == level);
      int index;
      if (exact >= 0) {
        index = exact + offset;
      } else {
        final insertion = pool.indexWhere((d) => d.level > level);
        final next = insertion < 0 ? pool.length : insertion;
        index = next + offset - (offset > 0 ? 1 : 0);
      }
      if (index >= 0 && index < pool.length && pool[index].id == normal.id) {
        index += offset > 0 ? 1 : -1;
      }
      if (index >= 0 && index < pool.length) result = pool[index].id;
      kind = game.id == 'p5r' ? '보마 합체' : '정령 합체';
    } else if (a.race == b.race) {
      if (game.id == 'smt5v') {
        final element = game.normalChart[a.race]?[a.race];
        if (element != null && isElement(element) && ids.contains(element)) {
          result = element;
        }
        kind = '정령 생성';
      } else {
        final threshold = (a.level + b.level) / 2 + 1;
        final pool = (results[a.race] ?? [])
            .where((d) => d.id != a.id && d.id != b.id && d.level <= threshold)
            .toList();
        if (pool.isNotEmpty) result = pool.last.id;
      }
    } else {
      final race = game.normalChart[a.race]?[b.race];
      final pool = results[race] ?? [];
      if (pool.isNotEmpty) {
        final threshold =
            (a.level + b.level) / 2 + (game.id == 'smt5v' ? 1 : .5);
        var found = pool.indexWhere((d) => d.level >= threshold);
        if (found < 0) found = pool.length - 1;
        if (pool[found].id == first || pool[found].id == second) {
          found++;
        }
        if (found < pool.length) result = pool[found].id;
      }
    }
    if (result == null ||
        result == first ||
        result == second ||
        !ids.contains(result)) {
      return null;
    }
    return FusionRecipe(inputs: [first, second], result: result, kind: kind);
  }

  FusionRecipe? triple(
    List<String> inputs, {
    Map<String, int> currentLevels = const {},
  }) {
    if (game.id != 'p4g' ||
        inputs.length != 3 ||
        inputs.toSet().length != 3 ||
        inputs.any((id) => !ids.contains(id))) {
      return null;
    }
    final ds = inputs.map((id) => game.byId[id]!).toList();
    if (ds.any(
      (d) =>
          (currentLevels[d.id] ?? d.level) < d.level ||
          (currentLevels[d.id] ?? d.level) > 99,
    )) {
      return null;
    }
    final special = tripleSpecials[([...inputs]..sort()).join('|')];
    if (special != null) {
      return FusionRecipe(inputs: inputs, result: special, kind: '특수 합체');
    }
    ds.sort((a, b) {
      final diff = (currentLevels[b.id] ?? b.level).compareTo(
        currentLevels[a.id] ?? a.level,
      );
      return diff != 0
          ? diff
          : game.races.indexOf(a.race).compareTo(game.races.indexOf(b.race));
    });
    String? race;
    if (ds.every((d) => d.race == ds.first.race)) {
      race = game.tripleChart[ds.first.race]?[ds.first.race];
    } else {
      final ab = ds[1].race == ds[2].race
          ? ds[1].race
          : game.normalChart[ds[1].race]?[ds[2].race];
      race = ab == null ? null : game.tripleChart[ds[0].race]?[ab];
    }
    final threshold = ds.fold<int>(0, (sum, d) => sum + d.level) / 3 + 4.25;
    final pool = results[race] ?? [];
    final candidate = pool
        .where((d) => d.level >= threshold && !inputs.contains(d.id))
        .firstOrNull;
    return candidate == null
        ? null
        : FusionRecipe(inputs: inputs, result: candidate.id, kind: '3신 합체');
  }

  List<FusionRecipe> reverse(
    String target, {
    Set<String>? owned,
    int maxLevel = 150,
  }) {
    if (!ids.contains(target)) return [];
    _reverse ??= _buildReverse();
    final recipes = <FusionRecipe>[...?_reverse![target]];
    final special = game.special[target];
    if (special != null && special.length > 2 && special.every(ids.contains)) {
      recipes.insert(
        0,
        FusionRecipe(inputs: special, result: target, kind: '특수 합체'),
      );
    }
    return recipes
        .where(
          (r) => r.inputs.every(
            (id) =>
                game.byId[id]!.level <= maxLevel &&
                (owned == null || owned.contains(id)),
          ),
        )
        .toList()
      ..sort((a, b) {
        final s = a.kind == '특수 합체'
            ? -1
            : b.kind == '특수 합체'
            ? 1
            : 0;
        if (s != 0 && a.kind != b.kind) return s;
        final al = a.inputs
                .map((id) => game.byId[id]!.level)
                .reduce((x, y) => x > y ? x : y),
            bl = b.inputs
                .map((id) => game.byId[id]!.level)
                .reduce((x, y) => x > y ? x : y);
        return al.compareTo(bl);
      });
  }

  Map<String, List<FusionRecipe>> _buildReverse() {
    final result = <String, List<FusionRecipe>>{};
    for (var i = 0; i < available.length; i++) {
      for (var j = i + 1; j < available.length; j++) {
        final recipe = forward(available[i].id, available[j].id);
        if (recipe != null) (result[recipe.result] ??= []).add(recipe);
      }
    }
    return result;
  }

  List<FusionRecipe> reverseTriple(
    String target, {
    Set<String>? owned,
    int maxLevel = 99,
    int limit = 100,
  }) {
    if (game.id != 'p4g' ||
        !ids.contains(target) ||
        game.special.containsKey(target)) {
      return [];
    }
    final candidates = available
        .where(
          (d) => d.level <= maxLevel && (owned == null || owned.contains(d.id)),
        )
        .toList();
    final found = <FusionRecipe>[];
    for (var i = 0; i < candidates.length; i++) {
      for (var j = i + 1; j < candidates.length; j++) {
        for (var k = j + 1; k < candidates.length; k++) {
          if ((candidates[i].level +
                          candidates[j].level +
                          candidates[k].level) /
                      3 +
                  4.25 >
              game.byId[target]!.level) {
            break;
          }
          final recipe = triple([
            candidates[i].id,
            candidates[j].id,
            candidates[k].id,
          ]);
          if (recipe?.result == target) {
            found.add(recipe!);
            if (found.length >= limit) return found;
          }
        }
      }
    }
    return found;
  }
}

List<Map<String, dynamic>> findTripleRecipes(Map<String, dynamic> request) {
  final game = GameData.fromJson(
    Map<String, dynamic>.from(request['game'] as Map),
  );
  final engine = FusionEngine(game, Set<String>.from(request['dlc'] as List));
  return engine
      .reverseTriple(
        request['target'] as String,
        owned: request['owned'] == null
            ? null
            : Set<String>.from(request['owned'] as List),
        maxLevel: request['maxLevel'] as int,
        limit: request['limit'] as int,
      )
      .map((r) => r.toJson())
      .toList();
}

List<Map<String, dynamic>> findNormalRecipes(Map<String, dynamic> request) {
  final game = GameData.fromJson(
    Map<String, dynamic>.from(request['game'] as Map),
  );
  final engine = FusionEngine(game, Set<String>.from(request['dlc'] as List));
  return engine
      .reverse(
        request['target'] as String,
        owned: request['owned'] == null
            ? null
            : Set<String>.from(request['owned'] as List),
        maxLevel: request['maxLevel'] as int,
      )
      .map((r) => r.toJson())
      .toList();
}
