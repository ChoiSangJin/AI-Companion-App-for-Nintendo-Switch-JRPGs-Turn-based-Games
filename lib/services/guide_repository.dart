import '../data/game_catalog.dart';
import '../models/models.dart';
import 'gemini.dart';
import 'storage.dart';

class GuideRepository {
  GuideRepository(this.store, this.api);
  final LocalStore store;
  final GeminiService api;
  Future<GuideData> load({
    required GameProfile game,
    required GuideTopic topic,
    required String key,
    String target = '',
    bool refresh = false,
  }) async {
    if (topic.needsProgress && game.progress.trim().isEmpty) {
      throw const FormatException('현재 진행 구간을 먼저 선택하세요.');
    }
    if (topic == GuideTopic.build && target.trim().isEmpty) {
      throw const FormatException('캐릭터를 먼저 선택하세요.');
    }
    final context = GeminiService.contextKey(game, topic, target, store.model);
    final cached = store.cachedGuide(context);
    if (!refresh && cached != null) return cached;
    final guide = await api.request(
      key: key,
      model: store.model,
      game: game,
      category: topic.id,
      text: target,
      convert: false,
      topic: topic,
      target: target,
    );
    // Refresh must preserve completed tasks when the same task remains present.
    if (cached != null) {
      for (final item in guide.items) {
        item.isChecked = cached.items.any(
          (old) =>
              old.label == item.label &&
              old.value == item.value &&
              old.deadline == item.deadline &&
              old.isChecked,
        );
      }
    }
    final previous = List<GuideData>.of(store.guides);
    store.putGuide(guide);
    try {
      await store.save();
    } catch (_) {
      store.guides = previous;
      rethrow;
    }
    return guide;
  }
}
