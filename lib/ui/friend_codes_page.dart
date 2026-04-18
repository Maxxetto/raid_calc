import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/friend_codes_loader.dart';
import '../util/i18n.dart';
import 'widgets.dart';

class FriendCodesPage extends StatefulWidget {
  final I18n? i18n;
  final bool isPremium;
  final VoidCallback? onOpenPremium;
  final VoidCallback? onOpenLastResults;
  final VoidCallback? onOpenTheme;
  final VoidCallback? onOpenLanguage;

  const FriendCodesPage({
    super.key,
    this.i18n,
    this.isPremium = false,
    this.onOpenPremium,
    this.onOpenLastResults,
    this.onOpenTheme,
    this.onOpenLanguage,
  });

  @override
  State<FriendCodesPage> createState() => _FriendCodesPageState();
}

class _FriendCodesPageState extends State<FriendCodesPage> {
  final TextEditingController _search = TextEditingController();
  List<FriendCodeEntry> _all = const <FriendCodeEntry>[];
  bool _loading = true;
  String _query = '';
  String _serverFilter = 'All';
  String _platformFilter = 'All';

  String t(String key, String fallback) =>
      widget.i18n?.t(key, fallback) ?? fallback;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      final q = _search.text.trim();
      if (q == _query) return;
      setState(() => _query = q);
    });
    _load();
  }

  Future<void> _load() async {
    final list = await FriendCodesLoader.load();
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FriendCodeEntry> get _filtered {
    final q = _query.toLowerCase();
    final filtered = _all.where((e) {
      if (_serverFilter != 'All' && e.server != _serverFilter) return false;
      if (_platformFilter != 'All' && e.platform != _platformFilter)
        return false;
      if (q.isEmpty) return true;
      return e.playerName.toLowerCase().contains(q) ||
          e.friendCode.toLowerCase().contains(q);
    }).toList(growable: false);

    filtered.sort((a, b) {
      final byName = a.playerName.toLowerCase().compareTo(
            b.playerName.toLowerCase(),
          );
      if (byName != 0) return byName;
      return a.friendCode.toLowerCase().compareTo(b.friendCode.toLowerCase());
    });

    return filtered;
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${t('copied', 'Copied')}: $code'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('nav.friend_codes', 'Friend Codes')),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: t('friend_codes.search_hint',
                          'Search name or friend code...'),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(t('friend_codes.server', 'Server')),
                      ChoiceChip(
                        label: Text(t('friend_codes.filter.all', 'All')),
                        selected: _serverFilter == 'All',
                        onSelected: (_) =>
                            setState(() => _serverFilter = 'All'),
                      ),
                      ChoiceChip(
                        label: const Text('EU'),
                        selected: _serverFilter == 'EU',
                        onSelected: (_) => setState(() => _serverFilter = 'EU'),
                      ),
                      ChoiceChip(
                        label: const Text('Global'),
                        selected: _serverFilter == 'Global',
                        onSelected: (_) =>
                            setState(() => _serverFilter = 'Global'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(t('friend_codes.platform', 'Platform')),
                      ChoiceChip(
                        label: Text(t('friend_codes.filter.all', 'All')),
                        selected: _platformFilter == 'All',
                        onSelected: (_) =>
                            setState(() => _platformFilter = 'All'),
                      ),
                      ChoiceChip(
                        label: const Text('Android'),
                        selected: _platformFilter == 'Android',
                        onSelected: (_) =>
                            setState(() => _platformFilter = 'Android'),
                      ),
                      ChoiceChip(
                        label: const Text('iOS'),
                        selected: _platformFilter == 'iOS',
                        onSelected: (_) =>
                            setState(() => _platformFilter = 'iOS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${items.length} ${t('friend_codes.entries', 'entries')}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              t('friend_codes.empty', 'No friend codes found.'),
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final e = items[i];
                              return Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _MetaBadge(
                                            label: e.server,
                                            textColor:
                                                theme.colorScheme.primary,
                                            backgroundColor: theme
                                                .colorScheme.primaryContainer
                                                .withValues(alpha: 0.45),
                                          ),
                                          _MetaBadge(
                                            label: e.platform,
                                            textColor:
                                                theme.colorScheme.secondary,
                                            backgroundColor: theme
                                                .colorScheme.secondaryContainer
                                                .withValues(alpha: 0.45),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () =>
                                                  _copyCode(e.friendCode),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 2,
                                                  horizontal: 2,
                                                ),
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: theme
                                                        .textTheme.bodyLarge,
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            '${e.playerName} | ',
                                                      ),
                                                      TextSpan(
                                                        text: e.friendCode,
                                                        style: theme
                                                            .textTheme.bodyLarge
                                                            ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.6,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: t('copy', 'Copy'),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => _copyCode(
                                              e.friendCode,
                                            ),
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const _MetaBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
