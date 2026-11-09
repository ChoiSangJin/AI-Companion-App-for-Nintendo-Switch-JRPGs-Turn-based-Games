import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/compendium.dart';
import '../services/compendium_store.dart';
import '../services/fusion_engine.dart';
import 'fusion_components.dart';
import 'fusion_home.dart';

Future<void> openReference(BuildContext context, String url) async {
  try {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('browser');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('브라우저에서 열어 주세요: $url')));
    }
  }
}

class DemonPage extends StatefulWidget {
  const DemonPage({
    super.key,
    required this.store,
    required this.game,
    required this.demon,
    required this.run,
  });
  final CompendiumStore store;
  final GameData game;
  final Demon demon;
  final StoreAction run;
  @override
  State<DemonPage> createState() => _DemonPageState();
}

class _DemonPageState extends State<DemonPage> {
  bool stats = false, ownedOnly = false, loading = false, triples = false;
  int maxLevel = 150, limit = 100, shown = 40, generation = 0;
  String fingerprint = '';
  String? error;
  List<FusionRecipe> recipes = [];
  CompendiumStore get store => widget.store;
  GameData get game => widget.game;
  Demon get demon => widget.demon;
  @override
  void initState() {
    super.initState();
    store.addListener(changed);
    load();
  }

  @override
  void dispose() {
    generation++;
    store.removeListener(changed);
    super.dispose();
  }

