import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/compendium.dart';

class CompendiumProfile {
  CompendiumProfile({
    Set<String>? registered,
    Set<String>? favorites,
    Set<String>? dlc,
  }) : registered = registered ?? {},
       favorites = favorites ?? {},
       dlc = dlc ?? {};
  final Set<String> registered, favorites, dlc;
  Map<String, dynamic> toJson() => {
    'registered': registered.toList(),
    'favorites': favorites.toList(),
    'dlc': dlc.toList(),
  };
  factory CompendiumProfile.fromJson(Map<String, dynamic> j) =>
      CompendiumProfile(
        registered: Set<String>.from(j['registered'] as List),
        favorites: Set<String>.from(j['favorites'] as List),
        dlc: Set<String>.from(j['dlc'] as List),
      );
}

class CompendiumStore extends ChangeNotifier {
  CompendiumStore(this.preferences, this.games, {this.write}) {
    profiles = {
      for (final g in games.values) g.id: CompendiumProfile(dlc: g.defaultDlc),
    };
  }
  final SharedPreferences preferences;
  final Map<String, GameData> games;
  final Future<bool> Function(String, String)? write;
  static const key = 'fusion.compendium.v1';
  String selected = 'p3r';
  late Map<String, CompendiumProfile> profiles;
  GameData get game => games[selected]!;
  CompendiumProfile profile(String id) => profiles[id]!;
  Future<void> _writes = Future.value();
  Map<String, dynamic> _json() => {
    'schema': 1,
    'selected': selected,
    'profiles': profiles.map((k, v) => MapEntry(k, v.toJson())),
  };
  (String, Map<String, CompendiumProfile>) _decode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['schema'] != 1 || !games.containsKey(j['selected'])) {
        throw const FormatException();
      }
      final ps = (j['profiles'] as Map).map(
        (k, v) => MapEntry(
          k as String,
          CompendiumProfile.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      );
      if (!ps.keys.every(games.containsKey)) {
        throw const FormatException();
      }
      for (final game in games.values) {
        ps.putIfAbsent(game.id, () => CompendiumProfile(dlc: game.defaultDlc));
      }
      for (final entry in ps.entries) {
        final g = games[entry.key]!, p = entry.value;
        if (!p.registered.every(g.byId.containsKey) ||
            !p.favorites.every(g.byId.containsKey) ||
            !p.dlc.every((id) => g.dlc.any((d) => d.id == id))) {
          throw const FormatException();
        }
      }
      return (j['selected'] as String, ps);
    } catch (_) {
      throw const FormatException('합체전서 기록 형식을 확인해 주세요. 현재 기록은 변경하지 않았습니다.');
    }
  }

  void load() {
    final raw = preferences.getString(key);
    if (raw == null) return;
    final (next, ps) = _decode(raw);
    selected = next;
    profiles = ps;
  }

  Future<void> _change(
    void Function(Map<String, CompendiumProfile>) action, {
    String? selection,
    String? restored,
  }) {
    final next = _writes.then((_) async {
      final (nextId, copy) = _decode(restored ?? jsonEncode(_json()));
      action(copy);
      final chosen = selection ?? nextId;
      if (!games.containsKey(chosen)) {
        throw const FormatException('지원하는 작품을 선택하세요.');
      }
      final encoded = jsonEncode({
        'schema': 1,
        'selected': chosen,
        'profiles': copy.map((k, v) => MapEntry(k, v.toJson())),
      });
      _decode(encoded);
      final ok =
          await (write?.call(key, encoded) ??
              preferences.setString(key, encoded));
      if (!ok) throw StateError('저장 실패');
      selected = chosen;
      profiles = copy;
      notifyListeners();
    });
    _writes = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> selectGame(String id) => _change((_) {}, selection: id);
  Future<void> register(String gameId, String id, bool value) => _change((ps) {
    if (!games[gameId]!.byId.containsKey(id)) {
      throw const FormatException('전서 항목을 찾지 못했습니다.');
    }
    if (value) {
      ps[gameId]!.registered.add(id);
    } else {
      ps[gameId]!.registered.remove(id);
    }
  });
  Future<void> favorite(String gameId, String id, bool value) => _change((ps) {
    if (!games[gameId]!.byId.containsKey(id)) {
      throw const FormatException('전서 항목을 찾지 못했습니다.');
    }
    if (value) {
      ps[gameId]!.favorites.add(id);
    } else {
      ps[gameId]!.favorites.remove(id);
    }
  });
  Future<void> setDlc(String gameId, String id, bool value) => _change((ps) {
    if (!games[gameId]!.dlc.any((g) => g.id == id)) {
      throw const FormatException('DLC 항목을 찾지 못했습니다.');
    }
    if (value) {
      ps[gameId]!.dlc.add(id);
    } else {
      ps[gameId]!.dlc.remove(id);
    }
  });
  Future<void> allDlc(String gameId, bool value) => _change((ps) {
    ps[gameId]!.dlc
      ..clear()
      ..addAll(value ? games[gameId]!.dlc.map((g) => g.id) : <String>[]);
  });
  String backup() => const JsonEncoder.withIndent('  ').convert(_json());
  Future<void> restore(String raw) async {
    _decode(raw);
    await _change((_) {}, restored: raw);
  }

  Map<String, String> get archives => {
    for (final entry in {
      '팔데아 플래너': 'paldea.planner.v1',
      '이전 공략집': 'companion.v1',
    }.entries)
      if (preferences.getString(entry.value) != null)
        entry.key: preferences.getString(entry.value)!,
  };
}
