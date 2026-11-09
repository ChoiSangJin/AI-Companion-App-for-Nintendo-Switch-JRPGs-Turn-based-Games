import 'package:flutter/material.dart';
import '../models/compendium.dart';
import '../services/compendium_store.dart';
import 'fusion_components.dart';
import 'fusion_pages.dart';

typedef StoreAction = Future<void> Function(Future<void> Function());
Color gameColor(String id) => switch (id) {
  'p3r' => const Color(0xFF77B8F4),
  'p4g' => const Color(0xFFE5C366),
  'p5r' => const Color(0xFFEF7D81),
  _ => const Color(0xFF7BD3CB),
};

class FusionHome extends StatefulWidget {
  const FusionHome({super.key, required this.store});
  final CompendiumStore store;
  @override
  State<FusionHome> createState() => _FusionHomeState();
}

class _FusionHomeState extends State<FusionHome> {
  int tab = 0;
  bool registeredView = false;
  CompendiumStore get store => widget.store;
  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : '저장하지 못했습니다. 기존 기록은 유지됩니다. 다시 시도해 주세요.',
            ),
          ),
        );
      }
    }
  }

  void open(Demon d) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          DemonPage(store: store, game: store.game, demon: d, run: run),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final game = store.game, profile = store.profile(game.id);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '합체전서',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            Text(
              'COMPENDIUM · FUSION RECIPES',
              style: TextStyle(fontSize: 9, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '기록·앱 안내',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => FusionSettingsPage(store: store, run: run),
              ),
            ),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('game-${store.selected}'),
                          initialValue: store.selected,
                          isDense: false,
                          isExpanded: true,
                          itemHeight: 72,
                          decoration: const InputDecoration(
                            labelText: '작품 선택',
                            contentPadding: EdgeInsets.fromLTRB(14, 8, 12, 8),
                          ),
                          items: store.games.values
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        g.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            if (id != null) run(() => store.selectGame(id));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '이 작품 DLC 설정',
                            onPressed: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DlcPage(store: store, game: game, run: run),
                              ),
                            ),
                            icon: Badge(
                              label: Text('${profile.dlc.length}'),
                              child: const Icon(Icons.extension_outlined),
                            ),
                          ),
                          const Text('DLC', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tab == 1
                      ? ForwardPanel(
                          key: ValueKey('forward-${game.id}'),
                          store: store,
                          onOpen: open,
                        )
                      : tab == 2
                      ? Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('합체 목표'),
                                    icon: Icon(Icons.bookmark_outline),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('등록한 전서'),
                                    icon: Icon(Icons.check_circle_outline),
                                  ),
                                ],
                                selected: {registeredView},
                                onSelectionChanged: (v) =>
                                    setState(() => registeredView = v.single),
                              ),
                            ),
                            Expanded(
                              child: CompendiumPanel(
                                key: ValueKey(
                                  '${game.id}-saved-$registeredView',
                                ),
                                store: store,
                                run: run,
                                onOpen: open,
                                collection: registeredView
                                    ? 'registered'
                                    : 'favorites',
                              ),
                            ),
                          ],
                        )
                      : CompendiumPanel(
                          key: ValueKey('catalog-${game.id}'),
                          store: store,
                          run: run,
                          onOpen: open,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '악마전서',
          ),
          NavigationDestination(icon: Icon(Icons.merge_type), label: '합체 계산'),
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            selectedIcon: Icon(Icons.bookmarks),
            label: '내 전서',
          ),
        ],
      ),
    );
  }
}

class CompendiumPanel extends StatefulWidget {
  const CompendiumPanel({
    super.key,
    required this.store,
    required this.run,
    required this.onOpen,
    this.collection,
  });
  final CompendiumStore store;
  final StoreAction run;
  final void Function(Demon) onOpen;
  final String? collection;
  @override
  State<CompendiumPanel> createState() => _CompendiumPanelState();
}

