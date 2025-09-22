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

  String t(String k, String fallback) => labels[k] ?? fallback;

  // ===== Piano gemme (ceil) =====
  static const int _targetPoints = 1000000000; // 1B
  static const int _freeEnergies = 34;
  static const int _packSize = 40;
  static const int _packCost = 90;

  static ({int runs, int extra, int packs, int gems, int leftover}) _plan({
    required int target,
    required num perRun,
    int free = _freeEnergies,
    int packSize = _packSize,
    int packCost = _packCost,
  }) {
    if (perRun <= 0) return (runs: 0, extra: 0, packs: 0, gems: 0, leftover: 0);
    final runs = (target / perRun).ceil(); // attacchi totali
    final extra = (runs - free) > 0 ? (runs - free) : 0; // da comprare
    final packs = extra > 0 ? (extra / packSize).ceil() : 0; // pacchi×40
    final gems = packs * packCost; // gemme
    final leftover = (free + packs * packSize) - runs; // residui
    return (
      runs: runs,
      extra: extra,
      packs: packs,
      gems: gems,
      leftover: leftover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final raidTxt = pre.meta.raidMode ? 'Raid' : 'Blitz';
    final adv = pre.meta.advVsKnights.map((e) => fmtDouble(e)).join(', ');

    final pMed = _plan(target: _targetPoints, perRun: stats.median);
    final pMean = _plan(target: _targetPoints, perRun: stats.mean);

    return Scaffold(
      appBar: AppBar(title: Text(t('report_title', 'Report simulazione'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Setup =====
          Text(
            '== == Setup == ==',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _kv('Boss', '${t('level', 'Level')} ${pre.meta.level} | $raidTxt'),
          _kv(
            'Boss Stats',
            '${t('attack', 'Attack')} ${fmtDouble(pre.stats.attack)} | '
                '${t('defense', 'Defense')} ${fmtDouble(pre.stats.defense)} | '
                'HP ${fmtInt(pre.stats.hp)}',
          ),
          _kv('Boss Advantage vs Knights', adv),
          _kv('[Debug] Multiplier', fmtDouble(pre.multiplierM)),
          const Divider(height: 24),

          // ===== Knights table =====
          Text(
            t('knights_title', 'Knights (Atk | Def | HP)'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _knightsTable(context),

          const Divider(height: 24),

          // ===== Punti per run =====
          Text(
            t('points_per_run', 'Punti/run') + ' ([Punti per run (baseline)])',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'median=${fmtInt(stats.median)}   '
            'mean=${fmtInt(stats.mean)}   '
            'min=${fmtInt(stats.min)}   '
            'max=${fmtInt(stats.max)}',
          ),

          const SizedBox(height: 16),

          // ===== Milestone / Gemme =====
          Text(
            '${t('milestone_title', 'Milestone — Stima gemme')}  (${fmtInt(_targetPoints)} pts)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _gemTable(
            context,
            rows: [
              _gemRow('median', stats.median, pMed),
              _gemRow('mean', stats.mean, pMean),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Note: ${fmtInt(_freeEnergies)} ${t('free', 'Free')}, '
            '${t('pack', 'pacco')} = $_packSize ${t('energies', 'energie')}, '
            '${t('cost', 'costo')} $_packCost ${t('gems', 'Gemme')}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ===== Knights table =====
  Widget _knightsTable(BuildContext context) {
    final th = Theme.of(context);
    final head = th.textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600);
    final body = th.textTheme.bodySmall;
    Center h(String s) => Center(
      child: Text(s, style: head, textAlign: TextAlign.center),
    );

    final columns = [
      DataColumn(label: h(t('k', 'K'))),
      DataColumn(label: h(t('attack', 'Attack'))),
      DataColumn(label: h(t('defense', 'Defense'))),
      DataColumn(label: h(t('hp', 'HP'))),
      DataColumn(label: h(t('adv', 'Adv'))),
      DataColumn(label: h(t('stun_chance', 'Stun'))),
      DataColumn(label: h(t('damage_dealt', 'Dmg→Boss (special)'))),
      DataColumn(label: h(t('incoming_damage', 'Incoming (norm/crit)'))),
    ];

    Center c(String s) => Center(child: Text(s, style: body));

    final rows = List<DataRow>.generate(3, (i) {
      final n = i + 1;
      final atk = fmtDouble(pre.k_atk[i]);
      final def = fmtDouble(pre.k_def[i]);
      final hp = fmtInt(pre.k_hp[i]);
      final adv = fmtDouble(pre.k_adv[i]);
      final stn = fmtDouble(pre.k_stun[i]);
      final hit = fmtInt(pre.k_hitBoss_special[i]);
      final inc =
          '${fmtInt(pre.incomingNormal[i])}/${fmtInt(pre.incomingCrit[i])}';
      return DataRow(
        cells: [
          DataCell(c('$n')),
          DataCell(c(atk)),
          DataCell(c(def)),
          DataCell(c(hp)),
          DataCell(c(adv)),
          DataCell(c(stn)),
          DataCell(c(hit)),
          DataCell(c(inc)),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: rows,
          columnSpacing: 22,
          horizontalMargin: 12,
          dividerThickness: 0.7,
        ),
      ),
    );
  }

  // ===== Gem table =====
  Map<String, String> _gemRow(
    String statName,
    int perRun,
    ({int runs, int extra, int packs, int gems, int leftover}) p,
  ) {
    return {
      'stat': statName,
      'points': fmtInt(perRun),
      'runs': fmtInt(p.runs),
      'free': fmtInt(_freeEnergies),
      'extra': fmtInt(p.extra),
      'packs': fmtInt(p.packs), // ceil( (runs - free) / 40 )
      'gems': fmtInt(p.gems),
      'left': fmtInt(p.leftover),
    };
  }

  Widget _gemTable(
    BuildContext context, {
    required List<Map<String, String>> rows,
  }) {
    final theme = Theme.of(context);
    final headingStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final dataStyle = theme.textTheme.bodySmall;
    Center h(String s) => Center(
      child: Text(s, style: headingStyle, textAlign: TextAlign.center),
    );
    Center c(String s) => Center(child: Text(s, style: dataStyle));

    final columns = [
      DataColumn(label: h(t('stat', 'Stat'))),
      DataColumn(label: h(t('points_run', 'Punti/run'))),
      DataColumn(label: h(t('attacks', 'Attacchi'))),
      DataColumn(label: h(t('free', 'Free'))),
      DataColumn(label: h(t('extra', 'Extra'))),
      DataColumn(label: h(t('packs_x40', 'Pacchi×40'))),
      DataColumn(label: h(t('gems', 'Gemme'))),
      DataColumn(label: h(t('leftovers', 'Residui'))),
    ];

    final dataRows = rows
        .map(
          (r) => DataRow(
            cells: [
              DataCell(c(r['stat']!)),
              DataCell(c(r['points']!)),
              DataCell(c(r['runs']!)),
              DataCell(c(r['free']!)),
              DataCell(c(r['extra']!)),
              DataCell(c(r['packs']!)),
              DataCell(c(r['gems']!)),
              DataCell(c(r['left']!)),
            ],
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: dataRows,
          columnSpacing: 22,
          horizontalMargin: 12,
          dividerThickness: 0.7,
        ),
      ),
    );
  }

  // ===== simple key-value row =====
  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    );
  }
}
