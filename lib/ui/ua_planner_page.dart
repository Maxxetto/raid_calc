import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ua_planner_rules_loader.dart';
import '../data/ua_planner_storage.dart';
import '../util/i18n.dart';
import 'widgets.dart';

class UaPlannerPage extends StatefulWidget {
  final I18n? i18n;
  final bool isPremium;
  final VoidCallback? onOpenPremium;
  final VoidCallback? onOpenLastResults;
  final VoidCallback? onOpenTheme;
  final VoidCallback? onOpenLanguage;

  const UaPlannerPage({
    super.key,
    this.i18n,
    this.isPremium = false,
    this.onOpenPremium,
    this.onOpenLastResults,
    this.onOpenTheme,
    this.onOpenLanguage,
  });

  @override
  State<UaPlannerPage> createState() => _UaPlannerPageState();
}

class _UaPlannerPageState extends State<UaPlannerPage> {
  static const String _plannerExportKind = 'ua_planner.state';
  static const int _plannerExportVersion = 1;
  static const List<_UaField> _fields = <_UaField>[
    _UaField('war', 'ua_planner.field.war', 'War'),
    _UaField('war_blitz', 'ua_planner.field.war_blitz', 'War Blitz'),
    _UaField('raid', 'ua_planner.field.raid', 'Raid'),
    _UaField('raid_blitz', 'ua_planner.field.raid_blitz', 'Raid Blitz'),
    _UaField('heroic', 'ua_planner.field.heroic', 'Heroic'),
    _UaField('headstart', 'ua_planner.field.headstart', 'Headstart'),
    _UaField(
      'eb_collection',
      'ua_planner.field.eb_collection',
      'EB Collection',
    ),
  ];

  static const List<_UaBonusRule> _bonusRules = <_UaBonusRule>[
    _UaBonusRule(
      id: 'headstart_prev_month',
      triggerFieldId: 'headstart',
      labelKey: 'ua_planner.bonus.headstart.prev_month',
      fallback: 'Crafted Elite+ of previous month',
      pieces: 1,
    ),
    _UaBonusRule(
      id: 'headstart_prev_two_months',
      triggerFieldId: 'headstart',
      labelKey: 'ua_planner.bonus.headstart.prev_two_months',
      fallback: 'Crafted Elite+ of previous two months',
      pieces: 1,
      dependsOnBonusId: 'headstart_prev_month',
    ),
    _UaBonusRule(
      id: 'eb_current_month',
      triggerFieldId: 'eb_collection',
      labelKey: 'ua_planner.bonus.eb.current_month',
      fallback: 'Obtained T20 armor of the current month',
      pieces: 1,
    ),
    _UaBonusRule(
      id: 'eb_current_and_past',
      triggerFieldId: 'eb_collection',
      labelKey: 'ua_planner.bonus.eb.current_and_past',
      fallback: 'Obtained T20 armor of current and past month',
      pieces: 1,
      dependsOnBonusId: 'eb_current_month',
    ),
  ];
  static const List<_UaCraftRule> _craftRules = <_UaCraftRule>[
    _UaCraftRule(
      id: 'elite',
      labelKey: 'ua_planner.craft.elite',
      fallback: 'Elite crafted',
      thresholdPieces: 10,
    ),
    _UaCraftRule(
      id: 'elite_plus',
      labelKey: 'ua_planner.craft.elite_plus',
      fallback: 'Elite+ crafted',
      thresholdPieces: 20,
    ),
  ];

  static const List<_UaSpecialRewardRule> _firstBlitzWarRewards =
      <_UaSpecialRewardRule>[
    _UaSpecialRewardRule(
      id: 'elite_ring',
      labelKey: 'ua_planner.reward.elite_ring',
      fallback: 'Elite ring',
      minPoints: 350000,
      quantity: 1,
    ),
    _UaSpecialRewardRule(
      id: 'elite_amulet',
      labelKey: 'ua_planner.reward.elite_amulet',
      fallback: 'Elite amulet',
      minPoints: 475000,
      quantity: 1,
    ),
    _UaSpecialRewardRule(
      id: 'ua_eggs',
      labelKey: 'ua_planner.reward.ua_eggs',
      fallback: 'UA Eggs',
      minPoints: 350000,
      quantity: 5,
    ),
  ];

  static const List<_UaEventType> _eventTypes = <_UaEventType>[
    _UaEventType(
      id: 'raid_blitz',
      fieldId: 'raid_blitz',
      labelKey: 'ua_planner.field.raid_blitz',
      fallback: 'Raid Blitz',
      includeIndividualPlacement: true,
    ),
    _UaEventType(
      id: 'raid',
      fieldId: 'raid',
      labelKey: 'ua_planner.field.raid',
      fallback: 'Raid',
      includeIndividualPlacement: true,
    ),
    _UaEventType(
      id: 'war_blitz',
      fieldId: 'war_blitz',
      labelKey: 'ua_planner.field.war_blitz',
      fallback: 'War Blitz',
      includeIndividualPlacement: false,
    ),
    _UaEventType(
      id: 'war',
      fieldId: 'war',
      labelKey: 'ua_planner.field.war',
      fallback: 'War',
      includeIndividualPlacement: false,
    ),
  ];

  static const List<String> _monthFallbacks = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static final DateTime _plannerStartMonth = DateTime(2025, 11, 1);
  static final DateTime _plannerEndMonth = DateTime(2028, 12, 1);
  static final DateTime _heroicAnchorDate = DateTime(2026, 3, 3);
  static final DateTime _cycleAnchorStartMonth = DateTime(2025, 11, 1);
  static const int _cycleAnchorNumber = 15;

  static const List<String> _elementCycle = <String>[
    'fire',
    'spirit',
    'earth',
    'air',
    'water',
  ];
  static final RegExp _scoreNumberRegExp = RegExp(r'^\d*([.,]\d{0,3})?$');
  static final List<_UaScoreUnit> _scoreUnits = <_UaScoreUnit>[
    _UaScoreUnit('k', 1000, 'K'),
    _UaScoreUnit('m', 1000000, 'M'),
    _UaScoreUnit('b', 1000000000, 'B'),
  ];

  static final List<DateTime> _plannerMonths = _buildPlannerMonths();
  static final List<DateTime> _heroicDatesAll = _buildHeroicDatesInRange();
  static final Map<String, List<DateTime>> _eventDatesAll = _buildEventDates();
  final Map<String, TextEditingController> _inputControllers =
      <String, TextEditingController>{};
  UaRuleset? _uaRuleset;
  bool _showHiddenMonths = false;
  bool _plannerLocked = false;
  final Set<String> _hiddenMonthKeys = <String>{};