  void changed() {
    load();
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    final p = store.profile(game.id);
    final next =
        '${([...p.dlc]..sort()).join('|')}/$ownedOnly/${ownedOnly ? ([...p.registered]..sort()).join('|') : ''}/$maxLevel/$triples/$limit';
    if (next == fingerprint) return;
    fingerprint = next;
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      recipes = [];
      shown = 40;
    });
    try {
      final result =
          await compute(triples ? findTripleRecipes : findNormalRecipes, {
            'game': game.raw,
            'dlc': p.dlc.toList(),
            'target': demon.id,
            'owned': ownedOnly ? p.registered.toList() : null,
            'maxLevel': maxLevel,
            'limit': limit,
          });
      if (mounted && request == generation) {
        setState(() => recipes = result.map(FusionRecipe.fromJson).toList());
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = '레시피를 계산하지 못했습니다. 설정을 확인하고 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  void open(Demon d) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          DemonPage(store: store, game: game, demon: d, run: widget.run),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final p = store.profile(game.id),
        active = demon.dlc == null || p.dlc.contains(demon.dlc);
    return Scaffold(
      appBar: AppBar(
        title: Text(demon.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: p.favorites.contains(demon.id) ? '합체 목표 해제' : '합체 목표 저장',
            onPressed: () => widget.run(
              () => store.favorite(
                game.id,
                demon.id,
                !p.favorites.contains(demon.id),
              ),
            ),
            icon: Icon(
              p.favorites.contains(demon.id)
                  ? Icons.bookmark
                  : Icons.bookmark_outline,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  game.title,
                  style: TextStyle(fontSize: 12, color: gameColor(game.id)),
                ),
                const SizedBox(height: 8),
                Text(
                  demon.name,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(demon.id, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(demon.raceName)),
                    Chip(label: Text('기본 Lv.${demon.level}')),
                    if (demon.dlc != null) const Chip(label: Text('DLC')),
                    if (demon.acquisition == 'special')
                      const Chip(label: Text('특수 합체')),
                    if (demon.acquisition == 'accident')
                      const Chip(label: Text('합체 사고 / 별도 입수')),
                    if (demon.acquisition == 'element')
                      Chip(label: Text(game.id == 'p5r' ? '보마' : '정령')),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('내 전서에 등록 표시'),
                  subtitle: const Text('소환 가능한 재료를 찾을 때 쓰는 직접 기록입니다.'),
                  value: p.registered.contains(demon.id),
                  onChanged: (v) =>
                      widget.run(() => store.register(game.id, demon.id, v)),
                ),
                if (!active)
                  FieldCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '현재 DLC 설정에서 제외된 항목입니다. 설정을 바꾸기 전에는 레시피를 표시하지 않습니다.',
                        ),
                        TextButton(
                          onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DlcPage(
                                store: store,
                                game: game,
                                run: widget.run,
                              ),
                            ),
                          ),
                          child: const Text('이 작품 DLC 설정 열기'),
                        ),
                      ],
                    ),
                  ),
                if (demon.requirements.isNotEmpty)
                  ExpansionTile(
                    key: PageStorageKey('unlock-${game.id}-${demon.id}'),
                    title: const Text('합체·입수 해금 조건 보기'),
                    subtitle: const Text('퀘스트·커뮤·회차 관련 정보가 포함될 수 있어요.'),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    children: demon.requirements
                        .map(
                          (r) => ListTile(
                            dense: true,
                            title: Text(unlockCategory(r['category']!)),
                            subtitle: Text(r['text']!),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('합체 레시피'),
                      icon: Icon(Icons.merge_type),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('능력·스킬'),
                      icon: Icon(Icons.insights),
                    ),
                  ],
                  selected: {stats},
                  onSelectionChanged: (v) => setState(() => stats = v.single),
                ),
                const SizedBox(height: 18),
                if (stats)
                  ...statContents()
                else if (active)
                  ...recipeContents(),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => openReference(
                    context,
                    game.sourceUrl(demon.id).toString(),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('원본 합체 도구에서 확인 (영어)'),
                ),
                const Text(
                  '기본 데이터와 선택한 DLC 조건으로 계산합니다. 해금·주인공 레벨·소환 비용·특수 이벤트 여부는 게임에서 별도로 확인하세요.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> recipeContents() => [
    if (game.id == 'p4g' || game.id == 'p5r')
      FieldCard(
        child: Text(
          game.id == 'p4g'
              ? '3신 역검색은 재료가 기본 레벨일 때의 조합입니다. 육성한 재료는 합체 계산에서 현재 레벨을 지정하세요.'
              : '보마 역검색은 재료의 기본 레벨 기준입니다. 육성한 재료와 보마를 합칠 때는 합체 계산에서 현재 레벨을 지정하세요.',
        ),
      ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('등록한 재료로만 찾기'),
      value: ownedOnly,
      onChanged: (v) {
        setState(() => ownedOnly = v);
        load();
      },
    ),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ActionChip(
          label: Text(
            maxLevel == 150 ? '재료 레벨 제한 없음' : '재료 기본 Lv.$maxLevel 이하',
          ),
          onPressed: () async {
            final value = await chooseLevel(context, maxLevel);
            if (value != null && mounted) {
              setState(() => maxLevel = value);
              load();
            }
          },
        ),
        if (game.id == 'p4g' && !game.special.containsKey(demon.id))
          ChoiceChip(
            label: const Text('일반 3신 조합'),
            selected: triples,
            onSelected: (v) {
              setState(() {
                triples = v;
                limit = 100;
              });
              load();
            },
          ),
      ],
    ),
    const SizedBox(height: 12),
    if (loading)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      )
    else if (error != null)
      FieldCard(
        child: Column(
          children: [
            Text(error!),
            TextButton(
              onPressed: () {
                fingerprint = '';
                load();
              },
              child: const Text('다시 계산'),
            ),
          ],
        ),
      )
    else if (recipes.isEmpty)
      FieldCard(
        child: Text(
          demon.acquisition == 'element'
              ? '이 항목은 일반 재료 합체로 만들지 않는 보마·정령일 수 있습니다. 게임 내 입수 방법과 원본 자료를 확인하세요.'
              : demon.acquisition == 'accident'
              ? '확정된 일반 합체 조합이 없는 별도 입수 항목입니다. 위의 입수 조건을 확인하세요.'
              : '현재 필터와 데이터에서 조합을 찾지 못했습니다. 등록 재료·레벨 상한·DLC를 확인하세요. ${game.id == 'p4g' && !triples ? '일반 3신 조합도 찾아볼 수 있습니다.' : ''}',
        ),
      ),
    if (!loading && recipes.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          triples
              ? '기본 레벨 3신 조합 · 최대 $limit개 검색'
              : '현재 조건의 조합 ${recipes.length}개',
        ),
      ),
    if (!loading)
      ...recipes
          .take(shown)
          .map(
            (r) => RecipeCard(
              game: game,
              recipe: r,
              registered: store.profile(game.id).registered,
              onOpen: open,
            ),
          ),
    if (!loading && recipes.length > shown)
      OutlinedButton(
        onPressed: () => setState(() => shown += 40),
        child: const Text('조합 더 보기'),
      ),
    if (!loading && triples && recipes.length >= limit)
      TextButton(
        onPressed: () {
          setState(() => limit += 100);
          load();
        },
        child: Text('3신 검색 범위 늘리기 (${limit + 100}개까지)'),
      ),
  ];
  List<Widget> statContents() => [
    const SectionTitle('기본 능력치'),
    Wrap(
      spacing: 8,
      runSpacing: 6,
      children: demon.stats.entries
          .map((e) => Chip(label: Text('${e.key} ${e.value}')))
          .toList(),
    ),
    const SectionTitle('기본 속성 내성'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: demon.resists.entries
          .map(
            (e) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (e.value == '약점' ? Colors.red : Colors.blue).withValues(
                  alpha: .1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${e.key} · ${e.value}',
                style: TextStyle(
                  color: e.value == '약점' ? const Color(0xFFFF9B9B) : null,
                ),
              ),
            ),
          )
          .toList(),
    ),
    const SectionTitle(
      '습득 스킬',
      subtitle: '초기는 입수 시 기본 스킬입니다. 합체 스킬 계승 결과는 계산하지 않습니다.',
    ),
    ...demon.skills.map(
      (s) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(s.name),
        subtitle: s.name == s.id ? null : Text(s.id),
        trailing: Text(s.level < 1 ? '초기' : 'Lv.${s.level}'),
      ),
    ),
  ];
}

