import 'package:flutter/material.dart';
import '../data/game_catalog.dart';
import '../models/models.dart';
import 'guide_details.dart';
import 'guide_sources.dart';

typedef GuideLoader =
    Future<GuideData> Function(GuideTopic topic, String target, bool refresh);

class GuidePage extends StatefulWidget {
  const GuidePage({
    super.key,
    required this.game,
    required this.topic,
    required this.load,
    required this.persist,
    this.target = '',
    this.initialGuide,
  });
  final GameProfile game;
  final GuideTopic topic;
  final String target;
  final GuideData? initialGuide;
  final GuideLoader load;
  final Future<void> Function() persist;
  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  GuideData? guide;
  String? error;
  bool loading = false, saving = false;
  @override
  void initState() {
    super.initState();
    guide = widget.initialGuide;
    if (guide == null) _load(false);
  }

  Future<void> _load(bool refresh) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await widget.load(widget.topic, widget.target, refresh);
      if (mounted) setState(() => guide = next);
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = '공략을 불러오거나 저장하지 못했습니다. 연결과 저장 공간을 확인하세요.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggle(GuideItem item, bool checked) async {
    if (saving) return;
    final previous = item.isChecked;
    setState(() {
      item.isChecked = checked;
      saving = true;
    });
    try {
      await widget.persist();
    } catch (_) {
      item.isChecked = previous;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('완료 상태를 저장하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openCharacter(String name) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GuidePage(
          game: widget.game,
          topic: GuideTopic.build,
          target: name,
          load: widget.load,
          persist: widget.persist,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _customCharacter() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐릭터 이름'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('육성 경로 보기'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    if (name != null && name.isNotEmpty && mounted) await _openCharacter(name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.target.isNotEmpty ? widget.target : widget.topic.label,
      ),
      actions: [
        IconButton(
          tooltip: '출처를 다시 검색하여 새로고침',
          onPressed: loading || saving ? null : () => _load(true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.game.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if ((guide?.progress ?? widget.game.progress).isNotEmpty &&
              widget.topic != GuideTopic.roster)
            Text('확인 구간: ${guide?.progress ?? widget.game.progress}'),
          if ((guide?.contextRules ?? widget.game.rules).isNotEmpty)
            Text('추천 조건: ${guide?.contextRules ?? widget.game.rules}'),
          if (widget.topic == GuideTopic.roster)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: OutlinedButton.icon(
                onPressed: loading ? null : _customCharacter,
                icon: const Icon(Icons.person_search),
                label: const Text('캐릭터 이름 직접 입력'),
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(error!),
                    const SizedBox(height: 8),
                    if (!loading)
                      FilledButton(
                        onPressed: () => _load(false),
                        child: const Text('다시 시도'),
                      ),
                  ],
                ),
              ),
            ),
          if (guide != null) ...[
            const SizedBox(height: 16),
            Text(
              guide!.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(guide!.summary),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '자동 저장됨 · 내 공략집에서 수정 가능${DateTime.tryParse(guide!.createdAt) == null ? '' : ' · ${DateTime.parse(guide!.createdAt).toIso8601String().substring(0, 10)} 확인'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (final entry in guide!.items.asMap().entries)
              Card(
                child: widget.topic == GuideTopic.roster
                    ? ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(entry.value.label),
                        subtitle: Text(
                          [
                            entry.value.value,
                            entry.value.note,
                          ].where((v) => v.isNotEmpty).join('\n'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: loading
                            ? null
                            : () => _openCharacter(entry.value.label),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (guide!.isChecklist)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: entry.value.isChecked,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                onChanged: saving || loading
                                    ? null
                                    : (v) => _toggle(entry.value, v ?? false),
                                title: Text(
                                  entry.value.label,
                                  style: TextStyle(
                                    decoration: entry.value.isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '${widget.topic == GuideTopic.route ? '${entry.key + 1}. ' : ''}${entry.value.label}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            Text(entry.value.value),
                            if (entry.value.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('조건: ${entry.value.note}'),
                              ),
                            GuideDetails(item: entry.value),
                          ],
                        ),
                      ),
              ),
            GuideSources(guide: guide!),
          ],
        ],
      ),
    ),
  );
}