  late final List<_UaMonth> _months = List<_UaMonth>.generate(
    _plannerMonths.length,
    (idx) {
      final monthDate = _plannerMonths[idx];
      final y = monthDate.year;
      final m = monthDate.month;
      return _UaMonth(
        monthKey: _monthKey(y, m),
        year: y,
        month: m,
        elementId: _elementForMonthDate(monthDate),
        cycleNumber: _cycleNumberForMonth(monthDate),
        isCycleStart: _isCycleStart(monthDate),
        flags: <String, bool>{for (final f in _fields) f.id: false},
        bonusFlags: <String, bool>{for (final b in _bonusRules) b.id: false},
        craftFlags: <String, bool>{for (final c in _craftRules) c.id: false},
        heroicDates: _heroicDatesForMonth(y, m),
        heroicFlags: <String, bool>{
          for (final d in _heroicDatesForMonth(y, m)) _dateKey(d): false,
        },
        eventDatesByType: <String, List<DateTime>>{
          for (final type in _eventTypes)
            type.id: _eventDatesForMonth(type.id, y, m),
        },
        scoreInputs: <String, String>{
          for (final type in _eventTypes)
            for (final d in _eventDatesForMonth(type.id, y, m))
              _eventKey(type.id, d): '',
        },
        scoreUnits: <String, String>{
          for (final type in _eventTypes)
            for (final d in _eventDatesForMonth(type.id, y, m))
              _eventKey(type.id, d): _defaultScoreUnitForType(type.id),
        },
        guildPlacementInputs: <String, String>{
          for (final type in _eventTypes)
            for (final d in _eventDatesForMonth(type.id, y, m))
              _eventKey(type.id, d): '',
        },
        individualPlacementInputs: <String, String>{
          for (final type
              in _eventTypes.where((t) => t.includeIndividualPlacement))
            for (final d in _eventDatesForMonth(type.id, y, m))
              _eventKey(type.id, d): '',
        },
      );
    },
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadUaRuleset());
    unawaited(_restorePlannerState());
  }

  @override
  void dispose() {
    for (final ctl in _inputControllers.values) {
      ctl.dispose();
    }
    _inputControllers.clear();
    super.dispose();
  }

  static List<DateTime> _buildPlannerMonths() {
    final months = <DateTime>[];
    DateTime cursor = _plannerStartMonth;
    while (!cursor.isAfter(_plannerEndMonth)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return months;
  }

  static List<DateTime> _buildHeroicDatesInRange() {
    final dates = <DateTime>[];
    final start = _plannerStartMonth;
    final end = DateTime(_plannerEndMonth.year, _plannerEndMonth.month + 1, 0);
    final anchor = _heroicAnchorDate; // Tuesday

    for (DateTime d = anchor;
        !d.isBefore(start);
        d = d.subtract(const Duration(days: 14))) {
      dates.add(d);
    }
    for (DateTime d = anchor.add(const Duration(days: 14));
        !d.isAfter(end);
        d = d.add(const Duration(days: 14))) {
      dates.add(d);
    }
    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }

  static List<DateTime> _heroicDatesForMonth(int year, int month) {
    return _heroicDatesAll
        .where((d) => d.year == year && d.month == month)
        .toList();
  }

  static String _eventKey(String eventTypeId, DateTime d) {
    return '$eventTypeId|${_dateKey(d)}';
  }

  static String _eventTypeFromEventKey(String key) {
    final sep = key.indexOf('|');
    if (sep <= 0) return '';
    return key.substring(0, sep);
  }

  static String _defaultScoreUnitForType(String typeId) {
    switch (typeId) {
      case 'war':
      case 'war_blitz':
        return 'k';
      case 'raid':
      case 'raid_blitz':
      default:
        return 'm';
    }
  }

  static Map<String, List<DateTime>> _buildEventDates() {
    final map = <String, List<DateTime>>{
      'raid_blitz': <DateTime>[],
      'raid': <DateTime>[],
      'war_blitz': <DateTime>[],
      'war': <DateTime>[],
    };
    final heroicMondays = _heroicDatesAll
        .map((d) => _dateKey(d.subtract(const Duration(days: 1))))
        .toSet();
    final start = _plannerStartMonth;
    final end = DateTime(_plannerEndMonth.year, _plannerEndMonth.month + 1, 0);
    for (DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.monday) continue;
      final friday = d.add(const Duration(days: 4));
      final isRaidWeek = heroicMondays.contains(_dateKey(d));
      if (isRaidWeek) {
        map['raid_blitz']!.add(d);
        if (!friday.isAfter(end)) {
          map['raid']!.add(friday);
        }
      } else {
        map['war_blitz']!.add(d);
        if (!friday.isAfter(end)) {
          map['war']!.add(friday);
        }
      }
    }
    return map;
  }

  static List<DateTime> _eventDatesForMonth(
      String typeId, int year, int month) {
    final list = _eventDatesAll[typeId] ?? const <DateTime>[];
    return list.where((d) => d.year == year && d.month == month).toList();
  }

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _monthKey(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  static String _elementForMonthDate(DateTime date) {
    final offset = _monthsBetween(_cycleAnchorStartMonth, date);
    final idx = (offset % _elementCycle.length + _elementCycle.length) %
        _elementCycle.length;
    return _elementCycle[idx];
  }

  static bool _isCycleStart(DateTime date) {
    final offset = _monthsBetween(_cycleAnchorStartMonth, date);
    return (offset % _elementCycle.length) == 0;
  }

  static int _cycleNumberForMonth(DateTime date) {
    final offset = _monthsBetween(_cycleAnchorStartMonth, date);
    final cycleOffset = offset ~/ _elementCycle.length;
    return _cycleAnchorNumber + cycleOffset;
  }

  String t(String key, String fallback) => i18n?.t(key, fallback) ?? fallback;

  I18n? get i18n => widget.i18n;

  Map<String, Object?> _exportPlannerState() {
    return <String, Object?>{
      'settings': <String, Object?>{
        'showHiddenMonths': _showHiddenMonths,
        'plannerLocked': _plannerLocked,
        'hiddenMonthKeys': _hiddenMonthKeys.toList(growable: false),
      },
      'months': <Object?>[
        for (final month in _months)
          <String, Object?>{
            'monthKey': month.monthKey,
            'year': month.year,
            'month': month.month,
            'flags': <String, Object?>{
              for (final e in month.flags.entries) e.key: e.value,
            },
            'bonusFlags': <String, Object?>{
              for (final e in month.bonusFlags.entries) e.key: e.value,
            },
            'craftFlags': <String, Object?>{
              for (final e in month.craftFlags.entries) e.key: e.value,
            },
            'monthLocked': month.locked,
            'heroicFlags': <String, Object?>{
              for (final e in month.heroicFlags.entries) e.key: e.value,
            },
            'scoreInputs': <String, Object?>{
              for (final e in month.scoreInputs.entries) e.key: e.value,
            },
            'scoreUnits': <String, Object?>{
              for (final e in month.scoreUnits.entries) e.key: e.value,
            },
            'guildPlacementInputs': <String, Object?>{
              for (final e in month.guildPlacementInputs.entries)
                e.key: e.value,
            },
            'individualPlacementInputs': <String, Object?>{
              for (final e in month.individualPlacementInputs.entries)
                e.key: e.value,
            },
          },
      ],
    };
  }

  Future<void> _persistPlannerState() async {
    await UaPlannerStorage.save(_exportPlannerState());
  }

  Map<String, Object?> _exportPlannerPayload() {
    return <String, Object?>{
      'kind': _plannerExportKind,
      'v': _plannerExportVersion,
      'exportedAtIso': DateTime.now().toUtc().toIso8601String(),
      'state': _exportPlannerState(),
    };
  }

  Map<String, Object?>? _decodePlannerImportPayload(String rawText) {
    final raw = rawText.trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = decoded.cast<String, Object?>();
      if (map['months'] is List) {
        return map;
      }
      if (map['kind'] == _plannerExportKind && map['state'] is Map) {
        return (map['state'] as Map).cast<String, Object?>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _resetMonthState(_UaMonth month) {
    for (final key in month.flags.keys) {
      month.flags[key] = false;
    }
    for (final key in month.bonusFlags.keys) {
      month.bonusFlags[key] = false;
    }
    for (final key in month.craftFlags.keys) {
      month.craftFlags[key] = false;
    }
    month.locked = false;
    for (final key in month.heroicFlags.keys) {
      month.heroicFlags[key] = false;
    }
    for (final key in month.scoreInputs.keys) {
      month.scoreInputs[key] = '';
      month.scoreUnits[key] =
          _defaultScoreUnitForType(_eventTypeFromEventKey(key));
    }
    for (final key in month.guildPlacementInputs.keys) {
      month.guildPlacementInputs[key] = '';
    }
    for (final key in month.individualPlacementInputs.keys) {
      month.individualPlacementInputs[key] = '';
    }
  }

  void _applyPlannerState(Map<String, Object?> raw) {
    _showHiddenMonths = false;
    _plannerLocked = false;
    _hiddenMonthKeys.clear();
    for (final month in _months) {
      _resetMonthState(month);
    }

    final monthList = (raw['months'] as List?)?.cast<Object?>() ?? const [];
    final monthByKey = <String, _UaMonth>{
      for (final m in _months) m.monthKey: m,
    };
    final settings = (raw['settings'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    _showHiddenMonths = settings['showHiddenMonths'] == true;
    _plannerLocked = settings['plannerLocked'] == true;
    _hiddenMonthKeys.addAll(
      ((settings['hiddenMonthKeys'] as List?)?.cast<Object?>() ??
              const <Object?>[])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty),
    );

    for (final item in monthList) {
      final map = (item as Map?)?.cast<String, Object?>();
      if (map == null) continue;
      final rawMonthKey = (map['monthKey'] ?? '').toString().trim();
      _UaMonth? target;
      if (rawMonthKey.isNotEmpty) {
        target = monthByKey[rawMonthKey];
      }
      if (target == null) {
        // Backward compatibility (old save format with 2026 month index).
        final legacyMonth = ((map['month'] as num?)?.toInt() ?? 0);
        if (legacyMonth >= 1 && legacyMonth <= 12) {
          final key = _monthKey(2026, legacyMonth);
          target = monthByKey[key];
        }
      }
      if (target == null) continue;

      final flags = (map['flags'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      for (final field in _fields) {
        target.flags[field.id] = flags[field.id] == true;
      }

      final bonusFlags = (map['bonusFlags'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      for (final rule in _bonusRules) {
        target.bonusFlags[rule.id] = bonusFlags[rule.id] == true;
      }

      target.locked = map['monthLocked'] == true;

      final craftFlags = (map['craftFlags'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      for (final rule in _craftRules) {
        target.craftFlags[rule.id] = craftFlags[rule.id] == true;
      }

      final heroicFlags =
          (map['heroicFlags'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{};
      for (final key in target.heroicFlags.keys) {
        target.heroicFlags[key] = heroicFlags[key] == true;
      }

      final scoreInputs =
          (map['scoreInputs'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{};
      for (final key in target.scoreInputs.keys) {
        target.scoreInputs[key] = scoreInputs[key]?.toString() ?? '';
      }
      final scoreUnits = (map['scoreUnits'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final validUnitIds = _scoreUnits.map((u) => u.id).toSet();
      for (final key in target.scoreUnits.keys) {
        final rawUnit = scoreUnits[key]?.toString() ?? '';
        if (validUnitIds.contains(rawUnit)) {
          target.scoreUnits[key] = rawUnit;
        } else {
          target.scoreUnits[key] =
              _defaultScoreUnitForType(_eventTypeFromEventKey(key));
        }
      }

      final guildPlacementInputs =
          (map['guildPlacementInputs'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{};
      for (final key in target.guildPlacementInputs.keys) {
        target.guildPlacementInputs[key] =
            guildPlacementInputs[key]?.toString() ?? '';
      }

      final individualPlacementInputs =
          (map['individualPlacementInputs'] as Map?)?.cast<String, Object?>() ??
              const <String, Object?>{};
      for (final key in target.individualPlacementInputs.keys) {
        target.individualPlacementInputs[key] =
            individualPlacementInputs[key]?.toString() ?? '';
      }

      if (!(target.flags['heroic'] ?? false)) {
        for (final key in target.heroicFlags.keys) {
          target.heroicFlags[key] = false;
        }
      }
      _normalizeCraftFlags(target);
    }

    for (final ctl in _inputControllers.values) {
      ctl.dispose();
    }
    _inputControllers.clear();
  }

  Future<void> _restorePlannerState() async {
    final raw = await UaPlannerStorage.load();
    if (!mounted || raw == null) return;

    setState(() {
      _applyPlannerState(raw);
    });
  }

  bool _isMonthHidden(_UaMonth month) =>
      _hiddenMonthKeys.contains(month.monthKey);

  bool _isMonthLocked(_UaMonth month) => month.locked;

  bool _isMonthEditable(_UaMonth month) => !_plannerLocked && !month.locked;

  bool _isMonthIncludedInTotals(_UaMonth month) => true;

  void _setMonthHidden(_UaMonth month, bool value) {
    if (_plannerLocked) return;
    if (value) {
      _hiddenMonthKeys.add(month.monthKey);
    } else {
      _hiddenMonthKeys.remove(month.monthKey);
    }
    unawaited(_persistPlannerState());
  }

  void _setMonthLocked(_UaMonth month, bool value) {
    if (_plannerLocked) return;
    month.locked = value;
    unawaited(_persistPlannerState());
  }

  Future<void> _exportPlannerToClipboard() async {
    final payload = jsonEncode(_exportPlannerPayload());
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'ua_planner.tools.export.success',
            'Planner state copied to clipboard.',
          ),
        ),
      ),
    );
  }

  Future<void> _importPlannerFromClipboard() async {
    if (_plannerLocked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'ua_planner.tools.import.locked',
              'Unlock planner before importing state.',
            ),
          ),
        ),
      );
      return;
    }
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final controller = TextEditingController(text: clip?.text ?? '');
    try {
      if (!mounted) return;
      final rawToImport = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              t('ua_planner.tools.import.title', 'Import planner state'),
            ),
            content: TextField(
              key: const ValueKey('ua_planner_import_text'),
              controller: controller,
              maxLines: 10,
              minLines: 6,
              decoration: InputDecoration(
                hintText: t(
                  'ua_planner.tools.import.hint',
                  'Paste exported planner JSON here',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t('cancel', 'Cancel')),
              ),
              TextButton(
                key: const ValueKey('ua_planner_import_apply'),
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                child: Text(t('import', 'Import')),
              ),
            ],
          );
        },
      );
      if (rawToImport == null) return;
      final decoded = _decodePlannerImportPayload(rawToImport);
      if (decoded == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'ua_planner.tools.import.error',
                'Invalid planner payload.',
              ),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _applyPlannerState(decoded);
      });
      await _persistPlannerState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'ua_planner.tools.import.success',
              'Planner state imported successfully.',
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _loadUaRuleset() async {
    try {
      final catalog = await UaPlannerRulesLoader.load();
      if (!mounted) return;
      setState(() {
        _uaRuleset = catalog.activeRuleset;
      });
    } catch (_) {
      // Keep hardcoded fallback rules if rules asset cannot be loaded.
    }
  }

  String _rulesEventIdForType(String typeId) {
    switch (typeId) {
      case 'raid':
        return 'weekend_raid';
      case 'raid_blitz':
        return 'blitz_raid';
      case 'war':
        return 'weekend_war';
      case 'war_blitz':
        return 'blitz_war';
      case 'heroic':
        return 'heroic';
      default:
        return '';
    }
  }

  UaEventRule? _eventRuleForType(String typeId) {
    final rulesEventId = _rulesEventIdForType(typeId);
    if (rulesEventId.isEmpty) return null;
    return _uaRuleset?.eventRules[rulesEventId];
  }

  UaBonusEntryRule? _bonusEntryForRule(_UaBonusRule rule) {
    final group = _uaRuleset?.bonusRules[rule.triggerFieldId];
    if (group == null || group.isEmpty) return null;
    for (final entry in group) {
      if (entry.id == rule.id) return entry;
    }
    return null;
  }

  int _bonusPieces(_UaBonusRule rule) {
    final fromRules = _bonusEntryForRule(rule)?.pieces;
    return fromRules != null && fromRules > 0 ? fromRules : rule.pieces;
  }

  String? _bonusDependsOn(_UaBonusRule rule) {
    return _bonusEntryForRule(rule)?.dependsOn ?? rule.dependsOnBonusId;
  }

  int _heroicPiecesPerRun() {
    final fromRules = _eventRuleForType('heroic')?.piecesPerCompletedHeroic;
    if (fromRules == null || fromRules <= 0) return 1;
    return fromRules;
  }

  String _monthLabel(int month) {
    switch (month) {
      case 1:
        return t('ua_planner.month.1', _monthFallbacks[0]);
      case 2:
        return t('ua_planner.month.2', _monthFallbacks[1]);
      case 3:
        return t('ua_planner.month.3', _monthFallbacks[2]);
      case 4:
        return t('ua_planner.month.4', _monthFallbacks[3]);
      case 5:
        return t('ua_planner.month.5', _monthFallbacks[4]);
      case 6:
        return t('ua_planner.month.6', _monthFallbacks[5]);
      case 7:
        return t('ua_planner.month.7', _monthFallbacks[6]);
      case 8:
        return t('ua_planner.month.8', _monthFallbacks[7]);
      case 9:
        return t('ua_planner.month.9', _monthFallbacks[8]);
      case 10:
        return t('ua_planner.month.10', _monthFallbacks[9]);
      case 11:
        return t('ua_planner.month.11', _monthFallbacks[10]);
      case 12:
        return t('ua_planner.month.12', _monthFallbacks[11]);
      default:
        return _monthFallbacks.first;
    }
  }

  String _monthYearLabel(_UaMonth month) {
    return '${_monthLabel(month.month)} ${month.year}';
  }

  String _plannerRangeLabel() {
    final first = _months.first;
    final last = _months.last;
    return '${_monthYearLabel(first)} - ${_monthYearLabel(last)}';
  }

  String _cycleRangeLabel(_UaMonth startMonth) {
    final startIndex = _months.indexOf(startMonth);
    if (startIndex < 0) return '';
    final endIndex = (startIndex + _elementCycle.length - 1).clamp(
      0,
      _months.length - 1,
    );
    final endMonth = _months[endIndex];
    return '${_monthLabel(startMonth.month)} ${startMonth.year} - ${_monthLabel(endMonth.month)} ${endMonth.year}';
  }

  TextEditingController _inputControllerFor(String key, String initialValue) {
    final existing = _inputControllers[key];
    if (existing != null) return existing;
    final ctl = TextEditingController(text: initialValue);
    _inputControllers[key] = ctl;
    return ctl;
  }

  int _parseScoreToPoints(String raw, String unitId) {
    final s = raw.trim().replaceAll(' ', '');
    if (s.isEmpty) return 0;
    if (!_scoreNumberRegExp.hasMatch(s)) return 0;
    final base = double.tryParse(s.replaceAll(',', '.')) ?? 0.0;
    if (base <= 0) return 0;
    final multiplier = _scoreUnits
        .firstWhere((u) => u.id == unitId, orElse: () => _scoreUnits[1])
        .multiplier;
    return (base * multiplier).floor();
  }

  int _parsePlacement(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.tryParse(digits) ?? 0;
  }

  int _countReachedMilestones(int points, List<int> milestones) {
    if (points <= 0) return 0;
    var out = 0;
    for (final threshold in milestones) {
      if (points >= threshold) out++;
    }
    return out;
  }

  bool _isFirstBlitzWarOfMonth(_UaMonth month, DateTime date) {
    final blitzWars = month.eventDatesByType['war_blitz'] ?? const <DateTime>[];
    if (blitzWars.isEmpty) return false;
    return _dateKey(blitzWars.first) == _dateKey(date);
  }

  int _scorePiecesForEvent(
    _UaMonth month,
    _UaEventType type,
    DateTime date,
  ) {
    final points = _scorePointsForEvent(month, type, date);
    final rule = _eventRuleForType(type.id);
    if (rule != null && rule.enabled) {
      return rule.scorePieces(
        points,
        isFirstBlitzOfMonth: _isFirstBlitzWarOfMonth(month, date),
      );
    }
    switch (type.id) {
      case 'raid':
        return _countReachedMilestones(points, const [50000000, 200000000]);
      case 'raid_blitz':
        return points >= 8200000 ? 1 : 0;
      case 'war':
        return _countReachedMilestones(
          points,
          const [105000, 260000, 475000, 931000, 1825000],
        );
      case 'war_blitz':
        var pieces = _countReachedMilestones(points, const [105000, 260000]);
        if (!_isFirstBlitzWarOfMonth(month, date) && points >= 475000) {
          pieces += 1;
        }
        return pieces;
      default:
        return 0;
    }
  }

  int _scorePointsForEvent(
    _UaMonth month,
    _UaEventType type,
    DateTime date,
  ) {
    final key = _eventKey(type.id, date);
    return _parseScoreToPoints(
      month.scoreInputs[key] ?? '',
      month.scoreUnits[key] ?? _defaultScoreUnitForType(type.id),
    );
  }

  int _guildPlacementPiecesForEvent(
    _UaMonth month,
    _UaEventType type,
    DateTime date,
  ) {
    final key = _eventKey(type.id, date);
    final rank = _parsePlacement(month.guildPlacementInputs[key] ?? '');
    final rule = _eventRuleForType(type.id);
    if (rule != null && rule.enabled) {
      return rule.guildPlacementPieces(
        rank,
        isFirstBlitzOfMonth: _isFirstBlitzWarOfMonth(month, date),
      );
    }
    if (rank <= 0) return 0;
    switch (type.id) {
      case 'raid':
        if (rank == 1) return 4;
        if (rank == 2) return 3;
        if (rank == 3) return 2;
        if (rank >= 4 && rank <= 7) return 1;
        return 0;
      case 'raid_blitz':
        return 0;
      case 'war':
        if (rank == 1) return 3;
        if (rank == 2) return 2;
        if (rank >= 3 && rank <= 10) return 1;
        return 0;
      case 'war_blitz':
        if (_isFirstBlitzWarOfMonth(month, date)) return 0;
        if (rank == 1 || rank == 2) return 1;
        return 0;
      default:
        return 0;
    }
  }

  int _individualPlacementPiecesForEvent(
    _UaMonth month,
    _UaEventType type,
    DateTime date,
  ) {
    final key = _eventKey(type.id, date);
    final rank = _parsePlacement(month.individualPlacementInputs[key] ?? '');
    final rule = _eventRuleForType(type.id);
    if (rule != null && rule.enabled) {
      return rule.individualPlacementPieces(
        rank,
        isFirstBlitzOfMonth: _isFirstBlitzWarOfMonth(month, date),
      );
    }
    if (rank <= 0) return 0;
    switch (type.id) {
      case 'raid':
        if (rank == 1) return 4;
        if (rank == 2) return 3;
        if (rank == 3) return 2;
        if (rank >= 4 && rank <= 7) return 1;
        return 0;
      case 'raid_blitz':
        if (rank == 1) return 2;
        if (rank == 2 || rank == 3) return 1;
        return 0;
      default:
        return 0;
    }
  }

  int _eventPieces(_UaMonth month, _UaEventType type, DateTime date) {
    final scorePieces = _scorePiecesForEvent(month, type, date);
    final guildPieces = _guildPlacementPiecesForEvent(month, type, date);
    final individualPieces =
        _individualPlacementPiecesForEvent(month, type, date);
    return scorePieces + guildPieces + individualPieces;
  }

  int _monthPieces(_UaMonth month) {
    if (!_isMonthIncludedInTotals(month)) return 0;
    var total = 0;
    for (final rule in _bonusRules) {
      if (month.bonusFlags[rule.id] ?? false) {
        total += _bonusPieces(rule);
      }
    }
    total +=
        month.heroicFlags.values.where((v) => v).length * _heroicPiecesPerRun();
    for (final type in _eventTypes) {
      final dates = month.eventDatesByType[type.id] ?? const <DateTime>[];
      for (final d in dates) {
        total += _eventPieces(month, type, d);
      }
    }
    return total;
  }

  int _fieldPieces(_UaMonth month, String fieldId) {
    if (!_isMonthIncludedInTotals(month)) return 0;
    if (fieldId == 'heroic') {
      return month.heroicFlags.values.where((v) => v).length *
          _heroicPiecesPerRun();
    }
    final eventType = _eventTypes.cast<_UaEventType?>().firstWhere(
          (type) => type?.fieldId == fieldId,
          orElse: () => null,
        );
    if (eventType != null) {
      var total = 0;
      final dates = month.eventDatesByType[eventType.id] ?? const <DateTime>[];
      for (final d in dates) {
        total += _eventPieces(month, eventType, d);
      }
      return total;
    }
    var total = 0;
    for (final rule
        in _bonusRules.where((rule) => rule.triggerFieldId == fieldId)) {
      if (month.bonusFlags[rule.id] ?? false) {
        total += _bonusPieces(rule);
      }
    }
    return total;
  }

  bool _isCraftUnlocked(_UaMonth month, _UaCraftRule rule) {
    return _monthPieces(month) >= rule.thresholdPieces;
  }

  void _normalizeCraftFlags(_UaMonth month) {
    for (final rule in _craftRules) {
      if (!_isCraftUnlocked(month, rule)) {
        month.craftFlags[rule.id] = false;
      }
    }
  }

  int _cycleCraftCount(_UaMonth startMonth, String craftId) {
    final startIndex = _months.indexOf(startMonth);
    if (startIndex < 0) return 0;
    final endExclusive =
        (startIndex + _elementCycle.length).clamp(0, _months.length);
    var total = 0;
    for (int i = startIndex; i < endExclusive; i++) {
      final month = _months[i];
      if (!_isMonthIncludedInTotals(month)) continue;
      if (month.craftFlags[craftId] ?? false) total += 1;
    }
    return total;
  }

  String _elementCraftLabel(_UaMonth month, _UaCraftRule rule) {
    return '${_elementLabel(month.elementId)} ${t(rule.labelKey, rule.fallback)}';
  }

  bool _isFirstBlitzWarSpecialRewardBlock(
    _UaMonth month,
    _UaEventType type,
    DateTime date,
  ) {
    return type.id == 'war_blitz' && _isFirstBlitzWarOfMonth(month, date);
  }

  String _elementLabel(String elementId) {
    switch (elementId) {
      case 'fire':
        return t('element.fire', 'Fire');
      case 'spirit':
        return t('element.spirit', 'Spirit');
      case 'earth':
        return t('element.earth', 'Earth');
      case 'air':
        return t('element.air', 'Air');
      case 'water':
        return t('element.water', 'Water');
      default:
        return elementId;
    }
  }

  Color _elementColor(BuildContext context, String elementId) {
    switch (elementId) {
      case 'fire':
        return const Color(0xFFE45745);
      case 'spirit':
        return const Color(0xFF9B59B6);
      case 'earth':
        return const Color(0xFF8D6E63);
      case 'air':
        return const Color(0xFFB0BEC5);
      case 'water':
        return const Color(0xFF4A90E2);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _statusRow({
    required BuildContext context,
    required String title,
    required bool ready,
    required int missing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = ready
        ? t('ua_planner.status.ready', 'Ready')
        : '${t('ua_planner.status.missing', 'Missing')} $missing';
    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle : Icons.info_outline,
          size: 16,
          color: ready ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$title: $status',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyBadge({
    required ThemeData theme,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color foregroundColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleMonthMiniCard({
    required BuildContext context,
    required ThemeData theme,
    required _UaMonth month,
  }) {
    final included = _isMonthIncludedInTotals(month);
    final eliteCrafted = included && (month.craftFlags['elite'] ?? false);
    final elitePlusCrafted =
        included && (month.craftFlags['elite_plus'] ?? false);
    final color = _elementColor(context, month.elementId);
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthLabel(month.month),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _elementLabel(month.elementId),
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                eliteCrafted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 14,
                color: eliteCrafted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t('ua_planner.elite', 'Elite'),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                elitePlusCrafted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 14,
                color: elitePlusCrafted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  t('ua_planner.elite_plus', 'Elite+'),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_UaBonusRule> _visibleBonusRules(_UaMonth month) {
    return _bonusRules
        .where((rule) => month.flags[rule.triggerFieldId] ?? false)
        .toList();
  }

  void _setFieldFlag(_UaMonth month, String fieldId, bool value) {
    if (!_isMonthEditable(month)) return;
    month.flags[fieldId] = value;
    _normalizeCraftFlags(month);
    unawaited(_persistPlannerState());
  }

  void _setBonusFlag(_UaMonth month, _UaBonusRule rule, bool value) {
    if (!_isMonthEditable(month)) return;
    if (value) {
      final dependsOn = _bonusDependsOn(rule);
      if (dependsOn != null && !(month.bonusFlags[dependsOn] ?? false)) {
        return;
      }
      month.bonusFlags[rule.id] = true;
      _normalizeCraftFlags(month);
      unawaited(_persistPlannerState());
      return;
    }
    month.bonusFlags[rule.id] = false;
    for (final child
        in _bonusRules.where((r) => _bonusDependsOn(r) == rule.id)) {
      month.bonusFlags[child.id] = false;
    }
    _normalizeCraftFlags(month);
    unawaited(_persistPlannerState());
  }

  void _setHeroicFlag(_UaMonth month, String dateKey, bool value) {
    if (!_isMonthEditable(month)) return;
    month.heroicFlags[dateKey] = value;
    _normalizeCraftFlags(month);
    unawaited(_persistPlannerState());
  }

  void _setCraftFlag(_UaMonth month, _UaCraftRule rule, bool value) {
    if (!_isMonthEditable(month)) return;
    if (!_isCraftUnlocked(month, rule)) {
      month.craftFlags[rule.id] = false;
      return;
    }
    month.craftFlags[rule.id] = value;
    unawaited(_persistPlannerState());
  }

  void _clearMonth(_UaMonth month) {
    if (_plannerLocked) return;
    for (final key in month.flags.keys) {
      month.flags[key] = false;
    }
    for (final key in month.bonusFlags.keys) {
      month.bonusFlags[key] = false;
    }
    for (final key in month.craftFlags.keys) {
      month.craftFlags[key] = false;
    }
    month.locked = false;
    for (final key in month.heroicFlags.keys) {
      month.heroicFlags[key] = false;
    }
    for (final key in month.scoreInputs.keys) {
      month.scoreInputs[key] = '';
      month.scoreUnits[key] =
          _defaultScoreUnitForType(_eventTypeFromEventKey(key));
      _inputControllers['score|$key']?.clear();
    }
    for (final key in month.guildPlacementInputs.keys) {
      month.guildPlacementInputs[key] = '';
      _inputControllers['guild|$key']?.clear();
    }
    for (final key in month.individualPlacementInputs.keys) {
      month.individualPlacementInputs[key] = '';
      _inputControllers['individual|$key']?.clear();
    }
    unawaited(_persistPlannerState());
  }

  Future<void> _showMonthTip(_UaMonth month) async {
    final body = t(
      'ua_planner.month.tip.body',
      'Toggle buttons enable related monthly sections. Pieces are counted only from selected rows inside the tables (Heroic, Headstart, EB Collection), not from the buttons themselves.',
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            '${t('ua_planner.month.tip.title', 'Month tip')} - ${_monthYearLabel(month)}',
          ),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t('cancel', 'Cancel')),
            ),
          ],
        );
      },
    );
  }

  String _bonusGroupTitle(String groupId) {
    switch (groupId) {
      case 'headstart':
        return t('ua_planner.field.headstart', 'Headstart');
      case 'eb_collection':
        return t('ua_planner.field.eb_collection', 'EB Collection');
      default:
        return groupId;
    }
  }

  Widget _buildBonusRow({
    required BuildContext context,
    required ThemeData theme,
    required _UaMonth month,
    required _UaBonusRule rule,
  }) {
    final checked = month.bonusFlags[rule.id] ?? false;
    final dependsOn = _bonusDependsOn(rule);
    final enabled = _isMonthEditable(month) &&
        (dependsOn == null || (month.bonusFlags[dependsOn] ?? false));
    return Row(
      children: [
        Checkbox(
          key: ValueKey('ua_bonus_${month.monthKey}_${rule.id}'),
          value: checked,
          visualDensity: VisualDensity.compact,
          onChanged: enabled
              ? (value) {
                  setState(() {
                    _setBonusFlag(
                      month,
                      rule,
                      value ?? false,
                    );
                  });
                }
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              t(rule.labelKey, rule.fallback),
              style: theme.textTheme.bodySmall?.copyWith(
                color: enabled ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            '+${_bonusPieces(rule)}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBonusGroup({
    required BuildContext context,
    required ThemeData theme,
    required _UaMonth month,
    required String groupId,
  }) {
    final rules =
        _bonusRules.where((r) => r.triggerFieldId == groupId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          child: Text(
            _bonusGroupTitle(groupId),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (int i = 0; i < rules.length; i++) ...[
          if (i > 0) Divider(height: 1, color: theme.dividerColor),
          _buildBonusRow(
            context: context,
            theme: theme,
            month: month,
            rule: rules[i],
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    String? trailing,
  }) {
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          if (trailing != null && trailing.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              trailing,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroicRow({
    required BuildContext context,
    required ThemeData theme,
    required _UaMonth month,
    required DateTime date,
    required int index,
  }) {
    final key = _dateKey(date);
    final checked = month.heroicFlags[key] ?? false;
    return Row(
      children: [
        Checkbox(
          key: ValueKey('ua_heroic_${month.monthKey}_$key'),
          value: checked,
          visualDensity: VisualDensity.compact,
          onChanged: !_isMonthEditable(month)
              ? null
              : (value) {
                  setState(() {
                    _setHeroicFlag(month, key, value ?? false);
                  });
                },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${t('ua_planner.field.heroic', 'Heroic')} ${index + 1} - ${MaterialLocalizations.of(context).formatMediumDate(date)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            '+${_heroicPiecesPerRun()}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialRewardRow({
    required ThemeData theme,
    required String label,
    required int quantity,
    required bool earned,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Icon(
            earned ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: earned
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quantity > 1 ? '$label x$quantity' : label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text(
            earned
                ? t('ua_planner.reward.earned', 'Earned')
                : t('ua_planner.reward.missing', 'Missing'),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: earned
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCraftRow({
    required ThemeData theme,
    required _UaMonth month,
    required _UaCraftRule rule,
  }) {
    final checked = month.craftFlags[rule.id] ?? false;
    final unlocked = _isCraftUnlocked(month, rule);
    final enabled = _isMonthEditable(month) && unlocked;
    return Row(
      children: [
        Checkbox(
          key: ValueKey('ua_craft_${month.monthKey}_${rule.id}'),
          value: checked,
          visualDensity: VisualDensity.compact,
          onChanged: enabled
              ? (value) {
                  setState(() {
                    _setCraftFlag(month, rule, value ?? false);
                  });
                }
              : null,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              _elementCraftLabel(month, rule),
              style: theme.textTheme.bodySmall?.copyWith(
                color: unlocked ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            unlocked
                ? '+1'
                : '${rule.thresholdPieces} ${t('ua_planner.craft.pieces_required_suffix', 'pieces required')}',
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: unlocked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventInputRow({
    required ThemeData theme,
    required String label,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
    required int pieces,
    List<TextInputFormatter>? inputFormatters,
    String? unitId,
    ValueChanged<String>? onUnitChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: onUnitChanged == null ? 94 : 82,
            child: TextField(
              controller: controller,
              enabled: enabled,
              readOnly: !enabled,
              keyboardType: TextInputType.number,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: enabled ? onChanged : null,
            ),
          ),
          if (onUnitChanged != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 62,
              child: DropdownButtonFormField<String>(
                initialValue: unitId,
                isDense: true,
                items: [
                  for (final unit in _scoreUnits)
                    DropdownMenuItem<String>(
                      value: unit.id,
                      child: Text(unit.label),
                    ),
                ],
                onChanged: (value) {
                  if (!enabled) return;
                  if (value != null) onUnitChanged(value);
                },
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '+$pieces',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDateBlock({
    required BuildContext context,
    required ThemeData theme,
    required _UaMonth month,
    required _UaEventType type,
    required DateTime date,
    required int index,
  }) {
    final key = _eventKey(type.id, date);
    final editable = _isMonthEditable(month);
    final scorePoints = _scorePointsForEvent(month, type, date);
    final scorePieces = _scorePiecesForEvent(month, type, date);
    final guildPieces = _guildPlacementPiecesForEvent(month, type, date);
    final individualPieces = _individualPlacementPiecesForEvent(
      month,
      type,
      date,
    );
    final blockTotal = scorePieces +
        guildPieces +
        (type.includeIndividualPlacement ? individualPieces : 0);
    final showFirstBlitzRewards =
        _isFirstBlitzWarSpecialRewardBlock(month, type, date);

    return Container(
      margin: EdgeInsets.only(
          bottom: index == (month.eventDatesByType[type.id]?.length ?? 1) - 1
              ? 0
              : 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.28),
            child: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(date)} - ${t('ua_planner.event.total', 'Total')}: +$blockTotal',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _buildEventInputRow(
            theme: theme,
            label: t('ua_planner.event.score', 'Score'),
            controller:
                _inputControllerFor('score|$key', month.scoreInputs[key] ?? ''),
            hint: '500',
            onChanged: (v) {
              setState(() {
                month.scoreInputs[key] = v;
                _normalizeCraftFlags(month);
                unawaited(_persistPlannerState());
              });
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(_scoreNumberRegExp),
            ],
            unitId: month.scoreUnits[key] ?? _defaultScoreUnitForType(type.id),
            onUnitChanged: (unit) {
              setState(() {
                month.scoreUnits[key] = unit;
                _normalizeCraftFlags(month);
                unawaited(_persistPlannerState());
              });
            },
            enabled: editable,
            pieces: scorePieces,
          ),
          if (showFirstBlitzRewards) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Text(
                t(
                  'ua_planner.reward.first_blitz.title',
                  'First Blitz War rewards',
                ),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final reward in _firstBlitzWarRewards)
              _buildSpecialRewardRow(
                theme: theme,
                label: t(reward.labelKey, reward.fallback),
                quantity: reward.quantity,
                earned: scorePoints >= reward.minPoints,
              ),
          ],
          Divider(height: 1, color: theme.dividerColor),
          _buildEventInputRow(
            theme: theme,
            label: t('ua_planner.event.guild_placement', 'Guild placement'),
            controller: _inputControllerFor(
              'guild|$key',
              month.guildPlacementInputs[key] ?? '',
            ),
            hint: '#1',
            onChanged: (v) {
              setState(() {
                month.guildPlacementInputs[key] = v;
                _normalizeCraftFlags(month);
                unawaited(_persistPlannerState());
              });
            },
            enabled: editable,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            pieces: guildPieces,
          ),
          if (type.includeIndividualPlacement) ...[
            Divider(height: 1, color: theme.dividerColor),
            _buildEventInputRow(
              theme: theme,
              label: t(
                'ua_planner.event.individual_placement',
                'Individual placement',
              ),
              controller: _inputControllerFor(
                'individual|$key',
                month.individualPlacementInputs[key] ?? '',
              ),
              hint: '#1',
              onChanged: (v) {
                setState(() {
                  month.individualPlacementInputs[key] = v;
                  _normalizeCraftFlags(month);
                  unawaited(_persistPlannerState());
                });
              },
              enabled: editable,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              pieces: individualPieces,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventSection({
    required BuildContext context,
    required ThemeData theme,
    required _UaMonth month,
    required _UaEventType type,
  }) {
    final dates = month.eventDatesByType[type.id] ?? const <DateTime>[];
    if (dates.isEmpty) return const SizedBox.shrink();
    final subtotal = dates.fold<int>(
        0, (acc, date) => acc + _eventPieces(month, type, date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context: context,
          theme: theme,
          title: t(type.labelKey, type.fallback),
          trailing: '${t('ua_planner.event.total', 'Total')}: +$subtotal',
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < dates.length; i++)
          _buildEventDateBlock(
            context: context,
            theme: theme,
            month: month,
            type: type,
            date: dates[i],
            index: i,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('nav.ua_planner', 'UA Planner')),
        actions: [
          IconButton(
            key: const ValueKey('ua_planner_lock'),
            tooltip: _plannerLocked
                ? t('ua_planner.lock.tooltip.unlock', 'Unlock planner')
                : t('ua_planner.lock.tooltip.lock', 'Lock planner'),
            visualDensity: VisualDensity.compact,
            icon: Icon(_plannerLocked ? Icons.lock : Icons.lock_open),
            onPressed: () {
              setState(() {
                _plannerLocked = !_plannerLocked;
              });
              unawaited(_persistPlannerState());
            },
          ),
          PopupMenuButton<String>(
            key: const ValueKey('ua_planner_tools'),
            tooltip: t('ua_planner.tools.tooltip', 'Planner tools'),
            onSelected: (value) {
              if (value == 'export') {
                unawaited(_exportPlannerToClipboard());
              } else if (value == 'import') {
                unawaited(_importPlannerFromClipboard());
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'export',
                child: Text(
                  t(
                    'ua_planner.tools.export',
                    'Export planner state',
                  ),
                ),
              ),
              PopupMenuItem<String>(
                value: 'import',
                enabled: !_plannerLocked,
                child: Text(
                  t(
                    'ua_planner.tools.import',
                    'Import planner state',
                  ),
                ),
              ),
            ],
          ),
          AppBarShortcutsMenuButton(
            buttonKey: const ValueKey('app-shortcuts-menu'),
            tooltip: t('shortcuts.menu.tooltip', 'Quick actions'),
            title: t('shortcuts.menu.title', 'Quick actions'),
            items: [
              AppShortcutSheetItem(
                icon: widget.isPremium ? Icons.star : Icons.star_border,
                iconColor: widget.isPremium ? theme.colorScheme.primary : null,
                label: widget.isPremium
                    ? t('premium.active', 'Premium active')
                    : t('premium.inactive', 'Premium inactive'),
                onTap: widget.onOpenPremium,
              ),
              AppShortcutSheetItem(
                icon: Icons.history,
                label: t('results.last', 'Last results'),
                onTap: widget.onOpenLastResults,
              ),
              AppShortcutSheetItem(
                icon: Icons.palette_outlined,
                label: t('theme.tooltip', 'Themes'),
                onTap: widget.onOpenTheme,
              ),
              AppShortcutSheetItem(
                icon: Icons.public,
                label: t('lang', 'Language'),
                onTap: widget.onOpenLanguage,
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('ua_planner.summary.title', 'UA Calendar'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _plannerRangeLabel(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(
                      'ua_planner.summary.monthly_rule',
                      'Progress is calculated month by month. Elite requires 10 pieces in the same month, Elite+ requires 20.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_plannerLocked)
                    Text(
                      t(
                        'ua_planner.lock.enabled',
                        'Planner is locked. Unlock to edit values.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t(
                            'ua_planner.show_hidden_months',
                            'Show hidden months',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Switch(
                        key: const ValueKey('ua_show_hidden_months'),
                        value: _showHiddenMonths,
                        onChanged: (value) {
                          setState(() {
                            _showHiddenMonths = value;
                          });
                          unawaited(_persistPlannerState());
                        },
                      ),
                    ],
                  ),
                  Text(
                    t(
                      'ua_planner.summary.hidden_behavior',
                      'Hidden months stay counted in totals. Lock only prevents edits.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final month in _months)
            Builder(
              builder: (context) {
                final isHidden = _isMonthHidden(month);
                if (isHidden && !_showHiddenMonths) {
                  return const SizedBox.shrink();
                }
                final visibleBonusRules = _visibleBonusRules(month);
                final monthPieces = _monthPieces(month);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (month.isCycleStart) ...[
                      Builder(
                        builder: (context) {
                          final eliteCount = _cycleCraftCount(month, 'elite');
                          final elitePlusCount =
                              _cycleCraftCount(month, 'elite_plus');
                          final cs = theme.colorScheme;
                          final uaBadgeLabel = elitePlusCount >= 5
                              ? t(
                                  'ua_planner.ua.badge.upgraded_ready',
                                  'Upgraded UA Set Ready',
                                )
                              : eliteCount >= 5
                                  ? t(
                                      'ua_planner.ua.badge.ready',
                                      'UA Ready',
                                    )
                                  : 'UA $eliteCount/5';
                          final uaBadgeBackground = elitePlusCount >= 5
                              ? cs.tertiaryContainer.withValues(alpha: 0.82)
                              : eliteCount >= 5
                                  ? cs.primaryContainer.withValues(alpha: 0.78)
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: 0.55);
                          final uaBadgeBorder = elitePlusCount >= 5
                              ? cs.tertiary.withValues(alpha: 0.7)
                              : eliteCount >= 5
                                  ? cs.primary.withValues(alpha: 0.7)
                                  : cs.outlineVariant;
                          final uaBadgeForeground = elitePlusCount >= 5
                              ? cs.tertiary
                              : eliteCount >= 5
                                  ? cs.primary
                                  : cs.onSurfaceVariant;
                          final uaBadgeIcon = elitePlusCount >= 5
                              ? Icons.workspace_premium
                              : eliteCount >= 5
                                  ? Icons.check_circle
                                  : Icons.schedule;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t('ua_planner.cycle.title', 'UA Cycle')} ${month.cycleNumber}',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          _cycleRangeLabel(month),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildReadyBadge(
                                              theme: theme,
                                              label: uaBadgeLabel,
                                              backgroundColor:
                                                  uaBadgeBackground,
                                              borderColor: uaBadgeBorder,
                                              foregroundColor:
                                                  uaBadgeForeground,
                                              icon: uaBadgeIcon,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${t('ua_planner.ua.progress', 'UA progress')}: $eliteCount / 5',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          eliteCount >= 5
                                              ? t(
                                                  'ua_planner.ua.ready',
                                                  'UA ready',
                                                )
                                              : '${t('ua_planner.status.missing', 'Missing')} ${5 - eliteCount}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: eliteCount >= 5
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${t('ua_planner.ua_plus.progress', 'Upgraded UA progress')}: $elitePlusCount / 5',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          elitePlusCount >= 5
                                              ? t(
                                                  'ua_planner.ua_plus.ready',
                                                  'Upgraded UA ready',
                                                )
                                              : '${t('ua_planner.status.missing', 'Missing')} ${5 - elitePlusCount}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: elitePlusCount >= 5
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          t(
                                            'ua_planner.cycle.elements.title',
                                            'Cycle elements',
                                          ),
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            for (int i = _months.indexOf(month);
                                                i <
                                                        (_months.indexOf(
                                                                month) +
                                                            _elementCycle
                                                                .length) &&
                                                    i < _months.length;
                                                i++)
                                              _buildCycleMonthMiniCard(
                                                context: context,
                                                theme: theme,
                                                month: _months[i],
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (isHidden) ...[
                      Card(
                        key: ValueKey('ua_month_card_${month.monthKey}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _monthYearLabel(month),
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      t(
                                        'ua_planner.month.hidden.badge',
                                        'Hidden',
                                      ),
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t(
                                  'ua_planner.month.hidden.description.counted',
                                  'Hidden month. Still counted in totals.',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${t('ua_planner.month_pieces', 'Pieces this month')}: $monthPieces',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    key: ValueKey(
                                      'ua_month_lock_${month.monthKey}',
                                    ),
                                    label: Text(
                                      _isMonthLocked(month)
                                          ? t(
                                              'ua_planner.month.lock.tooltip.unlock',
                                              'Unlock month',
                                            )
                                          : t(
                                              'ua_planner.month.lock.tooltip.lock',
                                              'Lock month',
                                            ),
                                    ),
                                    selected: _isMonthLocked(month),
                                    avatar: Icon(
                                      _isMonthLocked(month)
                                          ? Icons.lock
                                          : Icons.lock_open,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: _plannerLocked
                                        ? null
                                        : (_) {
                                            setState(() {
                                              _setMonthLocked(month,
                                                  !_isMonthLocked(month));
                                            });
                                          },
                                  ),
                                  ActionChip(
                                    key: ValueKey(
                                      'ua_month_hidden_${month.monthKey}',
                                    ),
                                    label: Text(
                                      t(
                                        'ua_planner.month.hidden.tooltip.unhide',
                                        'Unhide month',
                                      ),
                                    ),
                                    avatar: const Icon(
                                      Icons.visibility,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _plannerLocked
                                        ? null
                                        : () {
                                            setState(() {
                                              _setMonthHidden(month, false);
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
                      Card(
                        key: ValueKey('ua_month_card_${month.monthKey}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _monthYearLabel(month),
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      _elementLabel(month.elementId),
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    backgroundColor:
                                        _elementColor(context, month.elementId),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ActionChip(
                                    key: ValueKey(
                                        'ua_month_tip_${month.monthKey}'),
                                    label: Text(
                                      t(
                                        'ua_planner.month.tip.tooltip',
                                        'Month tip',
                                      ),
                                    ),
                                    avatar: const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _showMonthTip(month),
                                  ),
                                  FilterChip(
                                    key: ValueKey(
                                        'ua_month_lock_${month.monthKey}'),
                                    label: Text(
                                      _isMonthLocked(month)
                                          ? t(
                                              'ua_planner.month.lock.tooltip.unlock',
                                              'Unlock month',
                                            )
                                          : t(
                                              'ua_planner.month.lock.tooltip.lock',
                                              'Lock month',
                                            ),
                                    ),
                                    selected: _isMonthLocked(month),
                                    avatar: Icon(
                                      _isMonthLocked(month)
                                          ? Icons.lock
                                          : Icons.lock_open,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: _plannerLocked
                                        ? null
                                        : (_) {
                                            setState(() {
                                              _setMonthLocked(
                                                month,
                                                !_isMonthLocked(month),
                                              );
                                            });
                                          },
                                  ),
                                  ActionChip(
                                    key: ValueKey(
                                      'ua_month_hidden_${month.monthKey}',
                                    ),
                                    label: Text(
                                      t(
                                        'ua_planner.month.hidden.tooltip.hide',
                                        'Hide month',
                                      ),
                                    ),
                                    avatar: const Icon(
                                      Icons.visibility_off,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _plannerLocked
                                        ? null
                                        : () {
                                            setState(() {
                                              _setMonthHidden(month, true);
                                            });
                                          },
                                  ),
                                  ActionChip(
                                    key: ValueKey(
                                        'ua_month_clear_${month.monthKey}'),
                                    label: Text(
                                      t(
                                        'ua_planner.month.clear.tooltip',
                                        'Clear this month',
                                      ),
                                    ),
                                    avatar: const Icon(
                                      Icons.cleaning_services_outlined,
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    onPressed:
                                        _plannerLocked || _isMonthLocked(month)
                                            ? null
                                            : () {
                                                setState(() {
                                                  _clearMonth(month);
                                                });
                                              },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${t('ua_planner.month_pieces', 'Pieces this month')}: $monthPieces',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_isMonthLocked(month)) ...[
                                const SizedBox(height: 4),
                                Text(
                                  t(
                                    'ua_planner.month.lock.enabled.simple',
                                    'Month is locked. Unlock it to edit this month.',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              _statusRow(
                                context: context,
                                title: t('ua_planner.elite', 'Elite'),
                                ready: monthPieces >= 10,
                                missing:
                                    monthPieces >= 10 ? 0 : (10 - monthPieces),
                              ),
                              const SizedBox(height: 6),
                              _statusRow(
                                context: context,
                                title: t('ua_planner.elite_plus', 'Elite+'),
                                ready: monthPieces >= 20,
                                missing:
                                    monthPieces >= 20 ? 0 : (20 - monthPieces),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final field in _fields)
                                    () {
                                      final fieldPieces =
                                          _fieldPieces(month, field.id);
                                      final label =
                                          t(field.labelKey, field.fallback);
                                      final summaryLabel = fieldPieces > 0
                                          ? '$label (+$fieldPieces)'
                                          : label;
                                      return FilterChip(
                                        key: ValueKey(
                                          'ua_field_${month.monthKey}_${field.id}',
                                        ),
                                        label: Text(summaryLabel),
                                        selected:
                                            month.flags[field.id] ?? false,
                                        visualDensity: VisualDensity.compact,
                                        onSelected: !_isMonthEditable(month)
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _setFieldFlag(
                                                      month, field.id, value);
                                                });
                                              },
                                      );
                                    }(),
                                ],
                              ),
                              if (month.flags['heroic'] ?? false) ...[
                                const SizedBox(height: 10),
                                _buildSectionHeader(
                                  context: context,
                                  theme: theme,
                                  title: t(
                                    'ua_planner.heroic.title',
                                    'Heroic runs this month',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: theme.dividerColor),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      for (int i = 0;
                                          i < month.heroicDates.length;
                                          i++) ...[
                                        if (i > 0)
                                          Divider(
                                              height: 1,
                                              color: theme.dividerColor),
                                        _buildHeroicRow(
                                          context: context,
                                          theme: theme,
                                          month: month,
                                          date: month.heroicDates[i],
                                          index: i,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              for (final eventType in _eventTypes)
                                if (month.flags[eventType.fieldId] ??
                                    false) ...[
                                  const SizedBox(height: 10),
                                  _buildEventSection(
                                    context: context,
                                    theme: theme,
                                    month: month,
                                    type: eventType,
                                  ),
                                ],
                              if (visibleBonusRules.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _buildSectionHeader(
                                  context: context,
                                  theme: theme,
                                  title: t('ua_planner.bonus.title',
                                      'Monthly bonus checks'),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: theme.dividerColor),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      if (month.flags['headstart'] ?? false)
                                        _buildBonusGroup(
                                          context: context,
                                          theme: theme,
                                          month: month,
                                          groupId: 'headstart',
                                        ),
                                      if ((month.flags['headstart'] ?? false) &&
                                          (month.flags['eb_collection'] ??
                                              false))
                                        Divider(
                                            height: 1,
                                            color: theme.dividerColor),
                                      if (month.flags['eb_collection'] ?? false)
                                        _buildBonusGroup(
                                          context: context,
                                          theme: theme,
                                          month: month,
                                          groupId: 'eb_collection',
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_craftRules.any(
                                (rule) => _isCraftUnlocked(month, rule),
                              )) ...[
                                const SizedBox(height: 10),
                                _buildSectionHeader(
                                  context: context,
                                  theme: theme,
                                  title: t(
                                    'ua_planner.craft.title',
                                    'Monthly craft recap',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: theme.dividerColor),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      for (int i = 0;
                                          i < _craftRules.length;
                                          i++)
                                        if (_isCraftUnlocked(
                                            month, _craftRules[i])) ...[
                                          if (i > 0)
                                            Divider(
                                                height: 1,
                                                color: theme.dividerColor),
                                          _buildCraftRow(
                                            theme: theme,
                                            month: month,
                                            rule: _craftRules[i],
                                          ),
                                        ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _UaField {
  final String id;
  final String labelKey;
  final String fallback;

  const _UaField(this.id, this.labelKey, this.fallback);
}

class _UaMonth {
  final String monthKey;
  final int year;
  final int month;
  final String elementId;
  final int cycleNumber;
  final bool isCycleStart;
  final Map<String, bool> flags;
  final Map<String, bool> bonusFlags;
  final Map<String, bool> craftFlags;
  final List<DateTime> heroicDates;
  final Map<String, bool> heroicFlags;
  final Map<String, List<DateTime>> eventDatesByType;
  final Map<String, String> scoreInputs;
  final Map<String, String> scoreUnits;
  final Map<String, String> guildPlacementInputs;
  final Map<String, String> individualPlacementInputs;
  bool locked = false;

  _UaMonth({
    required this.monthKey,
    required this.year,
    required this.month,
    required this.elementId,
    required this.cycleNumber,
    required this.isCycleStart,
    required this.flags,
    required this.bonusFlags,
    required this.craftFlags,
    required this.heroicDates,
    required this.heroicFlags,
    required this.eventDatesByType,
    required this.scoreInputs,
    required this.scoreUnits,
    required this.guildPlacementInputs,
    required this.individualPlacementInputs,
  });
}

class _UaCraftRule {
  final String id;
  final String labelKey;
  final String fallback;
  final int thresholdPieces;

  const _UaCraftRule({
    required this.id,
    required this.labelKey,
    required this.fallback,
    required this.thresholdPieces,
  });
}

class _UaSpecialRewardRule {
  final String id;
  final String labelKey;
  final String fallback;
  final int minPoints;
  final int quantity;

  const _UaSpecialRewardRule({
    required this.id,
    required this.labelKey,
    required this.fallback,
    required this.minPoints,
    required this.quantity,
  });
}

class _UaBonusRule {
  final String id;
  final String triggerFieldId;
  final String labelKey;
  final String fallback;
  final int pieces;
  final String? dependsOnBonusId;

  const _UaBonusRule({
    required this.id,
    required this.triggerFieldId,
    required this.labelKey,
    required this.fallback,
    required this.pieces,
    this.dependsOnBonusId,
  });
}

class _UaEventType {
  final String id;
  final String fieldId;
  final String labelKey;
  final String fallback;
  final bool includeIndividualPlacement;

  const _UaEventType({
    required this.id,
    required this.fieldId,
    required this.labelKey,
    required this.fallback,
    required this.includeIndividualPlacement,
  });
}

class _UaScoreUnit {
  final String id;
  final int multiplier;
  final String label;

  const _UaScoreUnit(this.id, this.multiplier, this.label);
}
