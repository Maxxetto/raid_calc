// lib/ui/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../core/damage_model.dart';
import '../data/config_loader.dart';
import '../data/config_models.dart';

import '../util/format.dart';
import '../util/i18n.dart';
import 'results_page.dart';

import 'ui_consts.dart';
import 'widgets/mode_toggle.dart';
import 'widgets/boss_level_dropdown.dart';
import '../util/ad_helper.dart';

// Consente di scrivere _lang['chiave'] come alias di _lang.t('chiave')
extension I18nIndexing on I18n {
  String operator [](String key) => t(key);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // I18n
  I18n _lang = const I18n('it', {});
  Map<String, String> get L => _lang.map;
  Future<void> _loadLang(String code) async {
    final next = await I18n.fromAssets(code);
    if (mounted) setState(() => _lang = next);
  }

  // Stato/Input
  bool _isRaid = true;
  bool _specialRegen = true; // solo UI/telemetria
  final _runsCtrl = TextEditingController(text: '50000');
  int _bossLevel = 7;

  // Boss advantage vs Knights
  double _bossAdvK1 = 1.0, _bossAdvK2 = 1.0, _bossAdvK3 = 1.0;

  // Knights
  final List<TextEditingController> _kAtk =
      List.generate(3, (_) => TextEditingController(text: '0'));
  final List<TextEditingController> _kDef =
      List.generate(3, (_) => TextEditingController(text: '0'));
  final List<TextEditingController> _kHp =
      List.generate(3, (_) => TextEditingController(text: '0'));
  final List<double> _kAdvVal = [1.0, 1.0, 1.0];
  final List<TextEditingController> _kStun =
      List.generate(3, (_) => TextEditingController(text: '0.0'));

  bool _running = false;
  int _done = 0, _total = 1;

  @override
  void initState() {
    super.initState();
    _loadLang('it');

    // Ads (safe): se fallisce, le ads si spengono e si va avanti
    AdHelper.bootstrap(enableAds: false);
  }

  @override
  void dispose() {
    _runsCtrl.dispose();
    for (final c in [..._kAtk, ..._kDef, ..._kHp, ..._kStun]) {
      c.dispose();
    }
    AdHelper.dispose();
    super.dispose();
  }

