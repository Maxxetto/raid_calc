// lib/ui/epic_results_page.dart
//
// Epic Boss results: summary + success table.

import 'package:flutter/material.dart';

import '../core/sim_types.dart';
import '../util/format.dart';
import 'table_widgets.dart';
import 'theme_helpers.dart';

class EpicKnightRow {
  final String id;
  final int atk;
  final int def;
  final int hp;
  final double adv;
  final double stun;

  const EpicKnightRow({
    required this.id,
    required this.atk,
    required this.def,
    required this.hp,
    required this.adv,
    required this.stun,
  });
}

class EpicLevelRow {
  final int level;
  final bool missing;
  final List<double?> winRates; // index 0 => 1 knight

  const EpicLevelRow({
    required this.level,
    required this.missing,
    required this.winRates,
  });
}

class EpicResultsPage extends StatelessWidget {
  final List<EpicKnightRow> knights;
  final List<EpicLevelRow> levels;
  final Map<String, String> labels;
  final int threshold;
  final double epicBonusPerExtraPct;
  final double epicEffectiveBonusPct;
  final bool isPremium;
  final bool debugEnabled;
  final FightMode fightMode;
  final bool cycloneUseGemsForSpecials;

  const EpicResultsPage({
    super.key,
    required this.knights,
    required this.levels,
    required this.labels,
    required this.threshold,
    required this.epicBonusPerExtraPct,
    required this.epicEffectiveBonusPct,
    required this.isPremium,
    required this.debugEnabled,
    required this.fightMode,
    this.cycloneUseGemsForSpecials = true,
  });

  String t(String k, String fb) => labels[k] ?? fb;

  String _fmtAdv(double v) => v.toStringAsFixed(1);

  String _modeLabel() {
    final key = switch (fightMode) {
      FightMode.normal => 'mode.normal',
      FightMode.specialRegen => 'mode.special_regeneration',
      FightMode.specialRegenPlusEw => 'mode.sr_ew',
      FightMode.shatterShield => 'mode.shatter_shield',
      FightMode.cycloneBoost => 'mode.cyclone_boost',
      FightMode.durableRockShield => 'mode.durable_rock_shield',
      FightMode.specialRegenEw => 'mode.old_simulator',
    };
    return t(key, fightMode.dropdownLabel());
  }

  String _summaryLine() {
    final parts = <String>[];
    parts.add('${t('epic', 'Epic')} ${t('boss', 'Boss')}');
    if (isPremium) parts.add(t('premium.title', 'Premium'));
    if (debugEnabled) parts.add(t('debug.title', 'Debug'));
    parts.add(_modeLabel());
    return parts.join(' | ');
  }

  int get _maxSuccessColumns {
    var maxCols = knights.length;
    for (final level in levels) {
      if (level.winRates.length > maxCols) {
        maxCols = level.winRates.length;
      }
    }
    return maxCols.clamp(1, 5).toInt();
  }

  String _successColumnLabel(int index) {
    final prefix = t('epic.success_prefix', 'Success');
    final ids = knights.take(index + 1).map((k) => k.id).join('+');
    if (ids.isEmpty) {
      return '$prefix ${index + 1}';
    }
    return '$prefix $ids';
  }

  Widget _levelsTable(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = themedLabelColor(theme);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: labelColor,
    );
    final cellStyle = theme.textTheme.bodySmall;
    const levelWidth = 48.0;
    const successWidth = 120.0;
    final missingText = t(
      'epic.level_missing',
      'Level data not available, please submit statistics.',
    );

    String fmtRate(double? v) {
      if (v == null) return '';
      return (v * 100).toStringAsFixed(0) + '%';
    }

    final hasMissing = levels.any((e) => e.missing);
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
    );

    final successColumns = _maxSuccessColumns;
    final columns = <TableHeaderCell>[
      TableHeaderCell(
        text: t('level', 'Level'),
        width: levelWidth,
        style: headerStyle,
      ),
      for (int i = 0; i < successColumns; i++)
        TableHeaderCell(
          text: _successColumnLabel(i),
          width: successWidth,
          style: headerStyle,
        ),
    ];

    List<TableValueCell> buildCells(EpicLevelRow row) {
      final cells = <TableValueCell>[
        TableValueCell(
          text: row.level.toString(),
          width: levelWidth,
          style: cellStyle,
        ),
      ];
      for (int i = 0; i < successColumns; i++) {
        final text = row.missing
            ? 'N/A*'
            : fmtRate((i < row.winRates.length) ? row.winRates[i] : null);
        cells.add(
          TableValueCell(
            text: text,
            width: successWidth,
            style: cellStyle,
          ),
        );
      }
      return cells;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMissing) Text('*$missingText', style: noteStyle),
        if (hasMissing) const SizedBox(height: 6),
        ThemedDataTable(
          columnSpacing: 10,
          horizontalMargin: 6,
          headingRowHeight: 34,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 42,
          columns: columns,
          rows: [for (final row in levels) buildCells(row)],
        ),
        if (hasMissing) const SizedBox(height: 6),
        if (hasMissing) Text('*$missingText', style: noteStyle),
      ],
    );
  }

  Widget _knightsTable(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: themedLabelColor(theme),
    );

    return ThemedDataTable(
      columns: [
        TableHeaderCell(text: t('knight', 'Knight'), style: headerStyle),
        TableHeaderCell(text: t('atk', 'ATK'), style: headerStyle),
        TableHeaderCell(text: t('def', 'DEF'), style: headerStyle),
        TableHeaderCell(text: t('hp', 'HP'), style: headerStyle),
        TableHeaderCell(text: t('advantage', 'Advantage'), style: headerStyle),
        TableHeaderCell(text: t('stun_chance', 'STUN %'), style: headerStyle),
      ],
      rows: [
        for (final k in knights)
          [
            TableValueCell(text: k.id),
            TableValueCell(text: fmtInt(k.atk)),
            TableValueCell(text: fmtInt(k.def)),
            TableValueCell(text: fmtInt(k.hp)),
            TableValueCell(text: _fmtAdv(k.adv)),
            TableValueCell(text: fmtPct(k.stun, decimals: 0)),
          ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${t('report_title', 'Simulation Report')} - ${t('epic', 'Epic')}';
    final thresholdLabel = t('epic.threshold', 'Epic success threshold');
    final bonusLabel = t('epic.bonus_label', 'Epic bonus');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Center(
            child: Text(
              _summaryLine(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: t('knights_section', 'Valori Cavalieri'),
            child: _knightsTable(context),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('epic', 'Epic'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$thresholdLabel: $threshold%'),
                const SizedBox(height: 6),
                Text(
                  '$bonusLabel: +${epicEffectiveBonusPct.toStringAsFixed(1)}% '
                  '(${epicBonusPerExtraPct.toStringAsFixed(1)}% ${t('epic.bonus_per_extra', 'per extra active knight')})',
                ),
                const SizedBox(height: 12),
                _levelsTable(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
