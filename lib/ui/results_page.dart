// lib/ui/results_page.dart
import 'package:flutter/material.dart';
import '../data/config_models.dart';
import '../util/format.dart';

class ResultsPage extends StatelessWidget {
  final Precomputed pre;
  final SimStats stats;
  final Map<String, String> labels;

  const ResultsPage({
    super.key,
    required this.pre,
    required this.stats,
    required this.labels,
  });

  // Target e costanti milestone
  static const int kTargetPoints = 1000000000; // 1B
  static const int kFreeEnergies = 34;
  static const int kPackSize = 40;
  static const int kPackCostGems = 90;

  // Colori richiesti
  static const Color _meanColor = Color(0xFF7E57C2); // purple 400
  static const Color _minColor = Color(0xFF5865F2); // blurple
  static const Color _maxColor = Colors.red; // rosso

  String t(String key, [String? fb]) => labels[key] ?? fb ?? key;
  String tAny(List<String> keys, String fb) {
    for (final k in keys) {
      final v = labels[k];
      if (v != null) return v;
    }
    return fb;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t('report_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(t('setup'), cs.primary),
            const SizedBox(height: 8),
            _setupTable(context),

            const SizedBox(height: 16),
            Text(
              tAny(
                  ['knights_title', 'knights_hdr'], 'Knights (Atk | Def | HP)'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            _knightsTable(context),

            const SizedBox(height: 16),
            Text('${t('points_per_run')} (${t('baseline')})',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            _pointsTable(context), // <— NUOVA TABELLA

            const SizedBox(height: 16),
            Text(t('milestone_title'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            _milestoneTable(context),

            const SizedBox(height: 8),
            Text(
              '${t('note')} '
              '$kFreeEnergies ${t('free')}, '
              '${t('pack').toLowerCase()} = $kPackSize ${t('energies').toLowerCase()}, '
              '${t('cost').toLowerCase()} $kPackCostGems ${t('gems')}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) =>
      Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color));

  // ===== Setup table =====
  Widget _setupTable(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headerStyle = Theme.of(context).textTheme.bodySmall;

    final level = pre.meta.level;
    final mode = pre.meta.raidMode ? t('raid') : t('blitz');
    final atk = fmtDouble(pre.stats.attack);
    final def = fmtDouble(pre.stats.defense);
    final hp = fmtInt(pre.stats.hp);
    final a1 = fmtDouble(pre.meta.advVsKnights[0]);
    final a2 = fmtDouble(pre.meta.advVsKnights[1]);
    final a3 = fmtDouble(pre.meta.advVsKnights[2]);

    Widget modeChip() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            mode,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 28,
            dataRowMinHeight: 32,
            columns: [
              DataColumn(label: Text(t('level'), style: headerStyle)),
              DataColumn(label: Text(t('mode'), style: headerStyle)),
              DataColumn(label: Text(t('attack'), style: headerStyle)),
              DataColumn(label: Text(t('defense'), style: headerStyle)),
              DataColumn(label: Text(t('hp'), style: headerStyle)),
              DataColumn(label: Text(t('boss_vs_k1'), style: headerStyle)),
              DataColumn(label: Text(t('boss_vs_k2'), style: headerStyle)),
              DataColumn(label: Text(t('boss_vs_k3'), style: headerStyle)),
            ],
            rows: [
              DataRow(cells: [
                DataCell(Text('$level')),
                DataCell(modeChip()),
                DataCell(Text(atk)),
                DataCell(Text(def)),
                DataCell(Text(hp)),
                DataCell(Text(a1)),
                DataCell(Text(a2)),
                DataCell(Text(a3)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Knights table =====
  Widget _knightsTable(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.bodySmall;
    final rows = List<DataRow>.generate(3, (i) {
      return DataRow(cells: [
        DataCell(Text('${i + 1}')),
        DataCell(Text(fmtDouble(pre.k_atk[i]))),
        DataCell(Text(fmtDouble(pre.k_def[i]))),
        DataCell(Text(fmtInt(pre.k_hp[i]))),
        DataCell(Text(fmtDouble(pre.k_adv[i]))),
        DataCell(Text(fmtDouble(pre.k_stun[i]))),
        DataCell(Text(fmtInt(pre.k_hitBoss_special[i]))),
        DataCell(Text(fmtInt(pre.incomingNormal[i]))),
        DataCell(Text(fmtInt(pre.incomingCrit[i]))),
      ]);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 28,
            dataRowMinHeight: 28,
            columns: [
              DataColumn(label: Text(t('k'), style: headerStyle)),
              DataColumn(label: Text(t('attack'), style: headerStyle)),
              DataColumn(label: Text(t('defense'), style: headerStyle)),
              DataColumn(label: Text(t('hp'), style: headerStyle)),
              DataColumn(label: Text(t('adv'), style: headerStyle)),
              DataColumn(label: Text(t('stun_chance'), style: headerStyle)),
              DataColumn(
                  label: Text(t('hit_boss_special'), style: headerStyle)),
              DataColumn(label: Text(t('incoming_normal'), style: headerStyle)),
              DataColumn(label: Text(t('incoming_crit'), style: headerStyle)),
            ],
            rows: rows,
          ),
        ),
      ),
    );
  }

  // ===== Points (baseline) table =====
  Widget _pointsTable(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.bodySmall;

    DataRow row(String label, int value, Color color) => DataRow(cells: [
          DataCell(Text(label)),
          DataCell(Text(
            fmtInt(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          )),
        ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 28,
            dataRowMinHeight: 28,
            columns: [
              DataColumn(label: Text(t('stat'), style: headerStyle)),
              DataColumn(label: Text(t('points_run'), style: headerStyle)),
            ],
            rows: [
              row(t('median'), stats.median,
                  Theme.of(context).colorScheme.primary),
              row(t('mean'), stats.mean, _meanColor),
              row(t('min'), stats.min, _minColor),
              row(t('max'), stats.max, _maxColor),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Milestone table =====
  Widget _milestoneTable(BuildContext context) {
    DataRow buildRow(String label, int pointsPerRun) {
      final runs = (kTargetPoints / pointsPerRun).ceil();
      final attacks = runs;
      final extra = (attacks - kFreeEnergies).clamp(0, 1 << 31);
      final packs = (extra / kPackSize).ceil();
      final gems = packs * kPackCostGems;
      final leftovers = (packs * kPackSize) - extra;

      return DataRow(cells: [
        DataCell(Text(label)),
        DataCell(Text(fmtInt(pointsPerRun))),
        DataCell(Text(fmtInt(attacks))),
        DataCell(Text(fmtInt(kFreeEnergies))),
        DataCell(Text(fmtInt(extra))),
        DataCell(Text(fmtInt(packs))),
        DataCell(Text(fmtInt(gems))),
        DataCell(Text(fmtInt(leftovers))),
      ]);
    }

    final headerStyle = Theme.of(context).textTheme.bodySmall;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 28,
            dataRowMinHeight: 28,
            columns: [
              DataColumn(label: Text(t('stat'), style: headerStyle)),
              DataColumn(label: Text(t('points_run'), style: headerStyle)),
              DataColumn(label: Text(t('attacks'), style: headerStyle)),
              DataColumn(label: Text(t('free'), style: headerStyle)),
              DataColumn(label: Text(t('extra'), style: headerStyle)),
              DataColumn(label: Text(t('packs_x40'), style: headerStyle)),
              DataColumn(label: Text(t('gems'), style: headerStyle)),
              DataColumn(label: Text(t('leftovers'), style: headerStyle)),
            ],
            rows: [
              buildRow(t('median'), stats.median),
              buildRow(t('mean'), stats.mean),
            ],
          ),
        ),
      ),
    );
  }
}