  double _toD(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
  int _toI(TextEditingController c) => int.tryParse(c.text) ?? 0;

  Future<void> _runSimulation() async {
    setState(() {
      _running = true;
      _done = 0;
      _total = 1;
    });

    final knights = List<KnightInput>.generate(
      3,
      (i) => KnightInput(
        atk: _toD(_kAtk[i]),
        def: _toD(_kDef[i]),
        hp: _toI(_kHp[i]),
        adv: _kAdvVal[i],
        stun: _toD(_kStun[i]),
      ),
    );

    final loaded = await ConfigLoader.loadBossFromAssets(
      raidMode: _isRaid,
      bossLevel: _bossLevel,
      overrideBossAdv: [_bossAdvK1, _bossAdvK2, _bossAdvK3],
    );

    final boss = BossConfig(
      stats: loaded.stats,
      meta: loaded.meta,
      multiplierM: loaded.multiplierM,
    );

    const model = DamageModel();

    // NIENTE specialRegenOn: il motore ha lo Special sempre ON
    final pre = model.precompute(boss: boss, input: knights);

    final runs = _toI(_runsCtrl);

    final stats = await model.simulate(
      pre,
      runs: runs,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );

    if (!mounted) return;
    setState(() => _running = false);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultsPage(pre: pre, stats: stats, labels: L),
    ));
  }

  void _onSimulatePressed() {
    if (_running) return;
    AdHelper.tryShow(); // non blocca
    _runSimulation();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang['app_title'] ?? 'Raid Calc (Safe)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _lang.code,
                items: I18n.supported
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(I18n.nativeName(code)),
                        ))
                    .toList(),
                onChanged: (code) => code != null ? _loadLang(code) : null,
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _expandCard(
                title: L['runs'] ?? 'Runs',
                child: TextField(
                  controller: _runsCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: UI.gap),
              _expandCard(
                title: L['boss_level'] ?? 'Boss Level',
                child: BossLevelDropdown(
                  isRaid: _isRaid,
                  value: _bossLevel,
                  onChanged: (v) => setState(() => _bossLevel = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: UI.gap),
          LayoutBuilder(builder: (ctx, cons) {
            final w = cons.maxWidth;
            final bossAdvMin = (UI.bossAdvItemW * 3) + (8 * 2) + (12 * 2) + 120;
            final need = UI.smallCardW * 2 + UI.gap * 2 + bossAdvMin;
            if (w >= need) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fixedCard(
                    width: UI.smallCardW,
                    title: L['mode'] ?? 'mode',
                    child: ModeToggleButton(
                      isRaid: _isRaid,
                      raidLabel: L['raid'] ?? 'Raid',
                      blitzLabel: L['blitz'] ?? 'Blitz',
                      onToggle: () {
                        setState(() {
                          _isRaid = !_isRaid;
                          final max = _isRaid ? 7 : 6;
                          if (_bossLevel > max) _bossLevel = max;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: UI.gap),
                  _fixedCard(
                    width: UI.smallCardW,
                    title: L['special_regen'] ?? 'Regen. speciale',
                    child: Switch(
                      value: _specialRegen,
                      onChanged: (v) => setState(() => _specialRegen = v),
                    ),
                  ),
                  const SizedBox(width: UI.gap),
                  Expanded(
                    child: _boxed(
                      title: L['boss_adv_vs_knights'] ??
                          'Boss Advantage vs Knights',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _bossAdvDropdown(_bossAdvK1,
                              (v) => setState(() => _bossAdvK1 = v)),
                          _bossAdvDropdown(_bossAdvK2,
                              (v) => setState(() => _bossAdvK2 = v)),
                          _bossAdvDropdown(_bossAdvK3,
                              (v) => setState(() => _bossAdvK3 = v)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return Wrap(
              spacing: UI.gap,
              runSpacing: UI.gap,
              children: [
                _fixedCard(
                  width: UI.smallCardW,
                  title: L['mode'] ?? 'mode',
                  child: ModeToggleButton(
                    isRaid: _isRaid,
                    raidLabel: L['raid'] ?? 'Raid',
                    blitzLabel: L['blitz'] ?? 'Blitz',
                    onToggle: () {
                      setState(() {
                        _isRaid = !_isRaid;
                        final max = _isRaid ? 7 : 6;
                        if (_bossLevel > max) _bossLevel = max;
                      });
                    },
                  ),
                ),
                _fixedCard(
                  width: UI.smallCardW,
                  title: L['special_regen'] ?? 'Regen. speciale',
                  child: Switch(
                    value: _specialRegen,
                    onChanged: (v) => setState(() => _specialRegen = v),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 320),
                  child: _boxed(
                    title:
                        L['boss_adv_vs_knights'] ?? 'Boss Advantage vs Knights',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _bossAdvDropdown(
                            _bossAdvK1, (v) => setState(() => _bossAdvK1 = v)),
                        _bossAdvDropdown(
                            _bossAdvK2, (v) => setState(() => _bossAdvK2 = v)),
                        _bossAdvDropdown(
                            _bossAdvK3, (v) => setState(() => _bossAdvK3 = v)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: UI.gap),
          Text(
            L['insert_knights'] ??
                'Inserisci qui sotto i dati dei tuoi cavalieri:',
            style: t.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _knightCard(1, 0)),
              const SizedBox(width: UI.gap),
              Expanded(child: _knightCard(2, 1)),
              const SizedBox(width: UI.gap),
              Expanded(child: _knightCard(3, 2)),
            ],
          ),
          const SizedBox(height: UI.gap),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _running ? null : _onSimulatePressed,
              child: Text(L['simulate'] ?? 'Simula'),
            ),
          ),
          const SizedBox(height: 12),
          _progressBar(_done, _total),
        ],
      ),
    );
  }

  // helpers UI
  Widget _boxed({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(UI.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _expandCard({required String title, required Widget child}) {
    return Expanded(child: _boxed(title: title, child: child));
  }

  Widget _fixedCard({
    required double width,
    required String title,
    required Widget child,
  }) {
    return SizedBox(width: width, child: _boxed(title: title, child: child));
  }

  Widget _bossAdvDropdown(double value, ValueChanged<double> onChanged) {
    const vals = [1.0, 1.5, 2.0];
    return SizedBox(
      width: UI.bossAdvItemW,
      child: DropdownButtonFormField<double>(
        value: value,
        items: vals
            .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
            .toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }

  Widget _uNum(TextEditingController c, String label,
      {TextInputType type =
          const TextInputType.numberWithOptions(decimal: true)}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _knightAdvDropdown(int i) {
    const vals = [1.0, 1.5, 2.0];
    return DropdownButtonFormField<double>(
      value: _kAdvVal[i],
      items: vals
          .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _kAdvVal[i] = v);
      },
      decoration: InputDecoration(labelText: L['advantage'] ?? 'Advantage'),
    );
  }

  Widget _knightCard(int idx, int i) {
    return _boxed(
      title: '${L['knight'] ?? 'Knight'} $idx',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _uNum(_kAtk[i], L['atk'] ?? 'ATK'),
          const SizedBox(height: 8),
          _uNum(_kDef[i], L['def'] ?? 'DEF'),
          const SizedBox(height: 8),
          _uNum(_kHp[i], L['hp'] ?? 'HP', type: TextInputType.number),
          const SizedBox(height: 8),
          _knightAdvDropdown(i),
          const SizedBox(height: 8),
          _uNum(_kStun[i], L['stun_chance'] ?? 'Stun Chance'),
        ],
      ),
    );
  }

  Widget _progressBar(int done, int total) {
    final val = (total <= 0) ? 0.0 : (done / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: (done == 0) ? 0 : val.clamp(0.0, 1.0)),
        const SizedBox(height: 4),
        Text('${fmtInt((val * 100).round())}%  ($done / $total)'),
      ],
    );
  }
}
