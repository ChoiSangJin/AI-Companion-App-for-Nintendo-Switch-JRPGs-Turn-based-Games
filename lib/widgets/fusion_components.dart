import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

Future<List<String>?> editFields(
  BuildContext context, {
  required String title,
  required List<String> labels,
  List<String>? values,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _FieldsDialog(title: title, labels: labels, values: values),
);

class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({required this.title, required this.labels, this.values});
  final String title;
  final List<String> labels;
  final List<String>? values;
  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final controllers = List.generate(
    widget.labels.length,
    (i) => TextEditingController(text: widget.values?[i] ?? ''),
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    controller: controllers[i],
                    autofocus: i == 0,
                    minLines: 1,
                    maxLines: i == 0 ? 2 : 4,
                    maxLength: widget.labels.length == 1
                        ? 2000
                        : i == 0
                        ? 120
                        : 2000,
                    decoration: InputDecoration(labelText: widget.labels[i]),
                    validator: i == 0 && widget.labels.length > 1
                        ? (v) => (v ?? '').trim().isEmpty ? '내용을 입력하세요.' : null
                        : null,
                  ),
                ),
            ],
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
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              controllers.map((c) => c.text.trim()).toList(),
            );
          }
        },
        child: const Text('저장'),
      ),
    ],
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    ) ??
    false;

Future<int?> chooseLevel(
  BuildContext context,
  int initial, {
  String title = '재료 기본 레벨 상한',
  int max = 150,
}) => showDialog<int>(
  context: context,
  builder: (context) {
    var value = initial.clamp(1, max).toDouble();
    return StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lv.${value.round()}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Slider(
              min: 1,
              max: max.toDouble(),
              divisions: max - 1,
              value: value,
              onChanged: (v) => update(() => value = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value.round()),
            child: const Text('적용'),
          ),
        ],
      ),
    );
  },
);
