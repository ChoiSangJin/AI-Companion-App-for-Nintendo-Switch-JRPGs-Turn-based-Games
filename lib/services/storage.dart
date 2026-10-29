import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class LocalStore {
  LocalStore(this.preferences);
  final SharedPreferences preferences;
  List<GameProfile> games = [];
  List<GuideData> guides = [];
  String? selectedId;
  String model = 'gemini-2.5-flash';
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
        'selectedId': selectedId,
        'model': model,
      }),
    );
    if (!ok) throw StateError('로컬 저장 실패. 저장 공간을 확인하세요.');
  }
}
