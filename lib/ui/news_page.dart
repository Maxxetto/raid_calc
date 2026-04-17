import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/event_progress_storage.dart';
import '../data/event_shop_planner_math.dart';
import '../data/event_shop_planner_storage.dart';
import '../data/events_loader.dart';
import '../util/i18n.dart';
import 'widgets.dart';

enum _NewsEventsFilter {
  active,
  endedGrace,
  upcoming,
}

class NewsPage extends StatefulWidget {
  final I18n? i18n;
  final bool isPremium;
  final VoidCallback? onOpenPremium;
  final VoidCallback? onOpenLastResults;
  final VoidCallback? onOpenTheme;
  final VoidCallback? onOpenLanguage;
  final DateTime? nowOverride;

  const NewsPage({
    super.key,
    this.i18n,
    this.isPremium = false,
    this.onOpenPremium,
    this.onOpenLastResults,
    this.onOpenTheme,
    this.onOpenLanguage,
    this.nowOverride,
  });

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  _NewsEventsFilter _filter =
      _NewsEventsFilter.active; // active pinned by default
  late final Future<EventsCatalog> _eventsFuture;
  Map<String, Set<String>> _eventRowProgress = <String, Set<String>>{};
  Map<String, Map<String, int>> _eventShopInventory =
      <String, Map<String, int>>{};
  Map<String, Map<int, int>> _eventShopQuantities = <String, Map<int, int>>{};

