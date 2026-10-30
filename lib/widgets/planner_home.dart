import 'package:flutter/material.dart';
import '../models/planner.dart';
import '../services/planner_store.dart';
import 'planner_components.dart';
import 'planner_pages.dart';

class PlannerHome extends StatefulWidget {
  const PlannerHome({super.key, required this.store});
  final PlannerStore store;
  @override
  State<PlannerHome> createState() => _PlannerHomeState();
}

class _PlannerHomeState extends State<PlannerHome> {
  int tab = 0;
  PlannerStore get store => widget.store;
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
                  : '저장하지 못했습니다. 저장 공간을 확인하고 다시 시도해 주세요.',
            ),
          ),
        );
      }
    }
  }

  void openPokemon(PokemonLine line) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PokemonSheet(store: store, line: line, run: run),
  );
  Future<void> task({PlannerTask? task}) async {
    final values = await editFields(
      context,
      title: task == null ? '내 할 일 추가' : '할 일 수정',
      labels: ['할 일', '조건·메모 (선택)'],
      values: task == null ? null : [task.title, task.memo],
    );
    if (values == null || !mounted) return;
    await run(
      () => task == null
          ? store.addTask(values[0], values[1])
          : store.updateTask(task.id, title: values[0], memo: values[1]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '팔데아 플래너',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 21),
          ),
          Text(
            'SCARLET / VIOLET · PERSONAL FIELD NOTES',
            style: TextStyle(fontSize: 9, letterSpacing: 1),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '기록·앱 안내',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => PlannerSettings(store: store, run: run),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'scarlet',
                        label: Text('스칼렛'),
                        icon: Icon(Icons.wb_sunny_outlined),
                      ),
                      ButtonSegment(
                        value: 'violet',
                        label: Text('바이올렛'),
                        icon: Icon(Icons.nightlight_outlined),
                      ),
                    ],
                    selected: {store.edition},
                    onSelectionChanged: (values) =>
                        run(() => store.selectEdition(values.single)),
                  ),
                ),
              ),
              Expanded(
                child: switch (tab) {
                  0 => dashboard(),
                  1 => PokemonCatalog(
                    key: ValueKey('catalog-${store.edition}'),
                    store: store,
                    onOpen: openPokemon,
                  ),
                  _ => RoutePage(store: store, run: run),
                },
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard_rounded),
          label: '내 현황판',
        ),
        NavigationDestination(
          icon: Icon(Icons.catching_pokemon_outlined),
          selectedIcon: Icon(Icons.catching_pokemon),
          label: '파티 찾기',
        ),
        NavigationDestination(
          icon: Icon(Icons.alt_route_rounded),
          label: '진행 루트',
        ),
      ],
    ),
  );
  Widget dashboard() {
    final a = store.adventure, route = store.data.route;
    final next = route.where((r) => !a.completed.contains(r.id)).firstOrNull;
    final recommendations = store.data.recommended(store.edition, a.starter);
    final pending = a.tasks.where((t) => !t.done).toList();
    final done = a.tasks.where((t) => t.done).toList();
    return ListView(
      key: PageStorageKey('dashboard-${store.edition}'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF272B3B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${store.editionName} · 나만의 모험 기록',
                style: const TextStyle(
                  color: Color(0xFFEBD6B3),
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '오늘의 모험 노트',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '파티 ${a.party.length}/6   ·   주요 목표 ${a.completed.length}/18   ·   할 일 ${pending.length}',
                style: const TextStyle(color: Color(0xFFE4E1ED)),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: a.completed.length / 18,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFE5B873),
                ),
              ),
            ],
          ),
        ),
        if (a.starter == null) ...[
          const SectionTitle(
            '첫 파트너를 골라주세요',
            subtitle: '선택한 파트너에 맞춰 스토리 파티 후보를 정리합니다.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: store.data.lines
                .where((l) => l.starter)
                .map(
                  (l) => ActionChip(
                    avatar: Icon(
                      Icons.eco_outlined,
                      color: typeColor(l.forms.first.types.first),
                      size: 18,
                    ),
                    label: Text(l.name),
                    onPressed: () => run(() => store.chooseStarter(l.id)),
                  ),
                )
                .toList(),
          ),
        ],
        SectionTitle(
          '다음 진행 목표',
          subtitle: '레벨 기준 추천 순서 · 완료는 직접 체크',
          action: TextButton(
            onPressed: () => setState(() => tab = 2),
            child: const Text('전체 보기'),
          ),
        ),
        if (next == null)
          const FieldCard(
            child: Text(
              '주요 목표 18개를 모두 체크했어요.\n남은 이야기 마무리와 도감 목표는 내 할 일에 적어두세요.',
            ),
          )
        else
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${next.kind}   /   상대 최고 Lv.${next.level}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  next.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(next.tip),
                if (next.reward.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('이동 능력: ${next.reward}'),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () =>
                        run(() => store.completeRoute(next.id, true)),
                    icon: const Icon(Icons.check),
                    label: const Text('목표 완료'),
                  ),
                ),
              ],
            ),
          ),
        SectionTitle(
          '내 파티',
          subtitle: '포획부터 최종 진화까지 · 탭해서 조건·메모 확인',
          action: TextButton.icon(
            onPressed: () => setState(() => tab = 1),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('추가'),
          ),
        ),
        if (a.party.isEmpty)
          FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups_2_outlined, size: 30),
                const SizedBox(height: 10),
                const Text(
                  '키울 포켓몬을 고정해 보세요.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('포획할 곳과 다음 진화 조건을 이 화면에서 확인할 수 있어요.'),
                TextButton(
                  onPressed: () => setState(() => tab = 1),
                  child: const Text('스토리 파티 후보 보기'),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: a.party.map((member) {
                  final line = store.data.line(member.lineId),
                      form = line.forms[member.evolution];
                  final finished =
                      member.captured &&
                      member.evolution == line.forms.length - 1;
                  return SizedBox(
                    width: wide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: FieldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => openPokemon(line),
                            child: Row(
                              children: [
                                Monogram(form.name, form.types.first),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        form.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 19,
                                        ),
                                      ),
                                      Text(
                                        member.captured
                                            ? '육성 ${member.evolution}/${line.conditions.length}'
                                            : '포획 목표',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          typeTags(form.types),
                          const SizedBox(height: 12),
                          Text(
                            !member.captured
                                ? line.location
                                : finished
                                ? '설정한 진화 경로를 완료했어요.'
                                : '${line.forms[member.evolution + 1].name} → ${line.conditions[member.evolution]}',
                          ),
                          if (member.memo.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                member.memo,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: finished
                                  ? () => openPokemon(line)
                                  : () => run(
                                      () => member.captured
                                          ? store.updateMember(
                                              member.lineId,
                                              evolution: member.evolution + 1,
                                            )
                                          : store.updateMember(
                                              member.lineId,
                                              captured: true,
                                            ),
                                    ),
                              icon: Icon(
                                finished
                                    ? Icons.check_circle_outline
                                    : Icons.check,
                              ),
                              label: Text(
                                finished
                                    ? '육성 기록 보기'
                                    : member.captured
                                    ? '진화 완료'
                                    : '포획 완료',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        if (recommendations.isNotEmpty) ...[
          SectionTitle(
            '이 파트너와 함께 키울 후보',
            subtitle: '스토리용 편성 예시 · 포획 시점·역할을 보고 한 마리씩 선택',
            action: IconButton(
              tooltip: '첫 파트너 변경',
              onPressed: chooseStarter,
              icon: const Icon(Icons.swap_horiz),
            ),
          ),
          FieldCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommendations
                  .map(
                    (l) => ActionChip(
                      avatar: Icon(
                        a.party.any((m) => m.lineId == l.id)
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        size: 18,
                      ),
                      label: Text(l.name),
                      onPressed: () => openPokemon(l),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        SectionTitle(
          '내 할 일',
          subtitle: '도구 준비·포획 계획·개인 메모를 직접 기록',
          action: IconButton(
            tooltip: '할 일 추가',
            onPressed: () => task(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
        if (pending.isEmpty)
          FieldCard(
            child: TextButton.icon(
              onPressed: () => task(),
              icon: const Icon(Icons.edit_note),
              label: const Text('다음에 할 일을 적어두세요'),
            ),
          ),
        ...pending.map(taskTile),
        if (done.isNotEmpty)
          ExpansionTile(
            key: PageStorageKey('completed-tasks-${store.edition}'),
            title: Text('완료한 할 일 ${done.length}'),
            children: done.map(taskTile).toList(),
          ),
        const SizedBox(height: 22),
        const Text(
          '본편 스토리용 선별 공략 · DLC·교환·HOME 제외\n자동 연동 없이 직접 체크하며 모든 기록은 이 기기에 저장됩니다.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64656A)),
        ),
      ],
    );
  }

  Widget taskTile(PlannerTask value) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: CheckboxListTile(
      value: value.done,
      onChanged: (v) => run(() => store.updateTask(value.id, done: v)),
      title: Text(
        value.title,
        style: TextStyle(
          decoration: value.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: value.memo.isEmpty ? null : Text(value.memo),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: PopupMenuButton<String>(
        tooltip: '할 일 메뉴',
        onSelected: (action) async {
          if (action == 'edit') {
            await task(task: value);
          } else if (await confirm(context, '할 일을 삭제할까요?', value.title)) {
            await run(() => store.removeTask(value.id));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('수정')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    ),
  );
  Future<void> chooseStarter() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('첫 파트너 선택'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('추천 후보만 바뀝니다. 기존 파티와 진행 기록은 유지됩니다.'),
          ),
          ...store.data.lines
              .where((l) => l.starter)
              .map(
                (l) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, l.id),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(l.name),
                  ),
                ),
              ),
        ],
      ),
    );
    if (choice != null) await run(() => store.chooseStarter(choice));
  }
}