class _CompendiumPanelState extends State<CompendiumPanel> {
  String query = '', race = '';
  int level = 150;
  @override
  Widget build(BuildContext context) {
    final store = widget.store, g = store.game, p = store.profile(g.id);
    final active = g.available(p.dlc).map((d) => d.id).toSet();
    var entries = widget.collection == 'favorites'
        ? g.demons.where((d) => p.favorites.contains(d.id)).toList()
        : widget.collection == 'registered'
        ? g.demons.where((d) => p.registered.contains(d.id)).toList()
        : g.available(p.dlc);
    entries =
        entries
            .where(
              (d) =>
                  d.matches(query) &&
                  (race.isEmpty || race == d.race) &&
                  d.level <= level,
            )
            .toList()
          ..sort(
            (a, b) => a.level.compareTo(b.level) != 0
                ? a.level.compareTo(b.level)
                : a.name.compareTo(b.name),
          );
    final races = {for (final d in g.demons) d.race: d.raceName};
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.collection == 'favorites'
                      ? '만들고 싶은 ${g.noun}'
                      : widget.collection == 'registered'
                      ? '등록한 ${g.noun}'
                      : '${g.noun} 전서',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${g.shortTitle} · ${entries.length}종 표시 / 전체 ${g.demons.length}종',
                  style: TextStyle(fontSize: 12, color: gameColor(g.id)),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('demon-search'),
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '한국어·영문 이름, 종족/아르카나 검색',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      label: Text(race.isEmpty ? '전체 종족/아르카나' : races[race]!),
                      onPressed: () async {
                        final value = await showDialog<String>(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: const Text('종족 / 아르카나'),
                            children: [
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(context, ''),
                                child: const Text('전체'),
                              ),
                              ...races.entries.map(
                                (e) => SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(context, e.key),
                                  child: Text(e.value),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (value != null && mounted) {
                          setState(() => race = value);
                        }
                      },
                    ),
                    ActionChip(
                      label: Text(level == 150 ? '레벨 전체' : 'Lv.$level 이하'),
                      onPressed: () async {
                        final value = await chooseLevel(
                          context,
                          level,
                          title: '표시할 기본 레벨',
                        );
                        if (value != null && mounted) {
                          setState(() => level = value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '체크는 직접 기록하는 전서 등록 표시입니다. 게임과 자동 연동되지 않습니다.',
                  style: TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.collection == null
                      ? '조건에 맞는 전서 항목이 없어요. 검색어와 DLC 설정을 확인해 주세요.'
                      : '아직 저장한 항목이 없어요. 전서 상세에서 목표 저장 또는 등록 표시를 해보세요.',
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final d = entries[i];
                return DemonTile(
                  demon: d,
                  game: g,
                  registered: p.registered.contains(d.id),
                  disabled: !active.contains(d.id),
                  onTap: () => widget.onOpen(d),
                  onRegister: () => widget.run(
                    () => store.register(
                      g.id,
                      d.id,
                      !p.registered.contains(d.id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class DemonTile extends StatelessWidget {
  const DemonTile({
    super.key,
    required this.demon,
    required this.game,
    required this.onTap,
    this.onRegister,
    this.registered = false,
    this.disabled = false,
  });
  final Demon demon;
  final GameData game;
  final VoidCallback onTap;
  final VoidCallback? onRegister;
  final bool registered, disabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      key: ValueKey('demon-${demon.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: gameColor(game.id).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '${demon.level}',
            style: TextStyle(
              color: gameColor(game.id),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          demon.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        subtitle: Text(
          '${demon.raceName}${demon.name != demon.id ? ' · ${demon.id}' : ''}${disabled ? '\nDLC 설정에서 제외됨' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: onRegister == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: registered ? '전서 등록 해제' : '전서 등록',
                icon: Icon(
                  registered ? Icons.check_circle : Icons.add_circle_outline,
                  color: registered ? gameColor(game.id) : null,
                ),
                onPressed: onRegister,
              ),
        onTap: onTap,
      ),
    ),
  );
}
