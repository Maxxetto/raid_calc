import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../core/sim_types.dart';
import '../../data/pet_skill_semantics_loader.dart';
import '../../data/setup_models.dart';
import '../widgets.dart';
import 'element_selector.dart';

class PetSection extends StatelessWidget {
  static void _noopBool(bool _) {}

  static const Map<String, String> _valueLabels = <String, String>{
    'attackBoostPercent': 'Knight ATK +',
    'baseShieldHp': 'Base shield',
    'baseShieldPercent': 'Base shield % of max HP',
    'bonusFlatDamage': 'Bonus damage',
    'bonusShieldHp': 'Bonus shield',
    'bonusShieldPercent': 'Bonus shield % of max HP',
    'critChancePercent': 'Crit chance +',
    'damageOverTime': 'Curse damage',
    'defenseBoostPercent': 'DEF +',
    'enemyAttackReductionPercent': 'Enemy ATK -',
    'flatDamage': 'Damage',
    'goldDrop': 'Gold drop',
    'meterChargePercent': 'Charge rate +',
    'petAttack': 'Pet ATK',
    'petAttackCap': 'Pet ATK cap',
    'stealPercent': 'Steal',
    'turns': 'Duration (turns)',
  };

  final String Function(String key, String fallback) t;
  final TextStyle themedLabel;
  final bool running;
  final TextEditingController petAtkCtl;
  final TextEditingController petElementalAtkCtl;
  final TextEditingController petElementalDefCtl;
  final ElementType firstElement;
  final ElementType? secondElement;
  final double advVsBoss;
  final String? importedCompendiumSummary;
  final SetupPetCompendiumImportSnapshot? importedCompendium;
  final SetupPetSkillSnapshot selectedSkill1;
  final SetupPetSkillSnapshot selectedSkill2;
  final List<SetupPetSkillSnapshot> skill1Options;
  final List<SetupPetSkillSnapshot> skill2Options;
  final ValueChanged<SetupPetSkillSnapshot> onSelectedSkill1Changed;
  final ValueChanged<SetupPetSkillSnapshot> onSelectedSkill2Changed;
  final PetSkillUsageMode petSkillUsageMode;
  final ValueChanged<PetSkillUsageMode> onPetSkillUsageModeChanged;
  final bool cycloneUseGemsForSpecials;
  final ValueChanged<bool> onCycloneUseGemsForSpecialsChanged;
  final ValueChanged<int> onElementCycle;
  final VoidCallback onOpenFavorites;
  final bool skillSlot1ValuesHidden;
  final bool skillSlot2ValuesHidden;
  final VoidCallback onToggleSkillSlot1ValuesHidden;
  final VoidCallback onToggleSkillSlot2ValuesHidden;

  const PetSection({
    super.key,
    required this.t,
    required this.themedLabel,
    required this.running,
    required this.petAtkCtl,
    required this.petElementalAtkCtl,
    required this.petElementalDefCtl,
    required this.firstElement,
    required this.secondElement,
    required this.advVsBoss,
    required this.importedCompendiumSummary,
    required this.importedCompendium,
    required this.selectedSkill1,
    required this.selectedSkill2,
    required this.skill1Options,
    required this.skill2Options,
    required this.onSelectedSkill1Changed,
    required this.onSelectedSkill2Changed,
    required this.petSkillUsageMode,
    required this.onPetSkillUsageModeChanged,
    this.cycloneUseGemsForSpecials = true,
    this.onCycloneUseGemsForSpecialsChanged = _noopBool,
    required this.onElementCycle,
    required this.onOpenFavorites,
    this.skillSlot1ValuesHidden = false,
    this.skillSlot2ValuesHidden = false,
    required this.onToggleSkillSlot1ValuesHidden,
    required this.onToggleSkillSlot2ValuesHidden,
  });

