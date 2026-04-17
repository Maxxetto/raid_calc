// lib/ui/debug_results_page.dart
//
// Debug (Premium): pagina dedicata con log turn-by-turn.
// - Search in real-time
// - Copy log completo
// - Traduzioni via labels (mappa già con fallback EN in I18n)
// - ZERO dipendenze da BuildContext.lang / i18n extension (non esistono nel codebase)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/debug/debug_run.dart';
import '../core/engine/engine_common.dart';
import '../core/sim_types.dart';
import '../data/config_models.dart';
import '../data/pet_effect_models.dart';
import '../data/setup_models.dart';
import '../util/format.dart';

class DebugResultsPage extends StatefulWidget {
  final Precomputed pre;
  final DebugRunResult debug;
  final Map<String, String> labels;
  final ShatterShieldConfig? shatter;
  final SetupPetCompendiumImportSnapshot? importedPet;
  final List<PetResolvedEffect> petEffects;
  final bool cycloneUseGemsForSpecials;

  const DebugResultsPage({
    super.key,
    required this.pre,
    required this.debug,
    required this.labels,
    this.shatter,
    this.importedPet,
    this.petEffects = const <PetResolvedEffect>[],
    this.cycloneUseGemsForSpecials = true,
  });

  @override
  State<DebugResultsPage> createState() => _DebugResultsPageState();
}