  String t(String key, String fallback) =>
      widget.i18n?.t(key, fallback) ?? fallback;

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _eventsFuture = EventsLoader.load();
    _loadEventProgress();
    _loadShopPlannerState();
  }

  Future<void> _loadEventProgress() async {
    final loaded = await EventProgressStorage.load();
    if (!mounted) return;
    setState(() => _eventRowProgress = loaded);
  }

  Future<void> _saveEventProgress() async {
    await EventProgressStorage.save(_eventRowProgress);
  }

  Future<void> _loadShopPlannerState() async {
    final loaded = await EventShopPlannerStorage.load();
    if (!mounted) return;
    setState(() {
      _eventShopInventory = {
        for (final entry in loaded.entries) entry.key: entry.value.inventory,
      };
      _eventShopQuantities = {
        for (final entry in loaded.entries) entry.key: entry.value.quantities,
      };
    });
  }

  Future<void> _saveShopPlannerState() async {
    final payload = <String, EventShopPlannerStateData>{};
    final eventIds = <String>{
      ..._eventShopInventory.keys,
      ..._eventShopQuantities.keys,
    };
    for (final eventId in eventIds) {
      final inventory = _eventShopInventory[eventId] ?? const <String, int>{};
      final quantities = _eventShopQuantities[eventId] ?? const <int, int>{};
      final state = EventShopPlannerStateData(
        inventory: inventory,
        quantities: quantities,
      );
      if (!state.isEmpty) {
        payload[eventId] = state;
      }
    }
    await EventShopPlannerStorage.save(payload);
  }

  void _setRowCompleted({
    required String eventId,
    required String rowKey,
    required bool completed,
  }) {
    setState(() {
      final current = <String>{
        ...(_eventRowProgress[eventId] ?? const <String>{})
      };
      if (completed) {
        current.add(rowKey);
      } else {
        current.remove(rowKey);
      }
      if (current.isEmpty) {
        _eventRowProgress.remove(eventId);
      } else {
        _eventRowProgress[eventId] = current;
      }
    });
    _saveEventProgress();
  }

  void _setShopInventoryValue({
    required String eventId,
    required String currencyId,
    required int amount,
  }) {
    setState(() {
      final current = <String, int>{
        ...(_eventShopInventory[eventId] ?? const <String, int>{}),
      };
      if (amount > 0) {
        current[currencyId] = amount;
      } else {
        current.remove(currencyId);
      }
      if (current.isEmpty) {
        _eventShopInventory.remove(eventId);
      } else {
        _eventShopInventory[eventId] = current;
      }
    });
    _saveShopPlannerState();
  }

  void _clearShopInventory({required String eventId}) {
    setState(() {
      _eventShopInventory.remove(eventId);
    });
    _saveShopPlannerState();
  }

  void _setShopQuantity({
    required String eventId,
    required int itemIndex,
    required int qty,
  }) {
    setState(() {
      final current = <int, int>{
        ...(_eventShopQuantities[eventId] ?? const <int, int>{}),
      };
      if (qty > 0) {
        current[itemIndex] = qty;
      } else {
        current.remove(itemIndex);
      }
      if (current.isEmpty) {
        _eventShopQuantities.remove(eventId);
      } else {
        _eventShopQuantities[eventId] = current;
      }
    });
    _saveShopPlannerState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('nav.news', 'News')),
        actions: [
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
      body: FutureBuilder<EventsCatalog>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(t('news.events.loading', 'Loading events...')),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t('news.events.error', 'Unable to load events data.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final catalog = snapshot.data ??
              const EventsCatalog(
                  schemaVersion: 1, events: <EventDefinition>[]);

          final visible = catalog.events
              .where(
                  (e) => e.displayStatusAt(_now) != EventDisplayStatus.hidden)
              .toList(growable: false)
            ..sort((a, b) => _compareEvents(a, b, _now));

          if (visible.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t('news.events.empty', 'No active or recently ended events.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final counts = <_NewsEventsFilter, int>{
            _NewsEventsFilter.active: 0,
            _NewsEventsFilter.endedGrace: 0,
            _NewsEventsFilter.upcoming: 0,
          };
          for (final e in visible) {
            final s = e.displayStatusAt(_now);
            switch (s) {
              case EventDisplayStatus.active:
                counts[_NewsEventsFilter.active] =
                    (counts[_NewsEventsFilter.active] ?? 0) + 1;
                break;
              case EventDisplayStatus.endedGrace:
                counts[_NewsEventsFilter.endedGrace] =
                    (counts[_NewsEventsFilter.endedGrace] ?? 0) + 1;
                break;
              case EventDisplayStatus.upcoming:
                counts[_NewsEventsFilter.upcoming] =
                    (counts[_NewsEventsFilter.upcoming] ?? 0) + 1;
                break;
              case EventDisplayStatus.hidden:
                break;
            }
          }

          final filtered = visible.where((e) {
            final s = e.displayStatusAt(_now);
            return switch (_filter) {
              _NewsEventsFilter.active => s == EventDisplayStatus.active,
              _NewsEventsFilter.endedGrace =>
                s == EventDisplayStatus.endedGrace,
              _NewsEventsFilter.upcoming => s == EventDisplayStatus.upcoming,
            };
          }).toList(growable: false);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              CompactCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.event_note,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t(
                              'news.events.tip',
                              'Tables are shown while the event is active and remain visible for a short grace period after the end date.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('news.events.filter.title', 'Event view'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<_NewsEventsFilter>(
                      key: const ValueKey('news-events-filter-dropdown'),
                      initialValue: _filter,
                      isDense: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<_NewsEventsFilter>(
                          value: _NewsEventsFilter.active,
                          child: Text(
                            '${t('news.events.filter.active', 'Active')} (${counts[_NewsEventsFilter.active] ?? 0})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem<_NewsEventsFilter>(
                          value: _NewsEventsFilter.endedGrace,
                          child: Text(
                            '${t('news.events.filter.ended', 'Ended (grace)')} (${counts[_NewsEventsFilter.endedGrace] ?? 0})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem<_NewsEventsFilter>(
                          value: _NewsEventsFilter.upcoming,
                          child: Text(
                            '${t('news.events.filter.upcoming', 'Upcoming')} (${counts[_NewsEventsFilter.upcoming] ?? 0})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _filter = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _filterCountChip(
                          context,
                          label: t('news.events.filter.active', 'Active'),
                          count: counts[_NewsEventsFilter.active] ?? 0,
                          emphasized: _filter == _NewsEventsFilter.active,
                        ),
                        _filterCountChip(
                          context,
                          label: t('news.events.filter.ended', 'Ended (grace)'),
                          count: counts[_NewsEventsFilter.endedGrace] ?? 0,
                          emphasized: _filter == _NewsEventsFilter.endedGrace,
                        ),
                        _filterCountChip(
                          context,
                          label: t('news.events.filter.upcoming', 'Upcoming'),
                          count: counts[_NewsEventsFilter.upcoming] ?? 0,
                          emphasized: _filter == _NewsEventsFilter.upcoming,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                CompactCard(
                  child: Text(
                    t(
                      'news.events.empty_filtered',
                      'No events available in this section right now.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              for (final event in filtered) ...[
                _EventCard(
                  event: event,
                  status: event.displayStatusAt(_now),
                  checkedRows: _eventRowProgress[event.id] ?? const <String>{},
                  manualShopInventory:
                      _eventShopInventory[event.id] ?? const <String, int>{},
                  savedShopQuantities:
                      _eventShopQuantities[event.id] ?? const <int, int>{},
                  onRowCheckedChanged: (row, checked) => _setRowCompleted(
                    eventId: event.id,
                    rowKey: _eventRowKey(row),
                    completed: checked,
                  ),
                  onShopInventoryChanged: (currencyId, amount) =>
                      _setShopInventoryValue(
                    eventId: event.id,
                    currencyId: currencyId,
                    amount: amount,
                  ),
                  onClearShopInventory: () => _clearShopInventory(
                    eventId: event.id,
                  ),
                  onShopQuantityChanged: (itemIndex, qty) => _setShopQuantity(
                    eventId: event.id,
                    itemIndex: itemIndex,
                    qty: qty,
                  ),
                  t: t,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _filterCountChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool emphasized,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? cs.primaryContainer.withValues(alpha: 0.55)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        '$label: $count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: emphasized ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

int _compareEvents(EventDefinition a, EventDefinition b, DateTime now) {
  final sa = a.displayStatusAt(now);
  final sb = b.displayStatusAt(now);
  int rank(EventDisplayStatus s) => switch (s) {
        EventDisplayStatus.active => 0,
        EventDisplayStatus.endedGrace => 1,
        EventDisplayStatus.upcoming => 2,
        EventDisplayStatus.hidden => 99,
      };
  final r = rank(sa).compareTo(rank(sb));
  if (r != 0) return r;

  // Within each section: newest active first, most recently ended first,
  // nearest upcoming first.
  switch (sa) {
    case EventDisplayStatus.active:
      return b.startDate.compareTo(a.startDate);
    case EventDisplayStatus.endedGrace:
      return b.endDate.compareTo(a.endDate);
    case EventDisplayStatus.upcoming:
      return a.startDate.compareTo(b.startDate);
    case EventDisplayStatus.hidden:
      return 0;
  }
}

String _eventRowKey(EventScheduleRow row) {
  String d(DateTime x) {
    final y = x.year.toString().padLeft(4, '0');
    final m = x.month.toString().padLeft(2, '0');
    final day = x.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  return '${row.activity}|${d(row.startDate)}|${d(row.endDate)}';
}

class _EventCard extends StatelessWidget {
  final EventDefinition event;
  final EventDisplayStatus status;
  final Set<String> checkedRows;
  final Map<String, int> manualShopInventory;
  final Map<int, int> savedShopQuantities;
  final void Function(EventScheduleRow row, bool checked) onRowCheckedChanged;
  final void Function(String currencyId, int amount) onShopInventoryChanged;
  final VoidCallback onClearShopInventory;
  final void Function(int itemIndex, int qty) onShopQuantityChanged;
  final String Function(String key, String fallback) t;

  const _EventCard({
    required this.event,
    required this.status,
    required this.checkedRows,
    required this.manualShopInventory,
    required this.savedShopQuantities,
    required this.onRowCheckedChanged,
    required this.onShopInventoryChanged,
    required this.onClearShopInventory,
    required this.onShopQuantityChanged,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ml = MaterialLocalizations.of(context);
    final headerTitle = status == EventDisplayStatus.endedGrace
        ? '${event.name} | ${t('news.events.ended_suffix', 'EVENT ENDED')}'
        : event.name;
    final inventory = _buildTrackedInventory(event, checkedRows);

    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${ml.formatMediumDate(event.startDate)}  ->  ${ml.formatMediumDate(event.endDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (status == EventDisplayStatus.endedGrace) ...[
                      const SizedBox(height: 2),
                      Text(
                        t(
                          'news.events.visible_until',
                          'Visible until: {date}',
                        ).replaceAll(
                          '{date}',
                          ml.formatMediumDate(
                            event.hiddenAfterDate.subtract(
                              const Duration(days: 1),
                            ),
                          ),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(context, status),
            ],
          ),
          const SizedBox(height: 8),
          _EventInventorySummary(
            event: event,
            checkedRows: checkedRows,
            tracked: inventory,
            t: t,
          ),
          const SizedBox(height: 8),
          _EventTable(
            event: event,
            checkedRows: checkedRows,
            onRowCheckedChanged: onRowCheckedChanged,
            t: t,
          ),
          if (status == EventDisplayStatus.active ||
              status == EventDisplayStatus.upcoming)
            if (event.specialEventShop.isNotEmpty) ...[
              const SizedBox(height: 8),
              _EventShopPlanner(
                event: event,
                trackedInventory: {
                  for (final item in inventory)
                    item.id: (
                      label: item.label,
                      amount: item.amount,
                      infinite: item.infinite,
                    ),
                },
                manualInventory: manualShopInventory,
                savedQuantities: savedShopQuantities,
                onInventoryChanged: onShopInventoryChanged,
                onClearInventory: onClearShopInventory,
                onQtyChanged: onShopQuantityChanged,
                t: t,
              ),
            ],
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, EventDisplayStatus status) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case EventDisplayStatus.active:
        label = t('news.events.status_active', 'ACTIVE');
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        break;
      case EventDisplayStatus.upcoming:
        label = t('news.events.status_upcoming', 'UPCOMING');
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        break;
      case EventDisplayStatus.endedGrace:
        label = t('news.events.status_ended', 'EVENT ENDED');
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        break;
      case EventDisplayStatus.hidden:
        label = t('news.events.status_hidden', 'HIDDEN');
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static List<({String id, String label, int amount, bool infinite})>
      _buildTrackedInventory(EventDefinition event, Set<String> checkedRows) {
    final byCurrency = <String, ({String label, int amount, bool infinite})>{};
    for (final row in event.rows) {
      if (!checkedRows.contains(_eventRowKey(row))) continue;
      for (final m in event.materials) {
        final raw = row.values[m.id];
        if (raw == null || raw.trim().isEmpty) continue;
        final normalized = raw.trim();
        final isInfinite = normalized.toUpperCase().contains('INF') ||
            normalized.contains('∞');
        final prev = byCurrency[m.id];
        if (isInfinite) {
          byCurrency[m.id] = (
            label: m.label,
            amount: prev?.amount ?? 0,
            infinite: true,
          );
          continue;
        }
        final parsed =
            int.tryParse(normalized.replaceAll(RegExp(r'[^0-9]'), ''));
        if (parsed == null) continue;
        byCurrency[m.id] = (
          label: m.label,
          amount: (prev?.amount ?? 0) + parsed,
          infinite: prev?.infinite ?? false,
        );
      }
    }

    final ordered = <({String id, String label, int amount, bool infinite})>[];
    for (final m in event.materials) {
      final e = byCurrency[m.id];
      if (e == null) continue;
      ordered.add(
          (id: m.id, label: e.label, amount: e.amount, infinite: e.infinite));
    }
    return ordered;
  }
}

class _EventInventorySummary extends StatelessWidget {
  final EventDefinition event;
  final Set<String> checkedRows;
  final List<({String id, String label, int amount, bool infinite})> tracked;
  final String Function(String key, String fallback) t;

  const _EventInventorySummary({
    required this.event,
    required this.checkedRows,
    required this.tracked,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: checkedRows.isEmpty
            ? cs.surfaceContainerHighest.withValues(alpha: 0.28)
            : cs.secondaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('news.events.progress.inventory_title', 'Tracked inventory'),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t(
              'news.events.progress.rows_done',
              '{done}/{total} activities checked',
            )
                .replaceAll('{done}', checkedRows.length.toString())
                .replaceAll('{total}', event.rows.length.toString()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (tracked.isEmpty)
            Text(
              t(
                'news.events.progress.none',
                'No tracked rewards yet. Use the checkboxes in the table.',
              ),
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in tracked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      '${item.label}: ${item.infinite ? t('news.events.progress.inf', 'INF') : _fmtInt(item.amount)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EventTable extends StatefulWidget {
  final EventDefinition event;
  final Set<String> checkedRows;
  final void Function(EventScheduleRow row, bool checked) onRowCheckedChanged;
  final String Function(String key, String fallback) t;

  const _EventTable({
    required this.event,
    required this.checkedRows,
    required this.onRowCheckedChanged,
    required this.t,
  });

  @override
  State<_EventTable> createState() => _EventTableState();
}

class _EventTableState extends State<_EventTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ml = MaterialLocalizations.of(context);
    final shortDateStyle = theme.textTheme.bodySmall?.copyWith(height: 1.05);

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget headerCell(String text,
            {Alignment align = Alignment.centerLeft}) {
          return _tableCell(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            align: align,
            dense: true,
          );
        }

        Widget bodyCell(Widget child,
            {Alignment align = Alignment.centerLeft}) {
          return _tableCell(
            child: child,
            align: align,
            dense: true,
          );
        }

        final rows = <TableRow>[
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
              ),
            ),
            children: [
              headerCell(widget.t('news.events.table.activity', 'Event')),
              headerCell(widget.t('news.events.table.dates', 'Dates')),
              headerCell(widget.t('news.events.table.rewards', 'Rewards')),
            ],
          ),
          for (final row in widget.event.rows)
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
              children: [
                bodyCell(
                  Row(
                    children: [
                      Checkbox(
                        value: widget.checkedRows.contains(_eventRowKey(row)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) =>
                            widget.onRowCheckedChanged(row, v == true),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          row.activity,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bodyCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.t('news.events.start_short', 'Start')}: ${ml.formatShortDate(row.startDate)}',
                        style: shortDateStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.t('news.events.end_short', 'End')}: ${ml.formatShortDate(row.endDate)}',
                        style: shortDateStyle,
                      ),
                    ],
                  ),
                ),
                bodyCell(
                  _RewardsCompactCell(
                    event: widget.event,
                    row: row,
                    textStyle:
                        theme.textTheme.bodySmall?.copyWith(height: 1.02),
                  ),
                ),
              ],
            ),
        ];

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth < 420
                    ? 560
                    : (constraints.maxWidth < 700 ? 620 : 760),
              ),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(120),
                  1: FixedColumnWidth(145),
                  2: FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tableCell({
    required Widget child,
    required Alignment align,
    required bool dense,
  }) {
    return Align(
      alignment: align,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: dense ? 5 : 7,
        ),
        child: child,
      ),
    );
  }
}

class _RewardsCompactCell extends StatelessWidget {
  final EventDefinition event;
  final EventScheduleRow row;
  final TextStyle? textStyle;

  const _RewardsCompactCell({
    required this.event,
    required this.row,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    for (final m in event.materials) {
      final raw = row.values[m.id];
      if (raw == null || raw.trim().isEmpty) continue;
      final value = raw.trim();
      lines.add('${m.label} (x$value)');
    }
    if (lines.isEmpty) {
      return Text('-', style: textStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < lines.length; i++) ...[
          Text(
            lines[i],
            style: textStyle,
            softWrap: true,
          ),
          if (i != lines.length - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }
}

class _EventShopPlanner extends StatefulWidget {
  final EventDefinition event;
  final Map<String, ({String label, int amount, bool infinite})>
      trackedInventory;
  final Map<String, int> manualInventory;
  final Map<int, int> savedQuantities;
  final void Function(String currencyId, int amount) onInventoryChanged;
  final VoidCallback onClearInventory;
  final void Function(int itemIndex, int qty) onQtyChanged;
  final String Function(String key, String fallback) t;

  const _EventShopPlanner({
    required this.event,
    required this.trackedInventory,
    required this.manualInventory,
    required this.savedQuantities,
    required this.onInventoryChanged,
    required this.onClearInventory,
    required this.onQtyChanged,
    required this.t,
  });

  @override
  State<_EventShopPlanner> createState() => _EventShopPlannerState();
}

class _EventShopPlannerState extends State<_EventShopPlanner> {
  late List<int> _qtys;
  Map<String, TextEditingController> _inventoryControllers =
      <String, TextEditingController>{};
  final Map<String, int> _pendingInventoryUpdates = <String, int>{};
  Timer? _inventoryDebounce;
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _qtys = _buildQtysFromSaved();
    _searchController = TextEditingController();
    _rebuildInventoryControllers();
  }

  @override
  void didUpdateWidget(covariant _EventShopPlanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.event.specialEventShop.length !=
            widget.event.specialEventShop.length) {
      _qtys = _buildQtysFromSaved();
    }
    if (oldWidget.event.id != widget.event.id ||
        !_sameIndexIntMap(oldWidget.savedQuantities, widget.savedQuantities)) {
      _qtys = _buildQtysFromSaved();
    }
    if (oldWidget.event.id != widget.event.id ||
        !_sameIntMap(oldWidget.manualInventory, widget.manualInventory)) {
      _rebuildInventoryControllers();
    }
  }

  @override
  void dispose() {
    _inventoryDebounce?.cancel();
    for (final controller in _inventoryControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  int _maxQtyFor(EventShopItem item) => item.buyLimit ?? 999999;

  List<int> _buildQtysFromSaved() {
    final qtys = List<int>.filled(widget.event.specialEventShop.length, 0);
    for (final entry in widget.savedQuantities.entries) {
      if (entry.key < 0 || entry.key >= qtys.length) continue;
      qtys[entry.key] = entry.value;
    }
    return qtys;
  }

  bool _sameIntMap(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _sameIndexIntMap(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  List<({String id, String label})> _shopCurrencies() {
    final seen = <String>{};
    final out = <({String id, String label})>[];
    for (final item in widget.event.specialEventShop) {
      if (seen.add(item.cost.currencyId)) {
        out.add((id: item.cost.currencyId, label: item.cost.currencyLabel));
      }
    }
    return out;
  }

  void _rebuildInventoryControllers() {
    final currencies = _shopCurrencies();
    final next = <String, TextEditingController>{};
    for (final currency in currencies) {
      final text = (widget.manualInventory[currency.id] ?? 0) > 0
          ? (widget.manualInventory[currency.id] ?? 0).toString()
          : '';
      final old = _inventoryControllers.remove(currency.id);
      if (old != null) {
        if (old.text != text) old.text = text;
        next[currency.id] = old;
      } else {
        next[currency.id] = TextEditingController(text: text);
      }
    }
    for (final controller in _inventoryControllers.values) {
      controller.dispose();
    }
    _inventoryControllers = next;
  }

  int _manualInventoryFor(String currencyId) =>
      widget.manualInventory[currencyId] ?? 0;

  ({String label, int amount, bool infinite})? _trackedInventoryFor(
    String currencyId,
  ) =>
      widget.trackedInventory[currencyId];

  void _onInventoryTextChanged(String currencyId, String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(normalized) ?? 0;
    _pendingInventoryUpdates[currencyId] = parsed;
    _inventoryDebounce?.cancel();
    _inventoryDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _pendingInventoryUpdates.isEmpty) return;
      final updates = Map<String, int>.from(_pendingInventoryUpdates);
      _pendingInventoryUpdates.clear();
      for (final entry in updates.entries) {
        widget.onInventoryChanged(entry.key, entry.value);
      }
    });
  }

  void _clearSelections() {
    setState(() {
      for (int i = 0; i < _qtys.length; i++) {
        _qtys[i] = 0;
      }
    });
    for (int i = 0; i < _qtys.length; i++) {
      widget.onQtyChanged(i, 0);
    }
  }

  void _setAllToMax() {
    setState(() {
      for (int i = 0; i < _qtys.length; i++) {
        final item = widget.event.specialEventShop[i];
        _qtys[i] = item.buyLimit ?? 1;
      }
    });
    for (int i = 0; i < _qtys.length; i++) {
      widget.onQtyChanged(i, _qtys[i]);
    }
  }

  void _setQty(int index, int qty) {
    if (index < 0 || index >= _qtys.length) return;
    final maxQty = _maxQtyFor(widget.event.specialEventShop[index]);
    final normalized = qty.clamp(0, maxQty);
    setState(() => _qtys[index] = normalized);
    widget.onQtyChanged(index, normalized);
  }

  bool _matchesSearch(EventShopItem item) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return item.name.toLowerCase().contains(q) ||
        item.cost.currencyLabel.toLowerCase().contains(q);
  }

  Future<void> _showPlannerTip() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.t(
            'news.events.shop.tip.title',
            'Shop planner tip',
          ),
        ),
        content: Text(
          widget.t(
            'news.events.shop.tip.body',
            'Select the shop items you want, set the quantity for each item, and the app will automatically calculate the total resources required grouped by currency.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.t('ok', 'OK')),
          ),
        ],
      ),
    );
  }

  Future<void> _editQty(int index) async {
    if (index < 0 || index >= widget.event.specialEventShop.length) return;
    final item = widget.event.specialEventShop[index];
    final maxQty = _maxQtyFor(item);
    final current = _qtys[index];
    final ctl = TextEditingController(text: current.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.t('news.events.shop.qty_title', 'Select quantity')),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.t('news.events.shop.cost', 'Cost')}: '
                '${_fmtInt(item.cost.amount)} ${item.cost.currencyLabel}'
                '${item.buyLimit == null ? '' : ' | ${widget.t('news.events.shop.limit', 'Limit')}: ${item.buyLimit}'}',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: widget.t('news.events.shop.qty', 'Quantity'),
                  helperText: item.buyLimit == null
                      ? widget.t(
                          'news.events.shop.qty_inf_hint',
                          'Use 0 to deselect. No event limit.',
                        )
                      : widget
                          .t(
                            'news.events.shop.qty_limit_hint',
                            'Use 0 to deselect. Max {max}.',
                          )
                          .replaceAll('{max}', item.buyLimit.toString()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(ctl.text.trim()) ?? current;
              final normalized = parsed.clamp(0, maxQty);
              Navigator.of(ctx).pop(normalized);
            },
            child: Text(widget.t('news.events.shop.apply_qty', 'Apply')),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    _setQty(index, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = widget.event.specialEventShop;
    final currencies = _shopCurrencies();
    final filteredIndexes = <int>[
      for (int i = 0; i < items.length; i++)
        if (_matchesSearch(items[i])) i,
    ];

    final totals = <String, ({String label, int amount})>{};
    int selectedCount = 0;
    for (int i = 0; i < items.length; i++) {
      final qty = _qtys[i];
      if (qty <= 0) continue;
      selectedCount += 1;
      final item = items[i];
      final key = item.cost.currencyId;
      final lineTotal = item.cost.amount * qty;
      final prev = totals[key];
      totals[key] = (
        label: item.cost.currencyLabel,
        amount: (prev?.amount ?? 0) + lineTotal,
      );
    }
    final sortedTotals = <({String id, String label, int amount})>[
      for (final currency in currencies)
        if (totals.containsKey(currency.id))
          (
            id: currency.id,
            label: totals[currency.id]!.label,
            amount: totals[currency.id]!.amount,
          ),
    ];

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceContainerLowest,
        ),
        child: ExpansionTile(
          key: ValueKey('shop-planner-${widget.event.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.t(
                      'news.events.shop.title', 'Special Event Shop planner'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip:
                    widget.t('news.events.shop.tip.title', 'Shop planner tip'),
                onPressed: _showPlannerTip,
                icon: const Icon(Icons.info_outline),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          subtitle: Text(
            selectedCount == 0
                ? widget.t(
                    'news.events.shop.subtitle',
                    'Select items and quantities to calculate required resources.',
                  )
                : widget
                    .t(
                      'news.events.shop.subtitle_selected',
                      '{count} selected item(s). Resource totals updated automatically.',
                    )
                    .replaceAll('{count}', selectedCount.toString()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          children: [
            if (currencies.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.t(
                        'news.events.shop.inventory_title',
                        'Current inventory',
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.t(
                        'news.events.shop.inventory_subtitle',
                        'Enter what you currently have. Checked table rewards are added automatically on top.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.t(
                              'news.events.shop.inventory_hint',
                              'Manual values stay saved for this event.',
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: widget.manualInventory.isNotEmpty
                              ? () {
                                  _inventoryDebounce?.cancel();
                                  _pendingInventoryUpdates.clear();
                                  for (final controller
                                      in _inventoryControllers.values) {
                                    controller.clear();
                                  }
                                  widget.onClearInventory();
                                }
                              : null,
                          icon: const Icon(
                            Icons.cleaning_services_outlined,
                            size: 16,
                          ),
                          label: Text(
                            widget.t(
                              'news.events.shop.clear_inventory',
                              'Clear inventory',
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (int i = 0; i < currencies.length; i++) ...[
                      _inventoryField(
                        context,
                        currencyId: currencies[i].id,
                        currencyLabel: currencies[i].label,
                      ),
                      if (i != currencies.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
            Row(
              children: [
                TextButton.icon(
                  onPressed: selectedCount > 0 ? _clearSelections : null,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(
                    widget.t(
                      'news.events.shop.clear',
                      'Clear selections',
                    ),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: items.isNotEmpty ? _setAllToMax : null,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text(
                    widget.t('news.events.shop.max_all', 'Max all'),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                hintText: widget.t(
                  'news.events.shop.search_hint',
                  'Search shop items...',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (totals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  widget.t(
                    'news.events.shop.totals_empty',
                    'No items selected yet.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.t(
                        'news.events.shop.totals_title',
                        'Required resources',
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in sortedTotals)
                          _totalsChip(
                            context,
                            currencyId: entry.id,
                            label: entry.label,
                            requiredAmount: entry.amount,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget
                          .t(
                            'news.events.shop.visible_items',
                            '{visible}/{total} items shown',
                          )
                          .replaceAll(
                              '{visible}', filteredIndexes.length.toString())
                          .replaceAll('{total}', items.length.toString()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (filteredIndexes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  widget.t(
                    'news.events.shop.search_empty',
                    'No shop items match this search.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (int listIndex = 0;
                listIndex < filteredIndexes.length;
                listIndex++) ...[
              () {
                final i = filteredIndexes[listIndex];
                return _ShopPlannerRow(
                  itemKey: 'shop-item-$i',
                  item: items[i],
                  qty: _qtys[i],
                  t: widget.t,
                  canIncrement: _qtys[i] < _maxQtyFor(items[i]),
                  canDecrement: _qtys[i] > 0,
                  onToggle: (enabled) {
                    _setQty(i, enabled ? (_qtys[i] == 0 ? 1 : _qtys[i]) : 0);
                  },
                  onIncrement: () => _setQty(i, _qtys[i] + 1),
                  onDecrement: () => _setQty(i, _qtys[i] - 1),
                  onEditQty: () => _editQty(i),
                );
              }(),
              if (listIndex != filteredIndexes.length - 1)
                Divider(
                  height: 10,
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inventoryField(
    BuildContext context, {
    required String currencyId,
    required String currencyLabel,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tracked = _trackedInventoryFor(currencyId);
    final trackedText = tracked == null
        ? null
        : tracked.infinite
            ? widget.t(
                'news.events.shop.inventory_tracked_inf',
                'Tracked from event: INF',
              )
            : widget
                .t(
                  'news.events.shop.inventory_tracked',
                  'Tracked from event: {amount}',
                )
                .replaceAll('{amount}', _fmtInt(tracked.amount));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: ValueKey('shop-inventory-$currencyId'),
            controller: _inventoryControllers[currencyId],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _onInventoryTextChanged(currencyId, value),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              labelText: currencyLabel,
              helperText: trackedText,
              helperMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            widget
                .t('news.events.shop.inventory_manual_short', 'Manual')
                .toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalsChip(
    BuildContext context, {
    required String currencyId,
    required String label,
    required int requiredAmount,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tracked = _trackedInventoryFor(currencyId);
    final manual = _manualInventoryFor(currencyId);
    final totals = computeEventShopPlannerTotals(
      requiredAmount: requiredAmount,
      manualInventory: manual,
      trackedInventory: tracked?.amount ?? 0,
      trackedInfinite: tracked?.infinite == true,
    );
    final remainingColor =
        totals.remaining > 0 ? cs.error : Colors.green.shade700;
    final inventoryLabel = totals.inventoryIsInfinite
        ? widget.t('news.events.progress.inf', 'INF')
        : _fmtInt(totals.available);

    return Container(
      key: ValueKey('shop-total-$currencyId'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget
                .t(
                  'news.events.shop.required_value',
                  'Required: {amount}',
                )
                .replaceAll('{amount}', _fmtInt(totals.required)),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 1),
          Text(
            widget
                .t(
                  'news.events.shop.inventory_breakdown',
                  'Manual: {manual} | Tracked: {tracked} | Total: {total}',
                )
                .replaceAll('{manual}', _fmtInt(manual))
                .replaceAll(
                  '{tracked}',
                  tracked?.infinite == true
                      ? widget.t('news.events.progress.inf', 'INF')
                      : _fmtInt(tracked?.amount ?? 0),
                )
                .replaceAll('{total}', inventoryLabel),
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 1),
          RichText(
            text: TextSpan(
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface,
              ),
              children: [
                TextSpan(
                  text: widget.t(
                    'news.events.shop.after_inventory',
                    'After inventory: ',
                  ),
                ),
                TextSpan(
                  text: _fmtInt(totals.remaining),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: remainingColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' ($inventoryLabel)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopPlannerRow extends StatelessWidget {
  final EventShopItem item;
  final String itemKey;
  final int qty;
  final String Function(String key, String fallback) t;
  final bool canIncrement;
  final bool canDecrement;
  final ValueChanged<bool> onToggle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditQty;

  const _ShopPlannerRow({
    required this.itemKey,
    required this.item,
    required this.qty,
    required this.t,
    required this.canIncrement,
    required this.canDecrement,
    required this.onToggle,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditQty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = qty > 0;
    final limitText = item.buyLimit == null
        ? t('news.events.shop.limit_inf', 'INF')
        : item.buyLimit.toString();
    final lineTotal = selected ? item.cost.amount * qty : 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      decoration: BoxDecoration(
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => onToggle(v == true),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            item.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _qtyPill(context, selected: selected),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _miniTag(
                        context,
                        '${t('news.events.shop.cost', 'Cost')}: ${_fmtInt(item.cost.amount)} ${item.cost.currencyLabel}',
                      ),
                      _miniTag(
                        context,
                        '${t('news.events.shop.limit', 'Limit')}: $limitText',
                      ),
                      if (selected)
                        _miniTag(
                          context,
                          '${t('news.events.shop.line_total', 'Total')}: ${_fmtInt(lineTotal)} ${item.cost.currencyLabel}',
                          emphasized: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyPill(BuildContext context, {required bool selected}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              selected ? cs.primary.withValues(alpha: 0.35) : cs.outlineVariant,
        ),
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.22)
            : cs.surfaceContainerLowest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyStepButton(
            context,
            icon: Icons.remove,
            onPressed: canDecrement ? onDecrement : null,
          ),
          InkWell(
            key: ValueKey('$itemKey-qty-pill'),
            borderRadius: BorderRadius.circular(8),
            onTap: onEditQty,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Text(
                '${t('news.events.shop.qty', 'Qty')}: $qty',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected ? cs.onPrimaryContainer : null,
                ),
              ),
            ),
          ),
          _qtyStepButton(
            context,
            icon: Icons.add,
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }

  Widget _qtyStepButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      iconSize: 14,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }

  Widget _miniTag(
    BuildContext context,
    String text, {
    bool emphasized = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: emphasized
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          color: emphasized ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _fmtInt(int v) {
  final s = v.toString();
  final out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    out.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) {
      out.write(',');
    }
  }
  return out.toString();
}