String unlockCategory(String category) => switch (category) {
  'Story Progression' => '스토리·회차 조건',
  'Maxed Social Link' => '커뮤/코옵 조건',
  'Maxed Teammate Link' => '동료 링크 조건',
  'Side Quests' => '퀘스트 조건',
  'Legacy DLC' => '본편에 포함된 구 DLC 조건',
  'Acquisition' => '별도 입수 조건',
  _ => category,
};

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.game,
    required this.recipe,
    required this.registered,
    required this.onOpen,
  });
  final GameData game;
  final FusionRecipe recipe;
  final Set<String> registered;
  final void Function(Demon) onOpen;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.kind,
            style: TextStyle(
              fontSize: 12,
              color: gameColor(game.id),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recipe.inputs.map((id) {
              final d = game.byId[id]!;
              return ActionChip(
                avatar: Icon(
                  registered.contains(id)
                      ? Icons.check_circle_outline
                      : Icons.add_circle_outline,
                  size: 16,
                ),
                label: Text('${d.name} · ${d.level}'),
                onPressed: () => onOpen(d),
              );
            }).toList(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.south, size: 18),
          ),
          Text(
            '${game.byId[recipe.result]!.name} · Lv.${game.byId[recipe.result]!.level}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (game.byId[recipe.result]!.requirements.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('별도 해금 조건 있음', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    ),
  );
}

