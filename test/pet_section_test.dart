import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/data/setup_models.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/ui/home/pet_section.dart';

void main() {
  testWidgets('pet skill usage selector shows and updates its description',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    final petAtkCtl = TextEditingController(text: '0');
    final petElementalAtkCtl = TextEditingController(text: '0');
    final petElementalDefCtl = TextEditingController(text: '0');
    var selectedMode = PetSkillUsageMode.special1Only;

    addTearDown(() {
      petAtkCtl.dispose();
      petElementalAtkCtl.dispose();
      petElementalDefCtl.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PetSection(
              t: _translate,
              themedLabel: Theme.of(context).textTheme.labelLarge!,
              running: false,
              petAtkCtl: petAtkCtl,
              petElementalAtkCtl: petElementalAtkCtl,
              petElementalDefCtl: petElementalDefCtl,
              firstElement: ElementType.fire,
              secondElement: ElementType.water,
              advVsBoss: 1.5,
              importedCompendiumSummary: null,
              importedCompendium: null,
              selectedSkill1: const SetupPetSkillSnapshot(
                slotId: 'skill1_none',
                name: 'None',
                values: <String, num>{},
              ),
              selectedSkill2: const SetupPetSkillSnapshot(
                slotId: 'skill2_none',
                name: 'None',
                values: <String, num>{},
              ),
              skill1Options: const <SetupPetSkillSnapshot>[
                SetupPetSkillSnapshot(
                  slotId: 'skill1_none',
                  name: 'None',
                  values: <String, num>{},
                ),
                SetupPetSkillSnapshot(
                  slotId: 'skill11',
                  name: 'Special Regeneration',
                  values: <String, num>{},
                ),
              ],
              skill2Options: const <SetupPetSkillSnapshot>[
                SetupPetSkillSnapshot(
                  slotId: 'skill2_none',
                  name: 'None',
                  values: <String, num>{},
                ),
                SetupPetSkillSnapshot(
                  slotId: 'skill2',
                  name: 'Shatter Shield',
                  values: <String, num>{
                    'baseShieldHp': 100,
                    'bonusShieldHp': 20
                  },
                ),
              ],
              onSelectedSkill1Changed: (_) {},
              onSelectedSkill2Changed: (_) {},
              petSkillUsageMode: selectedMode,
              onPetSkillUsageModeChanged: (value) {
                setState(() => selectedMode = value);
              },
              onElementCycle: (_) {},
              onOpenFavorites: () {},
              onToggleSkillSlot1ValuesHidden: () {},
              onToggleSkillSlot2ValuesHidden: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Always fills once and uses Special 1.'),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('pet-skill-usage-special1Only')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2, 1').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Starts with Special 2, then always uses Special 1.'),
      findsOneWidget,
    );

    expect(find.text('Skill Slot 1'), findsOneWidget);
    expect(find.text('Skill Slot 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('fightMode-pet-normal')), findsNothing);
  });

  testWidgets(
      'imported pet shows normalized slot dropdowns and skill-driven controls',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    final petAtkCtl = TextEditingController(text: '0');
    final petElementalAtkCtl = TextEditingController(text: '0');
    final petElementalDefCtl = TextEditingController(text: '0');
    SetupPetSkillSnapshot? slot1ChangedTo;

    addTearDown(() {
      petAtkCtl.dispose();
      petElementalAtkCtl.dispose();
      petElementalDefCtl.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const imported = SetupPetCompendiumImportSnapshot(
      familyId: 's101sf_ignitide',
      familyTag: 'S101SF',
      rarity: 'Shadowforged',
      tierId: 'V',
      tierName: '[S101SF] Ignitide',
      profileId: 'max',
      profileLabel: 'Max 99',
      useAltSkillSet: false,
      availableSkill1Options: <SetupPetSkillSnapshot>[
        SetupPetSkillSnapshot(
          slotId: 'skill11',
          name: 'Cyclone Earth Boost',
          values: <String, num>{},
        ),
        SetupPetSkillSnapshot(
          slotId: 'skill12',
          name: 'Special Regeneration',
          values: <String, num>{'meterChargePercent': 104.72},
        ),
      ],
      availableSkill2Options: <SetupPetSkillSnapshot>[
        SetupPetSkillSnapshot(
          slotId: 'skill2',
          name: 'Special Regeneration (inf)',
          values: <String, num>{'meterChargePercent': 104.72},
        ),
      ],
      selectedSkill1: SetupPetSkillSnapshot(
        slotId: 'skill11',
        name: 'Cyclone Earth Boost',
        values: <String, num>{},
      ),
      selectedSkill2: SetupPetSkillSnapshot(
        slotId: 'skill2',
        name: 'Special Regeneration (inf)',
        values: <String, num>{'meterChargePercent': 104.72},
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetSection(
            t: _translate,
            themedLabel: const TextStyle(),
            running: false,
            petAtkCtl: petAtkCtl,
            petElementalAtkCtl: petElementalAtkCtl,
            petElementalDefCtl: petElementalDefCtl,
            firstElement: ElementType.fire,
            secondElement: ElementType.water,
            advVsBoss: 1.5,
            importedCompendiumSummary: 'S101SF | [S101SF] Ignitide',
            importedCompendium: imported,
            selectedSkill1: imported.selectedSkill1,
            selectedSkill2: imported.selectedSkill2,
            skill1Options: imported.availableSkill1Options,
            skill2Options: imported.availableSkill2Options,
            onSelectedSkill1Changed: (value) {
              slot1ChangedTo = value;
            },
            onSelectedSkill2Changed: (_) {},
            petSkillUsageMode: PetSkillUsageMode.special1Only,
            onPetSkillUsageModeChanged: (_) {},
            onElementCycle: (_) {},
            onOpenFavorites: () {},
            onToggleSkillSlot1ValuesHidden: () {},
            onToggleSkillSlot2ValuesHidden: () {},
          ),
        ),
      ),
    );

    expect(find.text('Skill Slot 1'), findsOneWidget);
    expect(find.text('Skill Slot 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('fightMode-pet-normal')), findsNothing);
    expect(find.text('Cyclone Boost'), findsOneWidget);
    expect(find.text('Special Regeneration \u221E'), findsOneWidget);
    expect(find.text('Utilize gems for Specials'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pet-skill-slot1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Special Regeneration').last);
    await tester.pumpAndSettle();

    expect(slot1ChangedTo?.name, 'Special Regeneration');
  });

  testWidgets('selected skill values are editable through dynamic skill fields',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    final petAtkCtl = TextEditingController(text: '2500');
    final petElementalAtkCtl = TextEditingController(text: '0');
    final petElementalDefCtl = TextEditingController(text: '0');
    SetupPetSkillSnapshot currentSkill1 = const SetupPetSkillSnapshot(
      slotId: 'skill11',
      name: 'Elemental Weakness',
      values: <String, num>{
        'enemyAttackReductionPercent': 65,
        'turns': 2,
      },
    );

    addTearDown(() {
      petAtkCtl.dispose();
      petElementalAtkCtl.dispose();
      petElementalDefCtl.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PetSection(
              t: _translate,
              themedLabel: Theme.of(context).textTheme.labelLarge!,
              running: false,
              petAtkCtl: petAtkCtl,
              petElementalAtkCtl: petElementalAtkCtl,
              petElementalDefCtl: petElementalDefCtl,
              firstElement: ElementType.fire,
              secondElement: ElementType.water,
              advVsBoss: 1.5,
              importedCompendiumSummary: null,
              importedCompendium: null,
              selectedSkill1: currentSkill1,
              selectedSkill2: const SetupPetSkillSnapshot(
                slotId: 'skill2_none',
                name: 'None',
                values: <String, num>{},
              ),
              skill1Options: const <SetupPetSkillSnapshot>[
                SetupPetSkillSnapshot(
                  slotId: 'skill11',
                  name: 'Elemental Weakness',
                  values: <String, num>{
                    'enemyAttackReductionPercent': 65,
                    'turns': 2,
                  },
                ),
              ],
              skill2Options: const <SetupPetSkillSnapshot>[
                SetupPetSkillSnapshot(
                  slotId: 'skill2_none',
                  name: 'None',
                  values: <String, num>{},
                ),
              ],
              onSelectedSkill1Changed: (value) {
                setState(() => currentSkill1 = value);
              },
              onSelectedSkill2Changed: (_) {},
              petSkillUsageMode: PetSkillUsageMode.special1Only,
              onPetSkillUsageModeChanged: (_) {},
              onElementCycle: (_) {},
              onOpenFavorites: () {},
              onToggleSkillSlot1ValuesHidden: () {},
              onToggleSkillSlot2ValuesHidden: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Skill Slot 1 values'), findsOneWidget);
    expect(find.text('Enemy ATK -'), findsOneWidget);
    expect(find.text('Duration (turns)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pet-skill-slot1-Elemental Weakness-turns')),
      '3',
    );
    await tester.pump();

    expect(currentSkill1.overrideValues, const <String, num>{'turns': 3});
    expect(currentSkill1.effectiveValues['turns'], 3);
  });

  testWidgets('skill value editor exposes semantics help dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    final petAtkCtl = TextEditingController(text: '2500');
    final petElementalAtkCtl = TextEditingController(text: '0');
    final petElementalDefCtl = TextEditingController(text: '0');

    addTearDown(() {
      petAtkCtl.dispose();
      petElementalAtkCtl.dispose();
      petElementalDefCtl.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetSection(
            t: _translate,
            themedLabel: const TextStyle(),
            running: false,
            petAtkCtl: petAtkCtl,
            petElementalAtkCtl: petElementalAtkCtl,
            petElementalDefCtl: petElementalDefCtl,
            firstElement: ElementType.fire,
            secondElement: ElementType.water,
            advVsBoss: 1.5,
            importedCompendiumSummary: null,
            importedCompendium: null,
            selectedSkill1: const SetupPetSkillSnapshot(
              slotId: 'skill11',
              name: 'Elemental Weakness',
              values: <String, num>{
                'enemyAttackReductionPercent': 65,
                'turns': 2,
              },
            ),
            selectedSkill2: const SetupPetSkillSnapshot(
              slotId: 'skill2_none',
              name: 'None',
              values: <String, num>{},
            ),
            skill1Options: const <SetupPetSkillSnapshot>[
              SetupPetSkillSnapshot(
                slotId: 'skill11',
                name: 'Elemental Weakness',
                values: <String, num>{
                  'enemyAttackReductionPercent': 65,
                  'turns': 2,
                },
              ),
            ],
            skill2Options: const <SetupPetSkillSnapshot>[
              SetupPetSkillSnapshot(
                slotId: 'skill2_none',
                name: 'None',
                values: <String, num>{},
              ),
            ],
            onSelectedSkill1Changed: (_) {},
            onSelectedSkill2Changed: (_) {},
            petSkillUsageMode: PetSkillUsageMode.special1Only,
            onPetSkillUsageModeChanged: (_) {},
            onElementCycle: (_) {},
            onOpenFavorites: () {},
            onToggleSkillSlot1ValuesHidden: () {},
            onToggleSkillSlot2ValuesHidden: () {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-skill-slot1-semantics-help')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Elemental Weakness'), findsWidgets);
    expect(
      find.textContaining(
        'When triggered, Elemental Weakness reduces boss ATK',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'pet section shows percentage labels for percent-based Shatter Shield',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    final petAtkCtl = TextEditingController(text: '1990');
    final petElementalAtkCtl = TextEditingController(text: '0');
    final petElementalDefCtl = TextEditingController(text: '0');

    addTearDown(() {
      petAtkCtl.dispose();
      petElementalAtkCtl.dispose();
      petElementalDefCtl.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final skill = SetupPetSkillSnapshot(
      slotId: 'skill12',
      name: 'Shatter Shield',
      values: const <String, num>{
        'baseShieldPercent': 4.4,
        'bonusShieldPercent': 2.2,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PetSection(
            t: _translate,
            themedLabel: const TextStyle(),
            running: false,
            petAtkCtl: petAtkCtl,
            petElementalAtkCtl: petElementalAtkCtl,
            petElementalDefCtl: petElementalDefCtl,
            firstElement: ElementType.fire,
            secondElement: ElementType.water,
            advVsBoss: 1.5,
            importedCompendiumSummary: 'S59P | Mudferret | Max 80',
            importedCompendium: SetupPetCompendiumImportSnapshot(
              familyId: 'mudferret',
              familyTag: 'S59P',
              rarity: 'Primal',
              tierId: 'IV',
              tierName: 'Mudferret',
              profileId: 'max_80',
              profileLabel: 'Max 80',
              useAltSkillSet: true,
              availableSkill1Options: <SetupPetSkillSnapshot>[skill],
              availableSkill2Options: const <SetupPetSkillSnapshot>[
                SetupPetSkillSnapshot(
                  slotId: 'skill2',
                  name: 'Leech Strike',
                  values: <String, num>{'flatDamage': 7960, 'stealPercent': 10},
                ),
              ],
              selectedSkill1: skill,
              selectedSkill2: const SetupPetSkillSnapshot(
                slotId: 'skill2',
                name: 'Leech Strike',
                values: <String, num>{'flatDamage': 7960, 'stealPercent': 10},
              ),
            ),
            selectedSkill1: skill,
            selectedSkill2: const SetupPetSkillSnapshot(
              slotId: 'skill2',
              name: 'Leech Strike',
              values: <String, num>{'flatDamage': 7960, 'stealPercent': 10},
            ),
            skill1Options: <SetupPetSkillSnapshot>[skill],
            skill2Options: const <SetupPetSkillSnapshot>[
              SetupPetSkillSnapshot(
                slotId: 'skill2',
                name: 'Leech Strike',
                values: <String, num>{'flatDamage': 7960, 'stealPercent': 10},
              ),
            ],
            onSelectedSkill1Changed: (_) {},
            onSelectedSkill2Changed: (_) {},
            petSkillUsageMode: PetSkillUsageMode.special1Only,
            onPetSkillUsageModeChanged: (_) {},
            onElementCycle: (_) {},
            onOpenFavorites: () {},
            onToggleSkillSlot1ValuesHidden: () {},
            onToggleSkillSlot2ValuesHidden: () {},
          ),
        ),
      ),
    );

    expect(find.text('Base shield % of max HP'), findsOneWidget);
    expect(find.text('Bonus shield % of max HP'), findsOneWidget);
    expect(find.text('Base shield'), findsNothing);
    expect(find.text('Bonus shield'), findsNothing);
  });
}

String _translate(String _, String fallback) => fallback;
