import 'package:flutter/material.dart';
import '../models/models.dart';

class GuideDetails extends StatelessWidget {
  const GuideDetails({super.key, required this.item, this.includeSteps = true});
  final GuideItem item;
  final bool includeSteps;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (item.reason.isNotEmpty) _line('추천 이유', item.reason),
      if (item.availability.isNotEmpty) _line('입수 시점·조건', item.availability),
      if (item.deadline.isNotEmpty) _line('마감', item.deadline),
      if (includeSteps)
        for (final entry in item.steps.asMap().entries)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.value.label} · ${entry.value.value}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (entry.value.condition.isNotEmpty)
                        Text(entry.value.condition),
                    ],
                  ),
                ),
              ],
            ),
          ),
      if (item.alternatives.isNotEmpty)
        _line('대체 추천', item.alternatives.join(' / ')),
    ],
  );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text('$label: $value'),
  );
}
