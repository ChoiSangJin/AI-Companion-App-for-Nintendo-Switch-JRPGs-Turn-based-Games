import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/planner.dart';
import '../services/planner_store.dart';
import 'planner_components.dart';

typedef RunAction = Future<void> Function(Future<void> Function());

Future<void> openSource(BuildContext context, String address) async {
  try {
    final uri = Uri.parse(address);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('No browser');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('브라우저에서 열어 주세요: $address')));
    }
  }
}

class PokemonCatalog extends StatefulWidget {
  const PokemonCatalog({super.key, required this.store, required this.onOpen});
  final PlannerStore store;
  final void Function(PokemonLine) onOpen;
  @override
  State<PokemonCatalog> createState() => _PokemonCatalogState();
}

class _PokemonCatalogState extends State<PokemonCatalog> {
  String query = '', filter = '전체';
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final suggested = store.data
        .recommended(store.edition, store.adventure.starter)
        .map((l) => l.id)
        .toSet();
    final available = store.data.available(
      store.edition,
      store.adventure.starter,
    );
    final visible = available
        .where(
          (l) =>
              l.matches(query) &&
              switch (filter) {
                '추천' => suggested.contains(l.id),
                '버전 전용' => l.versions.length == 1,
                '전체' => true,
                _ => l.stage == filter,
              },
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        const SectionTitle(
          '함께 모험할 포켓몬',
          subtitle: '본편 스토리용 선별 카드 · 전체 도감이 아닙니다.',
        ),
        TextField(
          key: const ValueKey('pokemon-search'),
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '이름·진화형·타입·전국도감 번호 검색',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['전체', '추천', '초반', '중반', '후반', '버전 전용']
              .map(
                (f) => FilterChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                ),
              )
              .toList(),
        ),
        if (filter == '추천' && suggested.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('현황판에서 첫 파트너를 선택하면 추천 파티 예시를 볼 수 있어요.'),
          ),
        const SizedBox(height: 8),
        Text(
          '${store.editionName} · ${visible.length}개 육성 경로',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...visible.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              key: ValueKey('pokemon-${l.id}'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => widget.onOpen(l),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Monogram(l.name, l.forms.first.types.first),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.name,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (store.adventure.party.any(
                                  (m) => m.lineId == l.id,
                                ))
                                  const Icon(Icons.check_circle, size: 20),
                              ],
                            ),
                            Text(
                              l.forms.map((f) => f.name).join(' → '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            typeTags(l.forms.first.types),
                            const SizedBox(height: 8),
                            Text(
                              '${l.stage}${l.versions.length == 1 ? ' · ${l.versions.first == 'scarlet' ? '스칼렛' : '바이올렛'} 전용' : ''}',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (visible.isEmpty)
          const FieldCard(
            child: Text('조건에 맞는 선별 카드가 없습니다. 다른 이름이나 필터로 찾아보세요.'),
          ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => TypeMatchupPage(store: store)),
          ),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('상대 타입으로 약점 확인'),
        ),
        const SizedBox(height: 8),
        const Text(
          '진화·타입은 수록 데이터 기준입니다. 출현 위치는 간략 힌트이며, 정확한 범위는 게임 도감의 서식지와 카드의 상세 자료를 확인하세요.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class PokemonSheet extends StatelessWidget {
  const PokemonSheet({
    super.key,
    required this.store,
    required this.line,
    required this.run,
  });
  final PlannerStore store;
  final PokemonLine line;
  final RunAction run;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final member = store.adventure.party
          .where((m) => m.lineId == line.id)
          .firstOrNull;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.96,
        builder: (context, scroll) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('육성 카드'),
              actions: [
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            body: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(
                22,
                12,
                22,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Monogram(line.name, line.forms.first.types.first, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 27,
                            ),
                          ),
                          Text(
                            '전국도감 No.${line.forms.first.id} · ${line.stage} 후보',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                typeTags(line.forms.first.types),
                const SectionTitle('이 포켓몬을 고르는 이유'),
                Text(line.reason),
                const SectionTitle('어디서 만날까'),
                Text(line.location),
                const SectionTitle(
                  '육성 경로',
                  subtitle: '실제 게임 진행에 맞춰 직접 체크합니다. 레벨·걸음 수는 자동으로 읽지 않습니다.',
                ),
                if (member != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('포획·입수 완료'),
                    value: member.captured,
                    onChanged: (v) async {
                      if (!v &&
                          member.evolution > 0 &&
                          !await confirm(
                            context,
                            '포획 전으로 되돌릴까요?',
                            '체크한 진화 단계도 초기 상태로 돌아갑니다.',
                          )) {
                        return;
                      }
                      await run(() => store.updateMember(line.id, captured: v));
                    },
                  ),
                for (var i = 0; i < line.forms.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FieldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${i + 1}. ${line.forms[i].name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              if (member != null &&
                                  member.captured &&
                                  member.evolution >= i)
                                const Icon(Icons.check_circle_outline),
                            ],
                          ),
                          const SizedBox(height: 8),
                          typeTags(line.forms[i].types),
                          if (i > 0) ...[
                            const SizedBox(height: 8),
                            Text(line.conditions[i - 1]),
                            if (member != null && member.captured)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => run(
                                    () => store.updateMember(
                                      line.id,
                                      evolution: member.evolution >= i
                                          ? i - 1
                                          : i,
                                    ),
                                  ),
                                  child: Text(
                                    member.evolution >= i
                                        ? '이 단계 이전으로 되돌리기'
                                        : '여기까지 진화 완료',
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (member == null)
                  FilledButton.icon(
                    onPressed: () => run(() => store.addMember(line.id)),
                    icon: const Icon(Icons.add),
                    label: const Text('내 파티에 추가'),
                  )
                else ...[
                  Text(member.memo.isEmpty ? '아직 개인 메모가 없어요.' : member.memo),
                  TextButton.icon(
                    onPressed: () async {
                      final values = await editFields(
                        context,
                        title: '${line.name} 육성 메모',
                        labels: ['메모 (선택)'],
                        values: [member.memo],
                      );
                      if (values != null) {
                        await run(
                          () => store.updateMember(line.id, memo: values[0]),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('개인 메모 수정'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        '파티에서 제외할까요?',
                        '이 포켓몬의 포획·진화 체크와 개인 메모가 삭제됩니다. 다시 추가하면 처음부터 시작합니다.',
                      )) {
                        return;
                      }
                      await run(() => store.removeMember(line.id));
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('파티에서 제외'),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => run(
                    () => store.addTask(
                      '${line.name} 포획·육성 조건 확인',
                      line.location,
                      sourceId: line.id,
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('내 할 일에도 고정'),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => openSource(context, line.source),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('상세 서식지·기술 자료 (Serebii · 영어)'),
                ),
                TextButton(
                  onPressed: () =>
                      openSource(context, 'https://github.com/PokeAPI/pokeapi'),
                  child: const Text('이름·타입·진화 기초 데이터 출처'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class RoutePage extends StatefulWidget {
  const RoutePage({super.key, required this.store, required this.run});
  final PlannerStore store;
  final RunAction run;
  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  String filter = '전체';
  bool hideDone = false;
  @override
  Widget build(BuildContext context) {
    final store = widget.store, a = store.adventure;
    final route = store.data.route
        .where(
          (r) =>
              (filter == '전체' || filter == r.kind) &&
              (!hideDone || !a.completed.contains(r.id)),
        )
        .toList();
    return ListView(
      key: PageStorageKey('route-${store.edition}'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        SectionTitle(
          '팔데아 진행 루트',
          subtitle: '체육관 8 · 주인 5 · 스타단 5  /  완료 ${a.completed.length}/18',
        ),
        const FieldCard(
          child: Text(
            '레벨이 낮은 목표부터 섞어 진행하는 추천 순서입니다. 정답이나 필수 동선이 아니며, 상대는 진행도에 맞춰 자동으로 강해지지 않습니다. 레벨은 상대 최고 레벨 기준이고 주인은 참고값입니다. 주요 목표 이후의 이야기 결말은 표시하지 않습니다.',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ['전체', '체육관', '주인', '스타단']
              .map(
                (f) => FilterChip(
                  selected: filter == f,
                  label: Text(f),
                  onSelected: (_) => setState(() => filter = f),
                ),
              )
              .toList(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('완료한 목표 숨기기'),
          value: hideDone,
          onChanged: (v) => setState(() => hideDone = v),
        ),
        ...route.map((r) {
          final done = a.completed.contains(r.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ExpansionTile(
                key: PageStorageKey('route-stop-${store.edition}-${r.id}'),
                leading: Checkbox(
                  semanticLabel: '${r.title} 완료',
                  value: done,
                  onChanged: (v) =>
                      widget.run(() => store.completeRoute(r.id, v!)),
                ),
                title: Text(
                  '${store.data.route.indexOf(r) + 1}. ${r.title}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text('${r.kind} · ${r.type} · Lv.${r.level}'),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.tip),
                        if (r.reward.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('이동 능력 해금: ${r.reward}'),
                          ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => widget.run(
                            () => store.addTask(
                              '${r.title} 준비',
                              r.tip,
                              sourceId: 'route-${r.id}',
                            ),
                          ),
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('준비할 일에 고정'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (route.isEmpty)
          const FieldCard(child: Text('표시할 목표가 없어요. 완료 숨기기와 필터를 확인해 주세요.')),
        TextButton.icon(
          onPressed: () => openSource(
            context,
            'https://www.serebii.net/scarletviolet/gyms.shtml',
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('체육관 상세 자료 (Serebii · 영어)'),
        ),
        TextButton(
          onPressed: () => openSource(
            context,
            'https://www.serebii.net/scarletviolet/titanpokemon.shtml',
          ),
          child: const Text('주인 포켓몬 상세 자료'),
        ),
        TextButton(
          onPressed: () => openSource(
            context,
            'https://www.serebii.net/scarletviolet/teamstar.shtml',
          ),
          child: const Text('스타단 상세 자료'),
        ),
      ],
    );
  }
}

class TypeMatchupPage extends StatefulWidget {
  const TypeMatchupPage({super.key, required this.store});
  final PlannerStore store;
  @override
  State<TypeMatchupPage> createState() => _TypeMatchupPageState();
}

class _TypeMatchupPageState extends State<TypeMatchupPage> {
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final entries = widget.store.data.typeChart.keys
        .map(
          (attack) => MapEntry(
            attack,
            widget.store.data.effectiveness(attack, selected.toList()),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('상대 타입으로 약점 확인')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            '상대의 현재 방어 타입을 최대 두 개 선택하세요.\n테라스탈 후에는 바뀐 방어 타입을 선택합니다. 특성·도구·기술별 예외는 계산하지 않습니다.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.store.data.typeChart.keys
                .map(
                  (t) => FilterChip(
                    label: Text(t),
                    selected: selected.contains(t),
                    onSelected: (v) {
                      if (!v || selected.length < 2) {
                        setState(
                          () => v ? selected.add(t) : selected.remove(t),
                        );
                      }
                    },
                  ),
                )
                .toList(),
          ),
          if (selected.isNotEmpty) ...[
            const SectionTitle('이 공격 타입이 약점을 찔러요'),
            typeTags(
              entries
                  .where((e) => e.value > 1)
                  .map(
                    (e) =>
                        '${e.key} ×${e.value.toStringAsFixed(e.value == e.value.roundToDouble() ? 0 : 2)}',
                  )
                  .toList(),
            ),
            const SectionTitle('효과가 줄거나 없는 공격'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entries
                  .where((e) => e.value < 1)
                  .map((e) => Chip(label: Text('${e.key} ×${e.value}')))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class PlannerSettings extends StatelessWidget {
  const PlannerSettings({super.key, required this.store, required this.run});
  final PlannerStore store;
  final RunAction run;
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
                '팔데아 플래너',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                '스칼렛·바이올렛 본편을 위한 개인 공략 현황판\nAI·API 키·로그인 없이 오프라인으로 사용합니다.\n진행도는 게임과 자동 연동되지 않습니다.',
              ),
            ],
          ),
        ),
        const SectionTitle('내 기록 보관'),
        const Text(
          '스칼렛과 바이올렛의 파티·진행·할 일은 각각 저장됩니다. 앱 삭제나 기기 변경 전에는 백업 내용을 따로 보관하세요.',
        ),
        ListTile(
          leading: const Icon(Icons.copy_all),
          title: const Text('전체 기록 백업'),
          subtitle: const Text('두 버전의 기록을 JSON 텍스트로 복사'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('전체 기록 백업'),
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
          subtitle: const Text('현재 두 버전의 기록을 교체합니다.'),
          onTap: () async {
            final controller = TextEditingController();
            final value = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('백업 내용 붙여넣기'),
                content: SizedBox(
                  width: 520,
                  child: TextField(
                    controller: controller,
                    minLines: 6,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      hintText: '팔데아 플래너의 JSON 백업',
                    ),
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
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 300));
            controller.dispose();
            if (value == null || !context.mounted) return;
            if (await confirm(
              context,
              '현재 기록을 교체할까요?',
              '스칼렛·바이올렛의 파티와 체크 기록이 백업 내용으로 바뀝니다. 이전 앱의 기록은 유지됩니다.',
            )) {
              await run(() => store.restore(value));
            }
          },
        ),
        if (store.legacyRaw != null)
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('이전 앱 기록 열람'),
            subtitle: const Text('기존 공략·목표는 원래 저장 영역에 보존됩니다.'),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => LegacyRecords(raw: store.legacyRaw!),
              ),
            ),
          ),
        const SectionTitle('수록 범위와 출처'),
        Text(
          '${store.data.scope}\n선별 육성 경로 ${store.data.lines.length}개 · 주요 진행 목표 18개\n데이터 기준: ${store.data.revision}\n출현 지역은 간략 힌트이며 전체 도감·상세 지도·대전 최적화 공략은 아닙니다.',
        ),
        const SizedBox(height: 12),
        const Text(
          '이름·타입·기초 진화 조건: PokéAPI 공개 데이터\n지역·추천 파티·진행 순서·준비 팁: 편집한 본편 공략 카드\n카드의 외부 상세 자료는 인터넷 연결이 필요합니다.',
        ),
        TextButton(
          onPressed: () =>
              openSource(context, 'https://github.com/PokeAPI/pokeapi'),
          child: const Text('PokéAPI 데이터 원본'),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '팔데아 플래너',
            applicationVersion: '2.0.0',
          ),
          child: const Text('오픈소스 라이선스'),
        ),
        const SectionTitle('앱에 관하여'),
        const Text(
          '독립 제작 비공식 팬 도구입니다. Nintendo·Game Freak·The Pokémon Company와 제휴하지 않았습니다. Pokémon 및 캐릭터 이름의 권리는 각 권리자에게 있습니다. 앱 아이콘은 별도로 제작한 노트·경로 디자인입니다.\n\n버전 2.0.0 · Android ARM64',
        ),
      ],
    ),
  );
}

class LegacyRecords extends StatelessWidget {
  const LegacyRecords({super.key, required this.raw});
  final String raw;
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    final games = data?['games'] is List ? data!['games'] as List : const [];
    final goals = data?['goals'] is List ? data!['goals'] as List : const [];
    final guides = data?['guides'] is List ? data!['guides'] as List : const [];
    return Scaffold(
      appBar: AppBar(title: const Text('이전 앱 기록')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const FieldCard(
            child: Text(
              '이전 버전의 읽기 전용 보관함입니다. 원래 저장 데이터는 수정하거나 삭제하지 않습니다. 팔데아 플래너의 새 파티와 자동으로 합쳐지지 않습니다.',
            ),
          ),
          if (data == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('이전 기록 형식을 읽지 못했습니다. 원본은 보존되어 있습니다.'),
            ),
          SectionTitle('등록 게임 ${games.length}'),
          ...games.whereType<Map>().map(
            (g) => ListTile(
              title: Text('${g['name'] ?? ''}'),
              subtitle: Text('${g['progress'] ?? ''}'),
            ),
          ),
          SectionTitle('고정 목표 ${goals.length}'),
          ...goals.whereType<Map>().map((g) {
            final steps = g['completedSteps'] is List
                ? g['completedSteps'] as List
                : const [];
            final complete = steps.isNotEmpty
                ? steps.every((s) => s == true)
                : g['done'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FieldCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${complete ? '완료' : '진행 중'} · ${g['title'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (g['memo'] is String && (g['memo'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(g['memo'] as String),
                      ),
                    if (g['guide'] is Map)
                      LegacyGuideBody(
                        guide: g['guide'] as Map,
                        completedSteps: steps,
                      ),
                  ],
                ),
              ),
            );
          }),
          SectionTitle('저장 공략 ${guides.length}'),
          ...guides.whereType<Map>().map(
            (g) => ExpansionTile(
              key: PageStorageKey('legacy-${g['id'] ?? guides.indexOf(g)}'),
              title: Text('${g['title'] ?? '저장 공략'}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: LegacyGuideBody(guide: g),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이전 기록 원본을 복사했습니다.')),
                );
              }
            },
            child: const Text('이전 기록 원본 복사'),
          ),
        ],
      ),
    );
  }
}

class LegacyGuideBody extends StatelessWidget {
  const LegacyGuideBody({
    super.key,
    required this.guide,
    this.completedSteps = const [],
  });
  final Map guide;
  final List completedSteps;
  @override
  Widget build(BuildContext context) {
    final items = guide['items'] is List ? guide['items'] as List : const [];
    final sources = guide['sources'] is List
        ? guide['sources'] as List
        : const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (guide['summary'] is String) Text(guide['summary'] as String),
        for (final item in items.whereType<Map>()) ...[
          const SizedBox(height: 12),
          Text(
            '${item['isChecked'] == true ? '✓ ' : ''}${item['label'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final key in [
            'value',
            'note',
            'reason',
            'availability',
            'deadline',
          ])
            if (item[key] is String && (item[key] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item[key] as String),
              ),
          if (item['steps'] is List)
            for (final entry in (item['steps'] as List).asMap().entries)
              if (entry.value is Map)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${entry.key < completedSteps.length && completedSteps[entry.key] == true ? '✓' : '○'} ${(entry.value as Map)['label'] ?? ''} · ${(entry.value as Map)['value'] ?? ''}\n${(entry.value as Map)['condition'] ?? ''}',
                  ),
                ),
        ],
        for (final source in sources.whereType<Map>())
          if ((source['url'] ?? source['uri']) is String &&
              Uri.tryParse(
                    (source['url'] ?? source['uri']) as String,
                  )?.scheme ==
                  'https')
            TextButton.icon(
              onPressed: () => openSource(
                context,
                (source['url'] ?? source['uri']) as String,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('${source['title'] ?? '원문 출처'}'),
            ),
      ],
    );
  }
}
