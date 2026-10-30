import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/paldea.dart';
import '../models/planner.dart';

class PlannerStore extends ChangeNotifier {
  PlannerStore(this.preferences, this.data, {this.write});
  final SharedPreferences preferences;
  final PaldeaData data;
  final Future<bool> Function(String key, String value)? write;
  static const storageKey = 'paldea.planner.v1';
  PlannerState state = PlannerState();
  Adventure get adventure => state.current;
  String get edition => state.edition;
  String get editionName => edition == 'scarlet' ? '스칼렛' : '바이올렛';
  Future<void> _writes = Future.value();
  void load() {
    final raw = preferences.getString(storageKey);
    if (raw == null) return;
    final loaded = PlannerState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _validate(loaded);
    state = loaded;
  }

  void _validate(PlannerState value) {
    for (final entry in value.adventures.entries) {
      final a = entry.value;
      if (a.starter != null &&
          !data.lines.any((l) => l.id == a.starter && l.starter)) {
        throw const FormatException('첫 파트너 기록을 확인할 수 없습니다.');
      }
      for (final member in a.party) {
        final l = data.lines
            .where(
              (l) => l.id == member.lineId && l.versions.contains(entry.key),
            )
            .firstOrNull;
        if (l == null ||
            member.evolution >= l.forms.length ||
            (!member.captured && member.evolution > 0)) {
          throw const FormatException('육성 기록을 확인할 수 없습니다.');
        }
      }
      if (a.tasks.any((t) => t.id.isEmpty || t.title.trim().isEmpty) ||
          a.tasks.map((t) => t.id).toSet().length != a.tasks.length) {
        throw const FormatException('할 일 기록을 확인할 수 없습니다.');
      }
      if (a.completed.any((id) => !data.route.any((r) => r.id == id))) {
        throw const FormatException('진행 기록을 확인할 수 없습니다.');
      }
    }
  }

  Future<void> _change(void Function(PlannerState) action) {
    final next = _writes.then((_) async {
      final copy = state.copy();
      action(copy);
      _validate(copy);
      final encoded = jsonEncode(copy.toJson());
      final ok =
          await (write?.call(storageKey, encoded) ??
              preferences.setString(storageKey, encoded));
      if (!ok) throw StateError('기기 저장 실패');
      state = copy;
      notifyListeners();
    });
    _writes = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> selectEdition(String edition) => _change((s) {
    if (!s.adventures.containsKey(edition)) {
      throw const FormatException('버전을 확인하세요.');
    }
    s.edition = edition;
  });
  Future<void> _changeAdventure(
    void Function(Adventure adventure, String edition) action,
  ) {
    final expectedEdition = edition;
    return _change(
      (s) => action(s.adventures[expectedEdition]!, expectedEdition),
    );
  }

  Future<void> chooseStarter(String id) => _changeAdventure((a, edition) {
    if (!data.line(id).starter) throw const FormatException('첫 파트너를 선택하세요.');
    a.starter = id;
  });
  Future<void> addMember(String id) => _changeAdventure((a, edition) {
    final l = data.line(id);
    if (!l.versions.contains(edition)) {
      throw const FormatException('다른 버전의 포켓몬입니다.');
    }
    if (a.party.any((m) => m.lineId == id)) return;
    if (l.starter && a.starter != id) {
      throw const FormatException('먼저 첫 파트너를 선택하세요.');
    }
    if (a.party.length >= 6) {
      throw const FormatException('파티는 최대 6마리입니다. 파티에서 한 마리를 제외한 뒤 추가하세요.');
    }
    a.party.add(PartyMember(lineId: id, captured: l.starter));
  });
  Future<void> updateMember(
    String id, {
    bool? captured,
    int? evolution,
    String? memo,
  }) => _changeAdventure((a, edition) {
    final m = a.party.firstWhere((m) => m.lineId == id);
    if (captured != null) {
      m.captured = captured;
      if (!captured) m.evolution = 0;
    }
    if (evolution != null) m.evolution = evolution;
    if (memo != null) m.memo = memo.trim();
  });
  Future<void> removeMember(String id) => _changeAdventure(
    (a, edition) => a.party.removeWhere((m) => m.lineId == id),
  );
  Future<void> completeRoute(String id, bool done) =>
      _changeAdventure((a, edition) {
        if (done) {
          a.completed.add(id);
        } else {
          a.completed.remove(id);
        }
      });
  Future<void> addTask(String title, String memo, {String? sourceId}) =>
      _changeAdventure((a, edition) {
        if (title.trim().isEmpty) throw const FormatException('할 일을 입력하세요.');
        if (sourceId != null && a.tasks.any((t) => t.sourceId == sourceId)) {
          return;
        }
        a.tasks.add(
          PlannerTask(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title.trim(),
            memo: memo.trim(),
            sourceId: sourceId,
          ),
        );
      });
  Future<void> updateTask(
    String id, {
    bool? done,
    String? title,
    String? memo,
  }) => _changeAdventure((a, edition) {
    final t = a.tasks.firstWhere((t) => t.id == id);
    if (title != null) {
      if (title.trim().isEmpty) throw const FormatException('할 일을 입력하세요.');
      t.title = title.trim();
    }
    if (done != null) t.done = done;
    if (memo != null) t.memo = memo.trim();
  });
  Future<void> removeTask(String id) =>
      _changeAdventure((a, edition) => a.tasks.removeWhere((t) => t.id == id));
  String backup() => const JsonEncoder.withIndent('  ').convert(state.toJson());
  Future<void> restore(String text) async {
    late final PlannerState restored;
    try {
      restored = PlannerState.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );
      _validate(restored);
    } catch (_) {
      throw const FormatException(
        '팔데아 플래너의 올바른 백업인지 확인해 주세요. 현재 기록은 변경되지 않았습니다.',
      );
    }
    await _change((s) {
      s.edition = restored.edition;
      s.adventures
        ..clear()
        ..addAll(restored.adventures);
    });
  }

  String? get legacyRaw => preferences.getString('companion.v1');
}