class DlcPage extends StatelessWidget {
  const DlcPage({
    super.key,
    required this.store,
    required this.game,
    required this.run,
  });
  final CompendiumStore store;
  final GameData game;
  final StoreAction run;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('${game.shortTitle} · DLC')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const FieldCard(
            child: Text(
              '게임에 실제로 설치·적용한 DLC에 맞춰 선택하세요. DLC 페르소나가 합체 결과의 레벨 구간에 끼어들 수 있어 일반 조합도 달라집니다. 퀘스트·커뮤 해금 여부와 별개의 설정이며, 설정을 꺼도 등록·목표 기록은 지우지 않습니다.',
            ),
          ),
          if (game.id == 'p5r')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Royal의 기본값은 원본 도구처럼 DLC 전체 포함입니다. 플랫폼·에디션의 실제 설치 상태와 다르면 수정하세요.',
              ),
            ),
          if (game.dlc.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('이 작품 데이터에는 선택할 DLC 합체 항목이 없습니다.'),
            )
          else ...[
            Row(
              children: [
                TextButton(
                  onPressed: () => run(() => store.allDlc(game.id, true)),
                  child: const Text('전체 포함'),
                ),
                TextButton(
                  onPressed: () => run(() => store.allDlc(game.id, false)),
                  child: const Text('전체 제외'),
                ),
              ],
            ),
            ...game.dlc.map(
              (g) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(g.label),
                subtitle: Text(
                  g.members.map((id) => game.byId[id]!.name).join(', '),
                ),
                value: store.profile(game.id).dlc.contains(g.id),
                onChanged: (v) => run(() => store.setDlc(game.id, g.id, v)),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class ForwardPanel extends StatefulWidget {
  const ForwardPanel({super.key, required this.store, required this.onOpen});
  final CompendiumStore store;
  final void Function(Demon) onOpen;
  @override
  State<ForwardPanel> createState() => _ForwardPanelState();
}

class _ForwardPanelState extends State<ForwardPanel> {
  final ids = <String?>[null, null, null];
  final levels = List.generate(3, (_) => TextEditingController());
  bool triple = false;
  @override
  void dispose() {
    for (final c in levels) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.store.game,
        p = widget.store.profile(g.id),
        engine = FusionEngine(g, p.dlc);
    final count = triple ? 3 : 2;
    final selected = ids.take(count).whereType<String>().toList();
    final showLevels =
        triple || g.id == 'p5r' && selected.any(engine.isElement);
    FusionRecipe? result;
    String? error;
    if (selected.length == count) {
      if (selected.any((id) => !engine.ids.contains(id))) {
        error = 'DLC 설정에서 제외된 재료가 있어요. 설정 또는 재료를 바꿔 주세요.';
      } else {
        final values = {
          for (var i = 0; i < count; i++)
            ids[i]!: int.tryParse(levels[i].text) ?? -1,
        };
        if (showLevels &&
            selected.any(
              (id) => values[id]! < g.byId[id]!.level || values[id]! > 99,
            )) {
          error = '현재 레벨은 각 재료의 기본 레벨 이상, 99 이하로 입력하세요.';
        } else {
          result = triple
              ? engine.triple(selected, currentLevels: values)
              : engine.forward(
                  selected[0],
                  selected[1],
                  currentLevel: showLevels
                      ? values[selected.firstWhere(
                          (id) => !engine.isElement(id),
                          orElse: () => selected.first,
                        )]
                      : null,
                );
          if (result == null) {
            error = '현재 데이터와 설정에서 확정 조합을 찾지 못했습니다. 다른 재료나 대상의 특수 합체 조건을 확인하세요.';
          }
        }
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SectionTitle(
          '재료로 결과 찾기',
          subtitle: '작품별 합체표와 기본 레벨로 계산합니다. 합체 사고·경보·스킬 계승은 예측하지 않습니다.',
        ),
        if (g.id == 'p4g')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('3신 합체'),
            value: triple,
            onChanged: (v) => setState(() => triple = v),
          ),
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FieldCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '재료 ${i + 1}',
                    style: TextStyle(color: gameColor(g.id), fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      ids[i] == null ? '${g.noun} 선택' : g.byId[ids[i]]!.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: ids[i] == null
                        ? null
                        : Text(
                            '${g.byId[ids[i]]!.raceName} · 기본 Lv.${g.byId[ids[i]]!.level}',
                          ),
                    trailing: const Icon(Icons.search),
                    onTap: () async {
                      final choice = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (sheetContext) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.viewInsetsOf(
                              sheetContext,
                            ).bottom,
                          ),
                          child: DemonPicker(
                            game: g,
                            available: engine.available,
                            excluded: ids
                                .whereType<String>()
                                .where((id) => id != ids[i])
                                .toSet(),
                          ),
                        ),
                      );
                      if (choice != null && mounted) {
                        setState(() {
                          ids[i] = choice;
                          levels[i].text = '${g.byId[choice]!.level}';
                        });
                      }
                    },
                  ),
                  if (showLevels &&
                      ids[i] != null &&
                      !engine.isElement(ids[i]!))
                    TextField(
                      controller: levels[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '이 재료의 현재 레벨',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                ],
              ),
            ),
          ),
        if (showLevels)
          FieldCard(
            child: Text(
              triple
                  ? '3신 합체의 순서는 현재 레벨과 아르카나 우선순위로 정하고, 결과 레벨 계산에는 기본 레벨을 사용합니다.'
                  : '보마와 합칠 일반 페르소나의 현재 레벨을 입력하세요. 역검색 카드의 기본 레벨 조합과 결과가 다를 수 있습니다.',
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(error),
          ),
        if (result != null) ...[
          const SectionTitle('계산 결과'),
          RecipeCard(
            game: g,
            recipe: result,
            registered: p.registered,
            onOpen: widget.onOpen,
          ),
          FilledButton.icon(
            onPressed: () => widget.onOpen(g.byId[result!.result]!),
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('결과 전서·다른 조합 보기'),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          '고정 재료가 3개 이상인 특수 합체는 악마전서에서 만들 대상을 선택해 확인하세요. 전서 등록·해금·주인공 레벨·비용은 게임에서 별도로 확인해야 합니다.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class DemonPicker extends StatefulWidget {
  const DemonPicker({
    super.key,
    required this.game,
    required this.available,
    required this.excluded,
  });
  final GameData game;
  final List<Demon> available;
  final Set<String> excluded;
  @override
  State<DemonPicker> createState() => _DemonPickerState();
}

class _DemonPickerState extends State<DemonPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.available
        .where((d) => !widget.excluded.contains(d.id) && d.matches(query))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '합체 재료 선택',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                ),
                IconButton(
                  tooltip: '재료 선택 닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              key: const ValueKey('ingredient-search'),
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: '이름·종족/아르카나 검색',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => DemonTile(
                  demon: rows[i],
                  game: widget.game,
                  onTap: () => Navigator.pop(context, rows[i].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FusionSettingsPage extends StatelessWidget {
  const FusionSettingsPage({super.key, required this.store, required this.run});
  final CompendiumStore store;
  final StoreAction run;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('기록·앱 안내')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const FieldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '합체전서',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text('페르소나·진여신전생 악마전서와 합체 레시피\nAI·API 키·로그인 없이 오프라인으로 사용합니다.'),
            ],
          ),
        ),
        const SectionTitle('작품별 기록'),
        const Text(
          '전서 등록·합체 목표·DLC 설정은 작품별로 따로 저장합니다. 앱 삭제나 기기 변경 전 백업을 따로 보관하세요.',
        ),
        ListTile(
          leading: const Icon(Icons.copy_all),
          title: const Text('네 작품 기록 백업'),
          subtitle: const Text('현재 합체전서의 기록을 텍스트로 복사'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('전서 기록 백업'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: SelectableText(store.backup()),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
                FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: store.backup()),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('백업 복사'),
                ),
              ],
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.restore_page_outlined),
          title: const Text('백업에서 복원'),
          subtitle: const Text('확인 후 네 작품의 기록을 교체합니다.'),
          onTap: () async {
            final raw = await showDialog<String>(
              context: context,
              builder: (_) => const BackupInputDialog(),
            );
            if (raw == null || !context.mounted) return;
            if (await confirm(
              context,
              '현재 전서 기록을 교체할까요?',
              '네 작품의 등록·목표·DLC 설정이 백업 내용으로 바뀝니다. 이전 앱 보관 기록은 유지됩니다.',
            )) {
              await run(() => store.restore(raw));
            }
          },
        ),
        if (store.archives.isNotEmpty) ...[
          const SectionTitle('이전 버전 기록 보관'),
          ...store.archives.entries.map(
            (e) => ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('${e.key} 기록'),
              subtitle: const Text('읽기 전용 열람 · 원본 보존'),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ArchivePage(title: e.key, raw: e.value),
                ),
              ),
            ),
          ),
        ],
        const SectionTitle('지원 작품'),
        ...store.games.values.map(
          (g) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(g.name),
            subtitle: Text('${g.title}\n${g.demons.length}개 전서 항목'),
          ),
        ),
        const SectionTitle('계산 범위'),
        const Text(
          '일반 2신·특수 합체·정령/보마 합체와 P4 Golden의 3신 합체를 제공합니다. 역검색은 기본 레벨 기준입니다. 육성 재료의 3신 순서와 보마 합체는 합체 계산의 현재 레벨 입력을 사용하세요.\n\n해금·주인공 레벨·소환 비용·합체 경보/사고·스킬 계승은 자동으로 판정하지 않습니다. 원본 조건 문장은 영문으로 남아 있을 수 있고 한국어 이름이 없는 항목은 영문으로 표시합니다. 원본 데이터에 없는 조합은 추측해 만들지 않습니다.',
        ),
        const SectionTitle('데이터와 출처'),
        const Text(
          'aqiu384의 megaten-database와 megaten-fusion-tool 공개 데이터를 기반으로 합니다. 사용 중에는 API를 호출하지 않으며, 앱에 포함한 스냅샷으로 계산합니다. 데이터 갱신은 앱 업데이트로 제공합니다.',
        ),
        TextButton(
          onPressed: () => openReference(
            context,
            'https://github.com/aqiu384/megaten-database',
          ),
          child: const Text('원본 데이터 저장소'),
        ),
        TextButton(
          onPressed: () => openReference(
            context,
            'https://github.com/aqiu384/megaten-fusion-tool',
          ),
          child: const Text('합체 도구·라이선스 원본'),
        ),
        SelectableText(
          '데이터 커밋: ${store.game.sourceCommit}',
          style: const TextStyle(fontSize: 11),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '합체전서',
            applicationVersion: '3.0.0',
          ),
          child: const Text('오픈소스 라이선스'),
        ),
        const Text(
          '독립 제작 비공식 도구이며 ATLUS·SEGA와 제휴하지 않았습니다. 게임명과 캐릭터 이름의 권리는 각 권리자에게 있습니다.\n\n합체전서 3.0.0 · Android ARM64',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class BackupInputDialog extends StatefulWidget {
  const BackupInputDialog({super.key});
  @override
  State<BackupInputDialog> createState() => _BackupInputDialogState();
}

class _BackupInputDialogState extends State<BackupInputDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('백업 내용 붙여넣기'),
    content: SizedBox(
      width: 520,
      child: TextField(
        controller: controller,
        minLines: 6,
        maxLines: 12,
        decoration: const InputDecoration(hintText: '합체전서에서 복사한 백업 텍스트'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('복원 검토'),
      ),
    ],
  );
}

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key, required this.title, required this.raw});
  final String title, raw;
  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  Map<String, dynamic>? data, names;
  @override
  void initState() {
    super.initState();
    try {
      data = jsonDecode(widget.raw) as Map<String, dynamic>;
    } catch (_) {}
    loadNames();
  }

  Future<void> loadNames() async {
    final value =
        jsonDecode(
              await rootBundle.loadString('assets/archive/paldea_names.json'),
            )
            as Map<String, dynamic>;
    if (mounted) setState(() => names = value);
  }

  @override
  Widget build(BuildContext context) {
    final adventures = data?['adventures'];
    final goals = data?['goals'] is List ? data!['goals'] as List : const [];
    final guides = data?['guides'] is List ? data!['guides'] as List : const [];
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} 보관함')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const FieldCard(
            child: Text(
              '이전 앱의 읽기 전용 보관함입니다. 원래 저장 영역은 수정·삭제하지 않으며 새 전서와 자동으로 합치지 않습니다.',
            ),
          ),
          if (data == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('이전 기록 형식을 읽지 못했습니다. 원본은 그대로 보존되어 있습니다.'),
            ),
          if (adventures is Map)
            ...adventures.entries.where((entry) => entry.value is Map).map((
              entry,
            ) {
              final a = entry.value as Map;
              final party = a['party'] is List ? a['party'] as List : const [];
              final tasks = a['tasks'] is List ? a['tasks'] as List : const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(entry.key == 'scarlet' ? '스칼렛' : '바이올렛'),
                  Text(
                    '진행 목표 ${a['completed'] is List ? (a['completed'] as List).length : 0}개 완료',
                  ),
                  ...party.whereType<Map>().map((m) {
                    final aliases = names?[m['lineId']];
                    final step = m['evolution'] is int
                        ? m['evolution'] as int
                        : 0;
                    final name =
                        aliases is List && step >= 0 && step < aliases.length
                        ? '${aliases[step]}'
                        : '${m['lineId']}';
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        '${m['captured'] == true ? '입수 완료' : '포획 목표'}\n${m['memo'] ?? ''}',
                      ),
                    );
                  }),
                  ...tasks.whereType<Map>().map(
                    (t) => ListTile(
                      title: Text(
                        '${t['done'] == true ? '✓ ' : ''}${t['title'] ?? ''}',
                      ),
                      subtitle: Text('${t['memo'] ?? ''}'),
                    ),
                  ),
                ],
              );
            }),
          if (goals.isNotEmpty) ...[
            const SectionTitle('이전 고정 목표'),
            ...goals.whereType<Map>().map(
              (g) => ListTile(
                title: Text('${g['title'] ?? ''}'),
                subtitle: Text(
                  '${g['memo'] ?? ''}\n완료 단계: ${g['completedSteps'] is List ? (g['completedSteps'] as List).where((v) => v == true).length : 0}',
                ),
              ),
            ),
          ],
          if (guides.isNotEmpty) ...[
            const SectionTitle('이전 저장 공략'),
            ...guides.whereType<Map>().map(
              (g) => ExpansionTile(
                key: PageStorageKey('old-${g['id']}'),
                title: Text('${g['title'] ?? ''}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g['summary'] ?? ''}'),
                        if (g['items'] is List)
                          ...(g['items'] as List).whereType<Map>().map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                '${i['label'] ?? ''}\n${i['value'] ?? ''}\n${i['note'] ?? ''}',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.raw));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이전 기록 원본을 복사했습니다.')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('이전 기록 원본 백업 복사'),
          ),
        ],
      ),
    );
  }
}
