import 'storage.dart';

class AiSettingsRepository {
  AiSettingsRepository({
    required this.store,
    required this.readKey,
    required this.writeKey,
  });
  final LocalStore store;
  final Future<String?> Function() readKey;
  // A null value explicitly removes the secure binding.
  final Future<void> Function(String? value) writeKey;
  Future<void> save(String key, String model) async {
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
      throw const FormatException('공식 목록에서 모델을 선택해 주세요.');
    }
    final previousKey = await readKey();
    final previousModel = store.model;
    await writeKey(key.isEmpty ? null : key);
    store.model = model;
    try {
      await store.save();
    } catch (_) {
      store.model = previousModel;
      await writeKey(previousKey);
      rethrow;
    }
  }
}
