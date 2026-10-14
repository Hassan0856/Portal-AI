import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import 'glass.dart';

const _levelNames = [
  'Less activity',
  'Moderate activity',
  'High activity',
  'Very high activity'
];

class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.levels});
  final List<List<int>> levels;

  @override
  Widget build(BuildContext context) {
    const labelW = 44.0, gap = 10.0, cellH = 34.0, headH = 20.0, pad = 16.0;
    return LayoutBuilder(builder: (context, c) {
      final avail = c.maxWidth - pad * 2 - labelW;
      final cellW = ((avail - 7 * gap) / 8).clamp(44.0, 90.0);
      final gridW = 8 * cellW + 7 * gap;

      Widget axis(String t, double w, double h) => SizedBox(
          width: w,
          height: h,
          child: Center(
              child: Text(t,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5F739D)))));

      return Container(
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: labelW,
            child: Column(children: [
              const SizedBox(height: headH + gap),
              for (var r = 0; r < heatmapDays.length; r++) ...[
                axis(heatmapDays[r], labelW, cellH),
                if (r < heatmapDays.length - 1) const SizedBox(height: gap),
              ],
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridW,
                child: Column(children: [
                  Row(children: [
                    for (var i = 0; i < heatmapSlots.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      axis(heatmapSlots[i], cellW, headH),
                    ],
                  ]),
                  const SizedBox(height: gap),
                  for (var r = 0; r < levels.length; r++) ...[
                    Row(children: [
                      for (var i = 0; i < levels[r].length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        HeatCell(
                            level: levels[r][i],
                            width: cellW,
                            height: cellH,
                            tip:
                                '${heatmapDays[r]} ${heatmapSlots[i]}: ${_levelNames[levels[r][i]]}'),
                      ],
                    ]),
                    if (r < levels.length - 1) const SizedBox(height: gap),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class HeatCell extends StatelessWidget {
  const HeatCell(
      {super.key,
      required this.level,
      required this.width,
      required this.height,
      required this.tip});
  final int level;
  final double width, height;
  final String tip;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tip,
        triggerMode: TooltipTriggerMode.tap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.heat[level],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: .6)),
          ),
        ),
      );
}

class ActivityLegend extends StatelessWidget {
  const ActivityLegend({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: [
          const Text('Activity intensity',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          for (var i = 0; i < 4; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.heat[i],
                      border: Border.all(color: Colors.white))),
              const SizedBox(width: 8),
              Text(_levelNames[i],
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.secondary)),
            ]),
        ],
      ),
    );
  }
}

class StatisticCard extends StatelessWidget {
  const StatisticCard({super.key, required this.item});
  final StatItem item;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        GlassIconBadge(
            icon: item.icon,
            size: 48,
            color: item.iconColor,
            background: item.badgeColor),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary)),
            Text(item.value,
                style: const TextStyle(
                    fontSize: 29, fontWeight: FontWeight.w700, height: 1.15)),
            Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(item.trend,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: item.positive
                              ? AppColors.success
                              : AppColors.high)),
                  const Text('vs. last week',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.secondary)),
                ]),
          ]),
        ),
      ]),
    );
  }
}

class FilterControl extends StatelessWidget {
  const FilterControl({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.isSet = false,
  });
  final IconData icon;
  final String label, value;
  final bool isSet;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      fill: Colors.white.withValues(alpha: .62),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
      child: SizedBox(
        height: 74,
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: const Color(0xFF6376B5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334B7C))),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSet ? AppColors.primary : AppColors.muted)),
                ]),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6376B5)),
        ]),
      ),
    );
  }
}
