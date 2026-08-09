import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/recent_activity_entry.dart';
import 'home_skeletons.dart';
import '../../../../core/theme/shape_tokens.dart';

class RecentActivitySection extends StatefulWidget {
  const RecentActivitySection({
    super.key,
    required this.activity,
    required this.hasError,
    required this.loading,
    required this.onRetry,
  });

  final List<RecentActivityEntry> activity;
  final bool hasError;
  final bool loading;
  final VoidCallback onRetry;

  @override
  State<RecentActivitySection> createState() => _RecentActivitySectionState();
}

/// Ticks the relative-time labels ("Just now" / "5m ago") on the same coarse
/// timer pattern as `GreetingText` — previously computed once per build and
/// never re-evaluated, so an entry would say "Just now" forever until some
/// unrelated rebuild happened to occur.
class _RecentActivitySectionState extends State<RecentActivitySection> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.loading) {
      return Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: SkeletonBlock(
              height: 50,
              radius: groupedItemRadius(index: i, count: 3, outer: 14),
            ),
          ),
        ),
      );
    }
    if (widget.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't load recent activity.",
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: widget.onRetry,
            child: const Text('Try again'),
          ),
        ],
      );
    }
    if (widget.activity.isEmpty) {
      return Text(
        'No activity yet — dismiss an alarm or capture territory.',
        style: TextStyle(fontSize: 12, color: secondaryLabelColor(context)),
      );
    }
    return Column(
      children: List.generate(widget.activity.length, (i) {
        final a = widget.activity[i];
        final icon = a.kind == RecentActivityKind.alarmDismissed
            ? Icons.check_circle_outline
            : Icons.landscape_outlined;
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: AppleGlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: groupedItemRadius(
              index: i,
              count: widget.activity.length,
              outer: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: ShapeTokens.r8,
                  ),
                  child: Icon(icon, size: 16, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  _relativeTime(a.occurredAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryLabelColor(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
