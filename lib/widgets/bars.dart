import 'package:flutter/material.dart';
import '../format.dart';

String shortMoney(int v) {
  if (v <= 0) return '';
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) {
    return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
  }
  return '$v';
}

/// Histogramme vertical défilable
class SimpleBars extends StatelessWidget {
  const SimpleBars({
    super.key,
    required this.labels,
    required this.values,
    this.color = const Color(0xFFE8801E),
    this.height = 130,
  });
  final List<String> labels;
  final List<int> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(0, (a, b) => b > a ? b : a);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            SizedBox(
              width: 44,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shortMoney(values[i]),
                      style: const TextStyle(fontSize: 10)),
                  const SizedBox(height: 2),
                  Container(
                    width: 24,
                    height: maxV == 0
                        ? 2
                        : (height * values[i] / maxV).clamp(2.0, height).toDouble(),
                    decoration: BoxDecoration(
                      color: values[i] == 0 ? Colors.white24 : color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Barres horizontales (une par ligne)
class HBars extends StatelessWidget {
  const HBars({super.key, required this.items});
  final List<(String, int)> items;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<int>(0, (a, b) => b.$2 > a ? b.$2 : a);
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(it.$1), Text(fcfa(it.$2))],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maxV == 0 ? 0 : it.$2 / maxV,
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
