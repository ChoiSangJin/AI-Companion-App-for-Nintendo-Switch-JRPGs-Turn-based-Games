import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/models.dart';
import 'services/gemini.dart';
import 'services/storage.dart';
import 'data/game_catalog.dart';
import 'services/guide_repository.dart';
import 'widgets/game_picker.dart';
import 'widgets/guide_page.dart';
import 'widgets/guide_details.dart';
import 'widgets/guide_sources.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = LocalStore(await SharedPreferences.getInstance())..load();
    runApp(CompanionApp(store: store));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              '로컬 데이터를 불러오지 못했습니다.\n앱 데이터를 삭제하지 말고 저장 공간을 확인한 뒤 재실행하세요.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, required this.store});
  final LocalStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Switch 공략 컴패니언',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF65E6BC),
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    home: Home(store: store),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, required this.store});
  final LocalStore store;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final api = GeminiService();
  final secure = const FlutterSecureStorage();
  final query = TextEditingController(),
      pasted = TextEditingController(),
      filter = TextEditingController();
  String category = 'weakness';
  int tab = 0;
  bool busy = false, hideDone = false;
  GuideData? result;
  LocalStore get store => widget.store;
  GameProfile? get game =>
      store.games.where((g) => g.id == store.selectedId).firstOrNull;
  @override
  void dispose() {
    api.close();
    query.dispose();
    pasted.dispose();
    filter.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<bool> persist() async {
    try {
      await store.save();
      if (mounted) setState(() {});
      return true;
    } catch (_) {
      message('저장 실패: 저장 공간을 확인하세요.');
      return false;
    }
  }

  Future<void> addGame() async {
    final picked = await Navigator.push<GameDefinition>(
      context,
      MaterialPageRoute(builder: (_) => const GamePickerPage()),
    );
    if (picked == null || !mounted) return;
    if (picked.id == genericGame.id) {
      await _addCustomGame();
      return;
    }
    final existing = store.games
        .where(
          (g) =>
              g.catalogId == picked.id ||
              normalizeGameQuery(g.name) == normalizeGameQuery(picked.name),
        )
        .firstOrNull;
    if (existing == null) {
      store.games.add(picked.profile());
      store.selectedId = picked.id;
    } else {
      final index = store.games.indexOf(existing);
      store.games[index] = GameProfile(
        id: existing.id,
        name: picked.name,
        rules: existing.rules,
        catalogId: picked.id,
        progress: existing.progress,
      );
      store.selectedId = existing.id;
    }
    result = null;
    await persist();
  }

  Future<void> _addCustomGame() async {
    final values = await editDialog(
      '게임 추가',
      ['', ''],
      ['게임 이름', '커스텀 규칙 (선택)'],
    );
    if (values == null || values.first.isEmpty) return;
    final profile = GameProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: values[0],
      rules: values[1],
    );
    store.games.add(profile);
    store.selectedId = profile.id;
    result = null;
    await persist();
  }

  Future<List<String>?> editDialog(
    String title,
    List<String> initial,
    List<String> labels,
  ) async {
    final controllers = initial
        .map((s) => TextEditingController(text: s))
        .toList();
    final value = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                controllers.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[i],
                    minLines: 1,
                    maxLines: i == 0 ? 2 : 5,
                    decoration: InputDecoration(labelText: labels[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controllers.map((c) => c.text.trim()).toList(),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    // The dialog's exit animation may still reference its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in controllers) {
      c.dispose();
    }
    return value;
  }

  Future<bool> confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> deleteGame() async {
    final current = game;
    if (current == null || !await confirm('${current.name}과 저장된 공략을 삭제할까요?')) {
      return;
    }
    store.games.removeWhere((g) => g.id == current.id);
    store.guides.removeWhere((g) => g.gameId == current.id);
    store.selectedId = store.games.firstOrNull?.id;
    result = null;
    await persist();
  }

  Future<void> request(bool convert) async {
    final current = game;
    if (current == null || busy) return;
    final input = (convert ? pasted.text : query.text).trim();
    if (input.isEmpty) {
      message('검색어 또는 공략 텍스트를 입력하세요.');
      return;
    }
    if (input.length > 30000) {
      message('한 번에 30,000자 이하로 입력하세요.');
      return;
    }
    setState(() => busy = true);
    try {
      final key = await secure.read(key: 'gemini_api_key') ?? '';
      final guide = await api.request(
        key: key,
        model: store.model,
        game: current,
        category: category,
        text: input,
        convert: convert,
      );
      if (!mounted) return;
      if (convert) {
        store.guides.insert(0, guide);
        if (await persist() && mounted) setState(() => tab = 2);
      } else {
        setState(() => result = guide);
      }
    } on FormatException catch (e) {
      message(e.message);
    } catch (_) {
      message('요청 처리에 실패했습니다. 설정과 연결을 확인하세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> settings() async {
    try {
      final key = await secure.read(key: 'gemini_api_key') ?? '';
      if (!mounted) return;
      final keyInput = TextEditingController(text: key),
          modelInput = TextEditingController(text: store.model);
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gemini 설정'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '검색어·붙여넣은 공략·게임 이름과 규칙은 Google Gemini로 전송됩니다. API 사용료가 발생할 수 있습니다. 공략집은 기기에만 저장됩니다.\n',
                  ),
                  TextField(
                    controller: keyInput,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Google AI Studio API 키 (비우면 삭제)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: modelInput,
                    decoration: const InputDecoration(
                      labelText: '모델명',
                      helperText: '예: gemini-2.5-flash · Google 검색 지원 모델',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'API 키는 Android 보안 저장소에 저장됩니다. 앱 삭제 시 로컬 데이터도 삭제됩니다. AI의 스포일러 차단과 정답은 보장되지 않으므로 출처를 확인하세요.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (save == true) {
        final model = modelInput.text.trim();
        if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model)) {
          message('유효한 모델명을 입력하세요.');
        } else {
          if (keyInput.text.trim().isEmpty) {
            await secure.delete(key: 'gemini_api_key');
          } else {
            await secure.write(
              key: 'gemini_api_key',
              value: keyInput.text.trim(),
            );
          }
          store.model = model;
          await persist();
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      keyInput.dispose();
      modelInput.dispose();
    } catch (_) {
      message('보안 저장소에 접근할 수 없습니다. 기기 잠금 설정을 확인하세요.');
    }
  }

  Future<void> editGuide(GuideData g) async {
    final values = await editDialog(
      '공략 수정',
      [g.title, g.summary],
      ['제목', '요약'],
    );
    if (values == null || values[0].isEmpty) return;
    final index = store.guides.indexOf(g);
    store.guides[index] = GuideData.fromJson({
      ...g.toJson(),
      'title': values[0],
      'summary': values[1],
    });
    await persist();
  }

  Future<void> editItem(GuideData guide, int index) async {
    final item = guide.items[index];
    final values = await editDialog(
      '항목 수정',
      [item.label, item.value, item.note],
      ['항목', '내용', '조건'],
    );
    if (values == null || values[0].isEmpty) return;
    guide.items[index] = GuideItem.fromJson({
      ...item.toJson(),
      'label': values[0],
      'value': values[1],
      'note': values[2],
    });
    await persist();
  }

  Future<bool> _editProgress() async {
    final current = game;
    if (current == null) return false;
    final definition = definitionFor(current) ?? genericGame;
    final input = TextEditingController(text: current.progress);
    String? month = definition.progressOptions.contains(current.progress)
        ? current.progress
        : null;
    final next = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(definition.progressLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이 구간에서 확인할 공략을 요청합니다. 변경한 구간은 기기에 기억합니다.'),
              const SizedBox(height: 16),
              if (definition.progressOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: month,
                  hint: const Text('현재 월 선택'),
                  items: definition.progressOptions
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (m) => update(() => month = m),
                )
              else
                TextField(
                  controller: input,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: '예: 5장 / 두 번째 체육관 직전',
                  ),
                  onChanged: (_) => update(() {}),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('구간 해제'),
            ),
            FilledButton(
              onPressed:
                  (definition.progressOptions.isNotEmpty
                      ? month == null
                      : input.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(
                      context,
                      definition.progressOptions.isNotEmpty
                          ? month
                          : input.text.trim(),
                    ),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    if (next == null || !mounted) return false;
    store.games[store.games.indexOf(current)] = current.copyWith(
      progress: next,
    );
    final ok = await persist();
    if (!ok) {
      store.games[store.games.indexWhere((g) => g.id == current.id)] = current;
      if (mounted) setState(() {});
    }
    return ok;
  }

  Future<void> _editRules() async {
    final current = game;
    if (current == null) return;
    final values = await editDialog(
      '추천 조건',
      [current.rules],
      ['난이도·루트·DLC·사용할 멤버 (선택)'],
    );
    if (values == null || !mounted) return;
    store.games[store.games.indexOf(current)] = current.copyWith(
      rules: values[0],
    );
    if (!await persist()) {
      store.games[store.games.indexWhere((g) => g.id == current.id)] = current;
      if (mounted) setState(() {});
    }
  }

  Future<GuideData> _loadGuided(
    GameProfile selected,
    GuideTopic topic,
    String target,
    bool refresh,
  ) async {
    final cached = store.cachedGuide(
      GeminiService.contextKey(selected, topic, target, store.model),
    );
    if (!refresh && cached != null) return cached;
    final key = await secure.read(key: 'gemini_api_key') ?? '';
    return GuideRepository(store, api).load(
      game: selected,
      topic: topic,
      key: key,
      target: target,
      refresh: refresh,
    );
  }

  Future<void> _openTopic(GuideTopic topic, {GuideData? initialGuide}) async {
    if (topic.needsProgress &&
        initialGuide == null &&
        game?.progress.isEmpty == true) {
      if (!await _editProgress()) return;
    }
    final current = game;
    if (current == null || !mounted) return;
    if (topic.needsProgress &&
        initialGuide == null &&
        current.progress.isEmpty) {
      return;
    }
    final selected = initialGuide == null
        ? current
        : current.copyWith(
            progress: initialGuide.progress,
            rules: initialGuide.contextRules,
          );
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GuidePage(
          game: selected,
          topic: topic,
          initialGuide: initialGuide,
          target: initialGuide?.target ?? '',
          load: (t, target, refresh) =>
              _loadGuided(selected, t, target, refresh),
          persist: store.save,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  List<Widget> _dashboardCards() {
    final current = game!;
    final definition = definitionFor(current) ?? genericGame;
    final recent = store.guides
        .where((g) => g.gameId == current.id && g.topic.isNotEmpty)
        .take(3)
        .toList();
    return [
      Text('이 게임의 공략', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(definition.platform),
      if (definition.verifyAvailability)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '공략 요청 시 발매·공개 정보를 먼저 확인합니다. 공개된 공략이 부족하면 결과를 제공하지 못할 수 있습니다.',
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.flag_outlined, size: 18),
            label: Text(
              current.progress.isEmpty
                  ? '${definition.progressLabel} 선택'
                  : current.progress,
            ),
            onPressed: busy ? null : _editProgress,
          ),
          ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: Text(current.rules.isEmpty ? '추천 조건 설정' : '추천 조건 변경'),
            onPressed: busy ? null : _editRules,
          ),
          ActionChip(
            avatar: const Icon(Icons.search, size: 18),
            label: const Text('다른 게임 찾기'),
            onPressed: addGame,
          ),
        ],
      ),
      if (current.rules.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('조건: ${current.rules}'),
        ),
      const SizedBox(height: 12),
      for (final topic in definition.topics)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(switch (topic) {
              GuideTopic.roster ||
              GuideTopic.build => Icons.account_tree_outlined,
              GuideTopic.party => Icons.groups_outlined,
              GuideTopic.route => Icons.route_outlined,
              GuideTopic.missables => Icons.event_available_outlined,
            }),
            title: Text(
              topic == GuideTopic.roster ? '캐릭터별 추천 직업·육성' : topic.label,
            ),
            subtitle: Text(
              topic == GuideTopic.roster
                  ? '캐릭터 선택 → 추천 직업 → 단계별 조건'
                  : topic.description,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : () => _openTopic(topic),
          ),
        ),
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          '최근 확인한 공략 · 오프라인',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final guide in recent)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(guide.title),
            subtitle: Text(
              [
                guide.target,
                guide.progress,
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
            trailing: const Icon(Icons.history),
            onTap: () {
              final topic = GuideTopic.values
                  .where((t) => t.id == guide.topic)
                  .firstOrNull;
              if (topic != null) _openTopic(topic, initialGuide: guide);
            },
          ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget guideCard(GuideData g, {required bool saved}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(g.summary),
          const Divider(),
          ...g.items
              .asMap()
              .entries
              .where((e) => !hideDone || !e.value.isChecked || !saved)
              .map((entry) {
                final item = entry.value;
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(item.value),
                    GuideDetails(item: item),
                    if (item.note.isNotEmpty)
                      Text(
                        item.note,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                );
                return Row(
                  children: [
                    Expanded(
                      child: g.isChecklist && saved
                          ? CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: item.isChecked,
                              onChanged: (v) async {
                                item.isChecked = v ?? false;
                                await persist();
                              },
                              title: text,
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: text,
                            ),
                    ),
                    if (saved)
                      IconButton(
                        tooltip: '항목 수정',
                        onPressed: () => editItem(g, entry.key),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                );
              }),
          if (g.sources.isNotEmpty)
            const Text(
              'Google 검색 출처',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ...g.sources.map(
            (s) => TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(s['title'] ?? '출처'),
              onPressed: () async {
                final uri = Uri.tryParse(s['uri'] ?? '');
                if (uri == null || uri.scheme != 'https') {
                  message('출처 주소를 열 수 없습니다.');
                  return;
                }
                try {
                  if (!await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    message('브라우저를 열 수 없습니다.');
                  }
                } catch (_) {
                  message('브라우저를 열 수 없습니다.');
                }
              },
            ),
          ),
          if (g.searchEntryPoint.isNotEmpty)
            SearchSuggestion(html: g.searchEntryPoint),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: saved
                ? [
                    TextButton.icon(
                      onPressed: () => editGuide(g),
                      icon: const Icon(Icons.edit),
                      label: const Text('수정'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        if (await confirm('이 공략을 삭제할까요?')) {
                          store.guides.remove(g);
                          await persist();
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                  ]
                : [
                    FilledButton.icon(
                      onPressed: store.guides.any((s) => s.id == g.id)
                          ? null
                          : () async {
                              store.guides.insert(0, g);
                              if (await persist()) message('내 공략집에 저장했습니다.');
                            },
                      icon: const Icon(Icons.save_alt),
                      label: const Text('내 공략집에 저장'),
                    ),
                  ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final filtered = store.guides
        .where(
          (g) =>
              g.gameId == store.selectedId &&
              '${g.title} ${g.summary} ${g.items.map((i) => i.searchText).join(' ')}'
                  .toLowerCase()
                  .contains(filter.text.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Switch 공략집'),
        actions: [
          IconButton(
            tooltip: '게임 추가',
            onPressed: busy ? null : addGame,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: '설정',
            onPressed: busy ? null : settings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: busy ? null : deleteGame,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('게임을 찾아 선택하세요'),
                        value: game?.id,
                        items: store.games
                            .map(
                              (g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  g.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) async {
                                store.selectedId = v;
                                result = null;
                                await persist();
                              },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '현재 게임 삭제',
                    onPressed: busy || game == null ? null : deleteGame,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: game == null
                  ? Center(
                      child: FilledButton.icon(
                        onPressed: addGame,
                        icon: const Icon(Icons.add),
                        label: const Text('게임 찾기'),
                      ),
                    )
                  : IndexedStack(
                      index: tab,
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ..._dashboardCards(),
                            ExpansionTile(
                              title: const Text('추가 질문 직접 검색'),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  children: List.generate(
                                    4,
                                    (i) => ChoiceChip(
                                      label: Text(
                                        [
                                          '⚔️ 약점/보스',
                                          '💬 선택지/정답',
                                          '🧪 조합/수집',
                                          '📋 일정/체크리스트',
                                        ][i],
                                      ),
                                      selected:
                                          category == GuideData.categories[i],
                                      onSelected: busy
                                          ? null
                                          : (_) => setState(
                                              () => category =
                                                  GuideData.categories[i],
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: query,
                                  enabled: !busy,
                                  maxLength: 300,
                                  onSubmitted: (_) => request(false),
                                  decoration: const InputDecoration(
                                    labelText: '검색어',
                                    hintText: '예: 망나뇽 약점 / 5월 시험',
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: busy ? null : () => request(false),
                                  icon: const Icon(Icons.search),
                                  label: const Text('Google 검색으로 공략 찾기'),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    '게임 버전은 Switch 기준 · AI 결과와 출처를 함께 확인하세요.',
                                  ),
                                ),
                                if (result != null)
                                  guideCard(result!, saved: false),
                              ],
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              '공략 → 체크리스트',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '붙여넣은 텍스트는 변환을 위해 Google로 전송됩니다. 원문에 포함된 스포일러에 주의하세요.',
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: pasted,
                              enabled: !busy,
                              minLines: 10,
                              maxLines: 20,
                              maxLength: 30000,
                              decoration: const InputDecoration(
                                labelText: '복사한 공략 붙여넣기',
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: busy ? null : () => request(true),
                              icon: const Icon(Icons.checklist),
                              label: const Text('변환하고 로컬 저장'),
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            TextField(
                              controller: filter,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: '저장된 공략 검색',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            SwitchListTile(
                              title: const Text('완료한 항목 숨기기'),
                              value: hideDone,
                              onChanged: (v) => setState(() => hideDone = v),
                            ),
                            if (filtered.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  '저장된 공략이 없습니다. 검색 결과를 저장하거나 공략을 변환하세요.',
                                ),
                              ),
                            ...filtered.map((g) => guideCard(g, saved: true)),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: '게임 공략',
          ),
          NavigationDestination(icon: Icon(Icons.playlist_add), label: '공략 변환'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: '내 공략집',
          ),
        ],
      ),
    );
  }
}