  Future<void> _showPetTip(BuildContext context) {
    final title = t('pet.tip.title', 'Pet tip');
    final body = t(
      'pet.tip.body',
      'Enter pet ATK, Elemental ATK, Elemental DEF and elements. Select Skill Slot 1, Skill Slot 2 and pet bar usage.',
    );
    final autoAdv = t(
      'pet.tip.auto_advantage',
      'Pet advantage is calculated automatically based on the selected elements.',
    );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('$body\n\n$autoAdv'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  String _skillValueLabel(String key) {
    return _valueLabels[key] ?? key;
  }

  List<String> _orderedSkillValueKeys(SetupPetSkillSnapshot skill) {
    final keys = <String>[
      ...skill.values.keys,
      ...skill.overrideValues.keys
          .where((key) => !skill.values.containsKey(key)),
    ];
    return List<String>.unmodifiable(keys);
  }

  String _formatNumericInput(num value) {
    final isWhole = value == value.roundToDouble();
    return isWhole ? value.toInt().toString() : value.toString();
  }

  String _normalizeSemanticsLookup(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll('\u221e', '(inf)')
      .replaceAll(RegExp(r'\s+'), ' ');

  PetSkillSemanticsEntry? _resolveSemanticsEntry(
    PetSkillSemanticsCatalog catalog,
    SetupPetSkillSnapshot skill,
  ) {
    final candidates = <String>{
      _normalizeSemanticsLookup(skill.name),
      _normalizeSemanticsLookup(petSkillDisplayName(skill)),
      if ((skill.canonicalEffectId ?? '').trim().isNotEmpty)
        skill.canonicalEffectId!.trim().toLowerCase(),
    };

    for (final entry in catalog.entriesByName.values) {
      final entryNames = <String>{
        _normalizeSemanticsLookup(entry.name),
        _normalizeSemanticsLookup(entry.canonicalName),
        entry.canonicalEffectId.trim().toLowerCase(),
      };
      if (entryNames.any(candidates.contains)) {
        return entry;
      }
    }
    return null;
  }

  String _semanticsSummaryForSkill(
    PetSkillSemanticsCatalog catalog,
    SetupPetSkillSnapshot skill,
  ) {
    final entry = _resolveSemanticsEntry(catalog, skill);
    if (entry == null) {
      return 'No tracked semantics available for this skill yet.';
    }
    final effectSummary = entry.effectSpec['summary']?.toString().trim() ?? '';
    if (effectSummary.isNotEmpty) return effectSummary;
    if (entry.gameplaySummary.trim().isNotEmpty) return entry.gameplaySummary;
    if (entry.projectSummary.trim().isNotEmpty) return entry.projectSummary;
    return 'No tracked semantics available for this skill yet.';
  }

  Future<void> _showSkillSemantics(
    BuildContext context,
    SetupPetSkillSnapshot skill,
  ) async {
    final catalog = await PetSkillSemanticsLoader.load();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(petSkillDisplayName(skill)),
        content: Text(_semanticsSummaryForSkill(catalog, skill)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  num? _parseNumericInput(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    bool hasSelectedSkill(String displayName) {
      final names = <String>{
        petSkillDisplayName(selectedSkill1),
        petSkillDisplayName(selectedSkill2),
      };
      return names.contains(displayName);
    }

    String skillKey(SetupPetSkillSnapshot skill) =>
        '${skill.slotId}|${skill.name}';
    String petSkillUsageLabel(PetSkillUsageMode mode) => switch (mode) {
          PetSkillUsageMode.special1Only =>
            t('pet.skill_usage.special1_only', '1'),
          PetSkillUsageMode.special2Only =>
            t('pet.skill_usage.special2_only', '2'),
          PetSkillUsageMode.cycleSpecial1Then2 =>
            t('pet.skill_usage.cycle_special1_then2', '1, 2'),
          PetSkillUsageMode.special2ThenSpecial1 =>
            t('pet.skill_usage.special2_then_special1', '2, 1'),
          PetSkillUsageMode.doubleSpecial2ThenSpecial1 => t(
              'pet.skill_usage.double_special2_then_special1',
              '2, 2, 1',
            ),
        };
    String petSkillUsageDescription(PetSkillUsageMode mode) => switch (mode) {
          PetSkillUsageMode.special1Only => t(
              'pet.skill_usage.special1_only.description',
              'Always fills once and uses Special 1.',
            ),
          PetSkillUsageMode.special2Only => t(
              'pet.skill_usage.special2_only.description',
              'Always fills to Special 2 and uses it.',
            ),
          PetSkillUsageMode.cycleSpecial1Then2 => t(
              'pet.skill_usage.cycle_special1_then2.description',
              'Uses Special 1, then Special 2, then repeats.',
            ),
          PetSkillUsageMode.special2ThenSpecial1 => t(
              'pet.skill_usage.special2_then_special1.description',
              'Starts with Special 2, then always uses Special 1.',
            ),
          PetSkillUsageMode.doubleSpecial2ThenSpecial1 => t(
              'pet.skill_usage.double_special2_then_special1.description',
              'Starts with Special 2 twice, then always uses Special 1.',
            ),
        };
    Widget skillDropdown({
      required String label,
      required SetupPetSkillSnapshot selectedSkill,
      required List<SetupPetSkillSnapshot> options,
      required ValueChanged<SetupPetSkillSnapshot> onChanged,
      required String valueKey,
    }) {
      final optionMap = <String, SetupPetSkillSnapshot>{
        for (final option in options) skillKey(option): option,
      };
      final selectedKey = skillKey(selectedSkill);
      final initialKey = optionMap.containsKey(selectedKey)
          ? selectedKey
          : optionMap.keys.first;
      return LabeledField(
        label: label,
        labelStyle: themedLabel,
        child: DropdownButtonFormField<String>(
          key: ValueKey(valueKey),
          initialValue: initialKey,
          isDense: false,
          itemHeight: null,
          items: optionMap.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    petSkillDisplayName(entry.value),
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              )
              .toList(growable: false),
          selectedItemBuilder: (context) {
            return optionMap.entries
                .map(
                  (entry) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      petSkillDisplayName(entry.value),
                      maxLines: 2,
                      softWrap: true,
                    ),
                  ),
                )
                .toList(growable: false);
          },
          isExpanded: true,
          onChanged: running
              ? null
              : (value) {
                  final skill = value == null ? null : optionMap[value];
                  if (skill == null) return;
                  onChanged(skill);
                },
          decoration: const InputDecoration(
            isDense: false,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      );
    }

    Widget skillValueEditor({
      required int slotIndex,
      required SetupPetSkillSnapshot selectedSkill,
      required ValueChanged<SetupPetSkillSnapshot> onChanged,
      required bool hidden,
      required VoidCallback onToggleHidden,
    }) {
      final displayName = petSkillDisplayName(selectedSkill);
      final isNone = displayName == t('pet.skill.none', 'None');
      final keys = _orderedSkillValueKeys(selectedSkill);
      if (isNone || keys.isEmpty) {
        return const SizedBox.shrink();
      }

      SetupPetSkillSnapshot applyValue(String key, String raw) {
        final overrides = Map<String, num>.from(selectedSkill.overrideValues);
        final parsed = _parseNumericInput(raw);
        final base = selectedSkill.values[key];
        if (parsed == null || (base != null && parsed == base)) {
          overrides.remove(key);
        } else {
          overrides[key] = parsed;
        }
        return selectedSkill.copyWith(
          overrideValues: Map<String, num>.unmodifiable(overrides),
        );
      }

      final theme = Theme.of(context);
      final summary = keys
          .map(
            (key) =>
                '${_skillValueLabel(key)}: ${_formatNumericInput(selectedSkill.effectiveValues[key] ?? 0)}',
          )
          .join(' | ');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t(
                      slotIndex == 1
                          ? 'pet.skill_slot_1.values'
                          : 'pet.skill_slot_2.values',
                      slotIndex == 1
                          ? 'Skill Slot 1 values'
                          : 'Skill Slot 2 values',
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Skill details',
                  child: IconButton(
                    key: ValueKey('pet-skill-slot$slotIndex-semantics-help'),
                    onPressed: () => _showSkillSemantics(context, selectedSkill),
                    icon: const Icon(Icons.info_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  key: ValueKey('pet-skill-slot$slotIndex-toggle-hidden'),
                  onPressed: onToggleHidden,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  label: Text(
                    hidden
                        ? t('common.show', 'Show')
                        : t('common.hide', 'Hide'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (hidden)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary,
                  key: ValueKey('pet-skill-slot$slotIndex-hidden-summary'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              Text(
                t(
                  'pet.skill.values_hint',
                  'Default values are prefilled. Set any numeric value to 0 to disable that skill effect for the simulation.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final key in keys)
                    SizedBox(
                      width: 220,
                      child: LabeledField(
                        label: _skillValueLabel(key),
                        labelStyle: themedLabel,
                        child: TextFormField(
                          key: ValueKey(
                            'pet-skill-slot$slotIndex-$displayName-$key',
                          ),
                          initialValue: _formatNumericInput(
                            selectedSkill.effectiveValues[key] ?? 0,
                          ),
                          enabled: !running,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (raw) => onChanged(applyValue(key, raw)),
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            hintText: _formatNumericInput(
                              selectedSkill.values[key] ?? 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('pet.title', 'Pet'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('pet-tip-button'),
                tooltip: t('pet.tip.title', 'Pet tip'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _showPetTip(context),
                icon: const Icon(Icons.info_outline, size: 18),
              ),
              IconButton(
                key: const ValueKey('pet-favorites-open-button'),
                tooltip: t('pet.favorites.open', 'Open favorite pets'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                color: theme.colorScheme.primary,
                onPressed: onOpenFavorites,
                icon: const Icon(Icons.star_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: t('pet.atk', 'Pet ATK'),
                  labelStyle: themedLabel,
                  child: CompactGroupedIntField(
                    key: const ValueKey('pet-atk-field'),
                    controller: petAtkCtl,
                    hint: '0',
                    enabled: !running,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledField(
                  label: t('pet.elemental_atk', 'Elemental ATK'),
                  labelStyle: themedLabel,
                  child: CompactGroupedIntField(
                    key: const ValueKey('pet-elemental-atk-field'),
                    controller: petElementalAtkCtl,
                    hint: '0',
                    enabled: !running,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledField(
                  label: t('pet.elemental_def', 'Elemental DEF'),
                  labelStyle: themedLabel,
                  child: CompactGroupedIntField(
                    key: const ValueKey('pet-elemental-def-field'),
                    controller: petElementalDefCtl,
                    hint: '0',
                    enabled: !running,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: t('pet.elements', 'Pet elements'),
                  labelStyle: themedLabel,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElementButton(
                          value: firstElement,
                          onPressed: running ? null : () => onElementCycle(0),
                          t: t,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OptionalElementButton(
                          value: secondElement,
                          enabled: !running,
                          onPressed: () => onElementCycle(1),
                          t: t,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatMultiplier(advVsBoss),
                        style: themedLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (importedCompendiumSummary != null &&
              importedCompendiumSummary!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                t(
                  'pet.imported.source',
                  'Imported pet source: {summary}',
                ).replaceAll('{summary}', importedCompendiumSummary!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: skillDropdown(
                  label: t('pet.skill_slot_1', 'Skill Slot 1'),
                  selectedSkill: selectedSkill1,
                  options: skill1Options.isEmpty
                      ? <SetupPetSkillSnapshot>[selectedSkill1]
                      : skill1Options,
                  onChanged: onSelectedSkill1Changed,
                  valueKey: 'pet-skill-slot1',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: skillDropdown(
                  label: t('pet.skill_slot_2', 'Skill Slot 2'),
                  selectedSkill: selectedSkill2,
                  options: skill2Options.isEmpty
                      ? <SetupPetSkillSnapshot>[selectedSkill2]
                      : skill2Options,
                  onChanged: onSelectedSkill2Changed,
                  valueKey: 'pet-skill-slot2',
                ),
              ),
            ],
          ),
          if (petSkillDisplayName(selectedSkill1) !=
              t('pet.skill.none', 'None')) ...[
            const SizedBox(height: 10),
            skillValueEditor(
              slotIndex: 1,
              selectedSkill: selectedSkill1,
              onChanged: onSelectedSkill1Changed,
              hidden: skillSlot1ValuesHidden,
              onToggleHidden: onToggleSkillSlot1ValuesHidden,
            ),
          ],
          if (petSkillDisplayName(selectedSkill2) !=
              t('pet.skill.none', 'None')) ...[
            const SizedBox(height: 10),
            skillValueEditor(
              slotIndex: 2,
              selectedSkill: selectedSkill2,
              onChanged: onSelectedSkill2Changed,
              hidden: skillSlot2ValuesHidden,
              onToggleHidden: onToggleSkillSlot2ValuesHidden,
            ),
          ],
          const SizedBox(height: 10),
          LabeledField(
            label: t('pet.skill_usage', 'Pet skill usage'),
            labelStyle: themedLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<PetSkillUsageMode>(
                  key: ValueKey('pet-skill-usage-${petSkillUsageMode.name}'),
                  initialValue: petSkillUsageMode,
                  items: PetSkillUsageMode.values
                      .map(
                        (mode) => DropdownMenuItem<PetSkillUsageMode>(
                          value: mode,
                          child: Text(petSkillUsageLabel(mode)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: running
                      ? null
                      : (value) {
                          if (value == null) return;
                          onPetSkillUsageModeChanged(value);
                        },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  petSkillUsageDescription(petSkillUsageMode),
                  key: const ValueKey('pet-skill-usage-description'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasSelectedSkill('Cyclone Boost')) ...[
            const SizedBox(height: 10),
            SmallSwitchTile(
              title: t(
                'pet.cyclone_use_gems_for_specials',
                'Utilize gems for Specials',
              ),
              value: cycloneUseGemsForSpecials,
              onChanged: running ? (_) {} : onCycloneUseGemsForSpecialsChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionalElementButton extends StatelessWidget {
  final ElementType? value;
  final bool enabled;
  final VoidCallback onPressed;
  final String Function(String, String) t;

  const _OptionalElementButton({
    required this.value,
    required this.enabled,
    required this.onPressed,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    if (value != null) {
      return ElementButton(
        value: value!,
        onPressed: enabled ? onPressed : null,
        t: t,
      );
    }

    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final label = t('pet.element.empty', 'Empty');
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : color.withValues(alpha: 0.55),
          foregroundColor: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: enabled ? 1.0 : 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
