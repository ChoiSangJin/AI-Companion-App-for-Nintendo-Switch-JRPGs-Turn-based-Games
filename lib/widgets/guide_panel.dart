import 'package:material_ui/material_ui.dart';

import '../models/compendium.dart';
import '../services/compendium_store.dart';

class GuidePanel extends StatefulWidget {
  const GuidePanel({super.key, required this.store, required this.onOpen});

  final CompendiumStore store;
  final void Function(Demon) onOpen;

  @override
  State<GuidePanel> createState() => _GuidePanelState();
}

class _GuidePanelState extends State<GuidePanel> {
  bool unlocks = false;
  String query = '';
  String element = '';

  @override
  Widget build(BuildContext context) {
    final game = widget.store.game;
    final profile = widget.store.profile(game.id);
    final available = game.available(profile.dlc);
    final elements = <String>{
      for (final demon in available) ...demon.resists.keys,
    }.where((value) => value != '만능').toList();

    var entries = available.where((demon) => demon.matches(query)).toList();
    if (unlocks) {
      entries = entries
          .where((demon) => demon.requirements.isNotEmpty)
          .toList();
    } else {
      entries = entries.where((demon) {
        if (element.isNotEmpty) return demon.resists[element] == '약점';
        return demon.resists.values.contains('약점');
      }).toList();
    }

    return CustomScrollView(
      key: PageStorageKey('guide-${game.id}-$unlocks'),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '빠른 공략',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '${game.shortTitle} · 검증된 오프라인 전서 데이터',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.bolt_outlined),
                      label: Text('약점 검색'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.lock_open_outlined),
                      label: Text('해금 조건'),
                    ),
                  ],
                  selected: {unlocks},
                  onSelectionChanged: (value) => setState(() {
                    unlocks = value.single;
                    element = '';
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('guide-search'),
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: unlocks
                        ? '해금할 ${game.noun} 이름 검색'
                        : '전투 중 확인할 ${game.noun} 이름 검색',
                  ),
                ),
                if (!unlocks) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          key: const ValueKey('weakness-all'),
                          label: const Text('약점 전체'),
                          selected: element.isEmpty,
                          onSelected: (_) => setState(() => element = ''),
                        ),
                        for (final value in elements) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            key: ValueKey('weakness-$value'),
                            label: Text(value),
                            selected: element == value,
                            onSelected: (_) => setState(() => element = value),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '적 전용 도감이 아니라 소환 가능한 페르소나·악마의 전서 상성입니다.',
                    style: TextStyle(fontSize: 11),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    '퀘스트·커뮤·회차 등 전서 항목의 합체 및 입수 조건만 표시합니다.',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
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
                  unlocks ? '조건에 맞는 해금 정보가 없습니다.' : '선택한 속성이 약점인 항목이 없습니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final demon = entries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: InkWell(
                      key: ValueKey('guide-${demon.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => widget.onOpen(demon),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    demon.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text('Lv.${demon.level} · ${demon.raceName}'),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (unlocks)
                              for (final requirement in demon.requirements)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${_unlockCategory(requirement['category']!)} · ${requirement['text']!}',
                                  ),
                                )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final affinity in demon.resists.entries)
                                    if (affinity.value != '보통')
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '${affinity.key} ${affinity.value}',
                                        ),
                                      ),
                                ],
                              ),
                          ],
                        ),
                      ),
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

String _unlockCategory(String category) => switch (category) {
  'Story Progression' => '스토리·회차',
  'Maxed Social Link' => '커뮤/코옵',
  'Maxed Teammate Link' => '동료 링크',
  'Side Quests' => '퀘스트',
  'Legacy DLC' => '본편 포함 구 DLC',
  'Acquisition' => '별도 입수',
  _ => category,
};
