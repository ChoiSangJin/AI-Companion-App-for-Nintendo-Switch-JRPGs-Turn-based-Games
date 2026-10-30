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

Color typeColor(String type) => switch (type) {
  '불꽃' => const Color(0xFFAE4333),
  '물' => const Color(0xFF27679A),
  '풀' => const Color(0xFF427B43),
  '전기' => const Color(0xFF8A6900),
  '페어리' => const Color(0xFFA0447B),
  '강철' => const Color(0xFF526C78),
  '땅' => const Color(0xFF866339),
  '비행' => const Color(0xFF5D689C),
  '고스트' => const Color(0xFF70508B),
  '격투' => const Color(0xFF8B4936),
  '악' => const Color(0xFF525164),
  '드래곤' => const Color(0xFF5848A0),
  _ => const Color(0xFF5B6868),
};
Widget typeTags(List<String> types) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: types
      .map(
        (type) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor(type).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            type,
            style: TextStyle(
              color: typeColor(type),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      )
      .toList(),
);

class Monogram extends StatelessWidget {
  const Monogram(this.name, this.type, {super.key, this.size = 48});
  final String name, type;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: typeColor(type).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      name.substring(0, 1),
      style: TextStyle(
        fontSize: size * 0.43,
        color: typeColor(type),
        fontWeight: FontWeight.w900,
      ),
    ),
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
