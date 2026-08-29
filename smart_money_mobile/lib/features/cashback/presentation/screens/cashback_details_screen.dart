import 'package:flutter/material.dart';

import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/cashback_item.dart';
import '../cashback_status_copy.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

enum _StepState { done, current, upcoming, negative }

class _TimelineStep {
  const _TimelineStep({required this.label, required this.state, this.date});

  final String label;
  final _StepState state;
  final DateTime? date;
}

/// Cashback tracking detail for a single record — no network call, since the
/// list screen already holds the full [CashbackItem].
class CashbackDetailsScreen extends StatelessWidget {
  const CashbackDetailsScreen({super.key, required this.item});

  final CashbackItem item;

  List<_TimelineStep> _buildSteps() {
    switch (item.status) {
      case CashbackStatus.pending:
        return [
          _TimelineStep(
            label: 'Order tracked',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback pending',
            state: _StepState.current,
            date: item.createdAt,
          ),
          const _TimelineStep(
            label: 'Cashback confirmed',
            state: _StepState.upcoming,
          ),
          const _TimelineStep(label: 'Withdrawn', state: _StepState.upcoming),
        ];
      case CashbackStatus.awaitingAdminReview:
        return [
          _TimelineStep(
            label: 'Order tracked',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback pending',
            state: _StepState.done,
            date: item.createdAt,
          ),
          const _TimelineStep(label: 'Under review', state: _StepState.current),
          const _TimelineStep(label: 'Withdrawn', state: _StepState.upcoming),
        ];
      case CashbackStatus.confirmed:
        return [
          _TimelineStep(
            label: 'Order tracked',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback pending',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback confirmed',
            state: _StepState.done,
            date: item.confirmedDate,
          ),
          const _TimelineStep(label: 'Withdrawn', state: _StepState.upcoming),
        ];
      case CashbackStatus.paidOut:
        return [
          _TimelineStep(
            label: 'Order tracked',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback pending',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback confirmed',
            state: _StepState.done,
            date: item.confirmedDate,
          ),
          const _TimelineStep(label: 'Withdrawn', state: _StepState.done),
        ];
      case CashbackStatus.rejected:
        return [
          _TimelineStep(
            label: 'Order tracked',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback pending',
            state: _StepState.done,
            date: item.createdAt,
          ),
          const _TimelineStep(label: 'Not approved', state: _StepState.negative),
        ];
      case CashbackStatus.reversed:
        return [
          _TimelineStep(
            label: 'Order tracked',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback pending',
            state: _StepState.done,
            date: item.createdAt,
          ),
          _TimelineStep(
            label: 'Cashback confirmed',
            state: _StepState.done,
            date: item.confirmedDate,
          ),
          const _TimelineStep(label: 'Reversed', state: _StepState.negative),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final isPositive =
        item.status == CashbackStatus.confirmed ||
        item.status == CashbackStatus.paidOut;

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(title: const Text('Cashback Details')),
      body: SafeArea(
        top: false,
        child: FadeSlideIn(
          child: ListView(
            padding: const EdgeInsets.all(SmSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(SmSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(SmRadius.cardLarge),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.storeName ?? 'Store',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: cashbackStatusLabel(item.status),
                          tone: cashbackStatusTone(item.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: SmSpacing.sm),
                    Text(
                      '₹${item.cashbackAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isPositive ? colors.success : colors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cashback',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SmSpacing.lg),
              Container(
                padding: const EdgeInsets.all(SmSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(SmRadius.cardLarge),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking timeline',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SmSpacing.lg),
                    _Timeline(steps: _buildSteps(), colors: colors),
                  ],
                ),
              ),
              const SizedBox(height: SmSpacing.lg),
              Container(
                padding: const EdgeInsets.all(SmSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(SmRadius.cardLarge),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order details',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: SmSpacing.md),
                    _DetailRow(
                      label: 'Shopping date',
                      value: _formatDate(item.createdAt),
                      colors: colors,
                    ),
                    _DetailRow(
                      label: 'Expected confirmation',
                      value: _formatDate(item.expectedConfirmationDate),
                      colors: colors,
                    ),
                    if (item.confirmedDate != null)
                      _DetailRow(
                        label: 'Confirmed on',
                        value: _formatDate(item.confirmedDate!),
                        colors: colors,
                        isLast: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps, required this.colors});

  final List<_TimelineStep> steps;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            colors: colors,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.colors,
  });

  final _TimelineStep step;
  final bool isLast;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final Widget dotChild;
    switch (step.state) {
      case _StepState.done:
        dotColor = colors.success;
        dotChild = const Icon(Icons.check_rounded, color: Colors.white, size: 14);
      case _StepState.current:
        dotColor = colors.warning;
        dotChild = const SizedBox.shrink();
      case _StepState.negative:
        dotColor = colors.danger;
        dotChild = const Icon(Icons.close_rounded, color: Colors.white, size: 14);
      case _StepState.upcoming:
        dotColor = colors.border;
        dotChild = const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                child: dotChild,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: colors.border),
                ),
            ],
          ),
          const SizedBox(width: SmSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: SmSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      color: step.state == _StepState.upcoming
                          ? colors.textMuted
                          : colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(step.date!),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.colors,
    this.isLast = false,
  });

  final String label;
  final String value;
  final SmColors colors;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : SmSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
