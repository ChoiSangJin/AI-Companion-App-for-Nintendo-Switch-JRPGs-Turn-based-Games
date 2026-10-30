import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/pinned_goal.dart';
import '../services/storage.dart';
import 'guide_details.dart';
import 'guide_sources.dart';

Future<bool> confirmUnpin(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('목표 고정을 해제할까요?'),
        content: const Text('이 목표의 진행 기록과 메모를 삭제합니다. 원본 공략은 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('고정 해제'),
          ),
        ],
      ),
    ) ??
    false;

class GoalBoard extends StatefulWidget {
  const GoalBoard({
    super.key,
    required this.store,
    required this.game,
    required this.onChanged,
  });
  final LocalStore store;
  final GameProfile game;
  final VoidCallback onChanged;
  @override
  State<GoalBoard> createState() => _GoalBoardState();
}

class _GoalBoardState extends State<GoalBoard> {
  final Set<String> busy = {};
  bool adding = false;
  Future<void> _change(PinnedGoal next) async {
    if (busy.contains(next.id)) return;
    setState(() => busy.add(next.id));
    try {
      await widget.store.updateGoal(next);
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목표 진행을 저장하지 못했습니다. 다시 시도하세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy.remove(next.id));
    }
  }

  Future<void> _open(PinnedGoal goal) async {
    if (busy.contains(goal.id)) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GoalDetailPage(store: widget.store, goalId: goal.id),
      ),
    );
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  Future<void> _add() async {
    if (adding) return;
    final inputs = List.generate(3, (_) => TextEditingController());
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('직접 목표 추가'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: inputs[i],
                    maxLength: i == 0 ? 80 : 1000,
                    minLines: 1,
                    maxLines: i == 0 ? 2 : 4,
                    decoration: InputDecoration(
                      labelText: ['목표 이름', '내가 할 일', '메모 (선택)'][i],
                    ),
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
            onPressed: () {
              if (inputs[0].text.trim().isEmpty ||
                  inputs[1].text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('목표 이름과 할 일을 입력하세요.')),
                );
                return;
              }
              Navigator.pop(context, inputs.map((c) => c.text.trim()).toList());
            },
            child: const Text('목표 추가'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in inputs) {
      c.dispose();
    }
    if (values == null || !mounted) return;
    setState(() => adding = true);
    try {
      await widget.store.addManualGoal(
        widget.game,
        values[0],
        values[1],
        values[2],
      );
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('목표를 저장하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.store.goals
        .where((g) => g.gameId == widget.game.id)
        .toList();
    final active = all.where((g) => !g.isComplete).toList();
    final complete = all.where((g) => g.isComplete).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '내 목표 현황판',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            TextButton.icon(
              onPressed: adding ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('직접 추가'),
            ),
          ],
        ),
        Text('진행 중 ${active.length}개 · 완료 ${complete.length}개'),
        const SizedBox(height: 12),
        if (all.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '공략에서 필요한 캐릭터·포켓몬·할 일을 내 목표에 고정하세요. 다음 단계와 조건을 여기서 바로 확인할 수 있습니다.',
              ),
            ),
          ),
        if (active.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 340
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: active
                    .map((g) => SizedBox(width: width, child: _card(g)))
                    .toList(),
              );
            },
          ),
        if (complete.isNotEmpty)
          ExpansionTile(
            key: PageStorageKey('completed-${widget.game.id}'),
            title: Text('완료한 목표 (${complete.length})'),
            children: complete.map(_card).toList(),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(PinnedGoal goal) {
    final next = goal.nextStepIndex;
    return Card(
      key: ValueKey('goal-${goal.id}'),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: busy.contains(goal.id) ? null : () => _open(goal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                goal.item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (goal.guide.progress.isNotEmpty)
                Text(
                  '구간: ${goal.guide.progress}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (goal.hasSteps) ...[
                const SizedBox(height: 10),
                Text(
                  '육성 ${goal.completedCount}/${goal.completedSteps.length}단계',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (next >= 0) ...[
                  Text(
                    '다음: ${goal.item.steps[next].value}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (goal.item.steps[next].condition.isNotEmpty)
                    Text(
                      goal.item.steps[next].condition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy.contains(goal.id)
                          ? null
                          : () => _change(goal.setStep(next, true)),
                      child: const Text('이 단계 완료'),
                    ),
                  ),
                ] else
                  const Text('모든 육성 단계 완료'),
              ] else ...[
                if (goal.item.availability.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '입수: ${goal.item.availability}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (goal.item.deadline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '마감: ${goal.item.deadline}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('목표 완료'),
                  value: goal.done,
                  onChanged: busy.contains(goal.id)
                      ? null
                      : (v) => _change(goal.copyWith(done: v ?? false)),
                ),
              ],
              if (goal.memo.isNotEmpty)
                Text(
                  '메모: ${goal.memo}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({super.key, required this.store, required this.goalId});
  final LocalStore store;
  final String goalId;
  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  bool busy = false;
  PinnedGoal? get goal =>
      widget.store.goals.where((g) => g.id == widget.goalId).firstOrNull;
  Future<void> _save(PinnedGoal next) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.store.updateGoal(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('변경 사항을 저장하지 못했습니다.')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit() async {
    final current = goal;
    if (current == null) return;
    final title = TextEditingController(text: current.title),
        memo = TextEditingController(text: current.memo),
        action = TextEditingController(text: current.item.value);
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 목표 편집'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '목표 이름'),
              ),
              if (current.manual)
                TextField(
                  controller: action,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: '내가 할 일'),
                ),
              TextField(
                controller: memo,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: '내 메모'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isNotEmpty &&
                  (!current.manual || action.text.trim().isNotEmpty)) {
                Navigator.pop(context, [
                  title.text.trim(),
                  memo.text.trim(),
                  action.text.trim(),
                ]);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    title.dispose();
    memo.dispose();
    action.dispose();
    if (values != null && mounted) {
      final updatedGuide = current.manual
          ? GuideData.fromJson({
              ...current.guide.toJson(),
              'title': values[0],
              'items': [
                {
                  ...current.item.toJson(),
                  'label': values[0],
                  'value': values[2],
                },
              ],
            })
          : current.guide;
      await _save(
        current.copyWith(
          title: values[0],
          memo: values[1],
          guide: updatedGuide,
        ),
      );
    }
  }

  Future<void> _unpin() async {
    if (!await confirmUnpin(context) || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.removeGoal(widget.goalId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('목표 고정을 해제하지 못했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = goal;
    if (current == null) {
      return const Scaffold(body: Center(child: Text('고정이 해제된 목표입니다.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        actions: [
          IconButton(
            tooltip: '목표 이름·메모 편집',
            onPressed: busy ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '목표 고정 해제',
            onPressed: busy ? null : _unpin,
            icon: const Icon(Icons.push_pin),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              current.item.value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (current.guide.progress.isNotEmpty)
              Text('저장한 구간: ${current.guide.progress}'),
            if (current.guide.contextRules.isNotEmpty)
              Text('추천 조건: ${current.guide.contextRules}'),
            if (current.memo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('내 메모: ${current.memo}'),
              ),
            if (current.hasSteps) ...[
              const SizedBox(height: 16),
              Text(
                '육성 단계 · ${current.completedCount}/${current.completedSteps.length} 완료',
              ),
              for (final entry in current.item.steps.asMap().entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: current.completedSteps[entry.key],
                  onChanged: busy
                      ? null
                      : (v) => _save(current.setStep(entry.key, v ?? false)),
                  title: Text(
                    '${entry.key + 1}. ${entry.value.label} · ${entry.value.value}',
                  ),
                  subtitle: entry.value.condition.isEmpty
                      ? null
                      : Text(entry.value.condition),
                ),
            ] else
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: current.done,
                title: const Text('목표 완료'),
                onChanged: busy
                    ? null
                    : (v) => _save(current.copyWith(done: v ?? false)),
              ),
            if (current.item.note.isNotEmpty) Text('조건: ${current.item.note}'),
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(current.manual ? '직접 작성한 내용' : '고정한 공략·출처'),
              childrenPadding: const EdgeInsets.all(12),
              children: [
                if (!current.manual)
                  const Text(
                    '고정 시점의 공략입니다. 원본 공략을 수정·새로고침해도 목표의 진행 기록은 유지됩니다.',
                  ),
                GuideDetails(item: current.item, includeSteps: false),
                GuideSources(guide: current.guide),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