class _DebugResultsPageState extends State<DebugResultsPage> {
  final TextEditingController _search = TextEditingController();
  late final List<String> _translatedAll;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _translatedAll = widget.debug.lines;
    _search.addListener(() {
      final v = _search.text.trim();
      if (v == _q) return;
      setState(() => _q = v);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String t(String key, String fallbackEn) {
    final v = widget.labels[key];
    if (v == null) return fallbackEn;
    final s = v.trim();
    return s.isEmpty ? fallbackEn : s;
  }

  String _modeKey(FightMode m) => switch (m) {
        FightMode.normal => 'mode.normal',
        FightMode.specialRegen => 'mode.special_regeneration',
        FightMode.specialRegenPlusEw => 'mode.sr_ew',
        FightMode.shatterShield => 'mode.shatter_shield',
        FightMode.cycloneBoost => 'mode.cyclone_boost',
        FightMode.durableRockShield => 'mode.durable_rock_shield',
        FightMode.specialRegenEw => 'mode.old_simulator',
      };

  String _descKey(FightMode m) => switch (m) {
        FightMode.normal => 'debug.desc.normal',
        FightMode.specialRegen => 'debug.desc.special_regeneration',
        FightMode.specialRegenPlusEw => 'debug.desc.sr_ew',
        FightMode.shatterShield => 'debug.desc.shatter_shield',
        FightMode.cycloneBoost => 'debug.desc.cyclone_boost',
        FightMode.durableRockShield => 'debug.desc.durable_rock_shield',
        FightMode.specialRegenEw => 'debug.desc.old_simulator',
      };

  static String _formatTpl(String tpl, Map<String, String> vars) {
    var out = tpl;
    vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  static String _pct(double v) {
    // accetta sia 0.65 che 65
    final x = (v <= 1.0) ? (v * 100.0) : v;
    final r = x.round();
    return '${r.toString()}%';
  }

  PetResolvedEffect? _effectByCanonicalId(String id) {
    final needle = id.trim().toLowerCase();
    for (final effect in widget.petEffects) {
      if (effect.canonicalEffectId.trim().toLowerCase() == needle) {
        return effect;
      }
    }
    return null;
  }

  num? _effectValue(String canonicalId, String key) {
    return _effectByCanonicalId(canonicalId)?.values[key];
  }

  String _skillValueSummary(SetupPetSkillSnapshot skill) {
    if (skill.values.isEmpty) return 'no imported values';
    return skill.values.entries.map((e) => '${e.key}=${e.value}').join(' | ');
  }

  static String _pctNoSign(double v) {
    final x = (v <= 1.0) ? (v * 100.0) : v;
    final r = x.round();
    return r.toString();
  }

  String _modeDescription() {
    final m = widget.pre.meta;
    final bool srEwUsesPetBar =
        widget.debug.mode == FightMode.specialRegenPlusEw &&
            m.petTicksBar.enabled &&
            m.petTicksBar.useInSpecialRegenPlusEw;
    final bool drsUsesPetBar =
        widget.debug.mode == FightMode.durableRockShield &&
            m.petTicksBar.enabled &&
            m.petTicksBar.useInDurableRockShield;
    final tpl = srEwUsesPetBar
        ? t(
            'debug.desc.sr_ew_pet_bar',
            'Battle simulation with Special Regeneration (assumed infinite). '
                'From turn {knightToSpecialSR} onward, knights use SPECIAL every turn. '
                'Elemental Weakness is applied when the pet casts Special 1 '
                '(-{reductionElementalWeakness} ATK for {durationElementalWeakness} boss turns). '
                'The numeric EW interval ({hitsToElementalWeakness}) is ignored while pet bar mode is active.',
          )
        : drsUsesPetBar
            ? t(
                'debug.desc.drs_pet_bar',
                'Battle simulation with Durable Rock Shield. The effect is applied when the pet casts according to the selected pet bar sequence ({petSkillUsage}) and each recast refreshes the {durationDRS}-turn duration.',
              )
            : t(
                _descKey(widget.debug.mode),
                _fallbackDescEn(widget.debug.mode),
              );

    final vars = <String, String>{
      'knightToSpecial': m.knightToSpecial.toString(),
      'bossToSpecial': m.bossToSpecial.toString(),
      'knightToSpecialSR': m.knightToSpecialSR.toString(),
      'hitsToElementalWeakness': m.hitsToElementalWeakness.toString(),
      'durationElementalWeakness': m.durationElementalWeakness.toString(),
      'reductionElementalWeakness': _pct(
        ((_effectValue('elemental_weakness', 'enemyAttackReductionPercent') ??
                        m.defaultElementalWeakness) <=
                    1.0
                ? (_effectValue(
                          'elemental_weakness',
                          'enemyAttackReductionPercent',
                        ) ??
                        m.defaultElementalWeakness)
                    .toDouble()
                : ((_effectValue(
                              'elemental_weakness',
                              'enemyAttackReductionPercent',
                            ) ??
                            m.defaultElementalWeakness)
                        .toDouble() /
                    100.0))
            .clamp(0.0, 10.0),
      ),
      'hitsToFirstShatter': m.hitsToFirstShatter.toString(),
      'hitsToNextShatter': m.hitsToNextShatter.toString(),
      'shatterBaseHp': ((_effectValue('shatter_shield', 'baseShieldHp') ??
              widget.shatter?.baseHp ??
              0))
          .round()
          .toString(),
      'shatterBonusHp': ((_effectValue('shatter_shield', 'bonusShieldHp') ??
              widget.shatter?.bonusHp ??
              0))
          .round()
          .toString(),
      'cyclone': _pctNoSign(
        resolvedCycloneBoostPct(
          widget.pre.petEffects,
          fallback: m.cyclone,
        ),
      ),
      'hitsToDRS': m.hitsToDRS.toString(),
      'durationDRS':
          ((_effectValue('durable_rock_shield', 'turns') ?? m.durationDRS))
              .round()
              .toString(),
      'durableRockShield': _pct(
        (((_effectValue('durable_rock_shield', 'defenseBoostPercent') ??
                        m.defaultDurableRockShield) <=
                    1.0
                ? (_effectValue(
                          'durable_rock_shield',
                          'defenseBoostPercent',
                        ) ??
                        m.defaultDurableRockShield)
                    .toDouble()
                : ((_effectValue(
                              'durable_rock_shield',
                              'defenseBoostPercent',
                            ) ??
                            m.defaultDurableRockShield)
                        .toDouble() /
                    100.0))
            .clamp(0.0, 10.0)),
      ),
      'petSkillUsage': widget.pre.petSkillUsage.shortLabel(),
    };

    final shatterFromPetBar =
        m.petTicksBar.enabled && m.petTicksBar.useInShatterShield;
    if (widget.debug.mode == FightMode.normal && m.knightSpecialBar.enabled) {
      final knightFill =
          (m.knightSpecialBar.knightTurnFill * 100).toStringAsFixed(1);
      final bossFill =
          (m.knightSpecialBar.bossTurnFill * 100).toStringAsFixed(1);
      return 'Battle simulation with Knight Special Bar. The active knight gains +$knightFill% bar per knight turn and +$bossFill% per boss turn or stun skip. When the bar reaches 100%, the next knight turn uses SPECIAL and the bar resets.';
    }
    if (widget.debug.mode == FightMode.shatterShield && shatterFromPetBar) {
      return 'Battle simulation with Shatter Shield. The pet bar starts at 1/2 and Shatter Shield is applied when the pet casts Special 2 (2/2 fill), then the bar resets and repeats.';
    }

    return _formatTpl(tpl, vars);
  }

  String _fallbackDescEn(FightMode mode) => switch (mode) {
        FightMode.normal =>
          'Battle simulation without pet skills. Knights use SPECIAL every {knightToSpecial} turns, while the Boss every {bossToSpecial} turns.',
        FightMode.specialRegen =>
          'Battle simulation with Special Regeneration (assumed infinite). From turn {knightToSpecialSR} onward, knights use SPECIAL every turn.',
        FightMode.specialRegenPlusEw =>
          'Battle simulation with Special Regeneration (assumed infinite). From turn {knightToSpecialSR} onward, knights use SPECIAL every turn. Then every {hitsToElementalWeakness} turns, Elemental Weakness is applied to the Boss: -{reductionElementalWeakness} ATK for {durationElementalWeakness} turns.',
        FightMode.shatterShield =>
          'Battle simulation with Shatter Shield. At turn {hitsToFirstShatter}, and then every {hitsToNextShatter} turns, the active knight gains a shield of {shatterBaseHp} HP (+{shatterBonusHp} HP if pet element matches).',
        FightMode.cycloneBoost => widget.cycloneUseGemsForSpecials
            ? 'Battle simulation with Cyclone Boost. Every turn from the first, the active knight ATK increases by {cyclone}%, stacking for 5 consecutive turns. From turn 6 onward, the boost stays constant. This mode is always gemmed: 4 gems are spent per knight turn.'
            : 'Battle simulation with Cyclone Boost. Cyclone stacks increase only when the pet casts a Cyclone skill through the pet bar and selected pet skill usage.',
        FightMode.durableRockShield =>
          'Battle simulation with Durable Rock Shield. Every {hitsToDRS} turns, the active knight gains a DEF boost of {durableRockShield} for {durationDRS} turns.',
        FightMode.specialRegenEw =>
          'Simulation using the old engine. Knights use SPECIAL every turn from turn 1 and the Boss cannot use SPECIAL.',
      };

  List<String> get _filtered {
    final q = _q.toLowerCase();
    if (q.isEmpty) return _translatedAll;
    return _translatedAll.where((l) => l.toLowerCase().contains(q)).toList();
  }

  Future<void> _copyAll() async {
    final header = _modeDescription();
    final full = <String>[
      header,
      ..._translatedAll,
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: full));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('debug.copied', 'Copied to clipboard')),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.debug.mode;

    final title = t('debug.title', 'Debug');
    final modeLabel = t(_modeKey(mode), mode.dropdownLabel());
    final modeTitle =
        t('debug.mode_title', 'Mode: {mode}').replaceAll('{mode}', modeLabel);

    final pointsLabel = t('debug.points', 'Points');
    final linesLabel = t('debug.lines', 'lines');

    final desc = _modeDescription();
    final list = _filtered;
    final importedSummary = widget.importedPet == null
        ? null
        : '1: ${petSkillDisplayName(widget.importedPet!.selectedSkill1)} | ${_skillValueSummary(widget.importedPet!.selectedSkill1)}\n'
            '2: ${petSkillDisplayName(widget.importedPet!.selectedSkill2)} | ${_skillValueSummary(widget.importedPet!.selectedSkill2)}\n'
            'Bar: ${widget.pre.petSkillUsage.shortLabel()}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: t('debug.copy_log', 'Copy log'),
            icon: Icon(
              Icons.copy,
              semanticLabel: t('debug.copy_log', 'Copy log'),
            ),
            onPressed: _copyAll,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              modeTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Boss L${widget.pre.meta.level} · Seed ${widget.debug.seed} · '
              '$pointsLabel: ${fmtInt(widget.debug.points)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
            if (importedSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                importedSummary,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: t('debug.search_hint', 'Search in log...'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${list.length} $linesLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      list[i],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.25,
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
