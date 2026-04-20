import 'dart:async';

import 'package:flutter/material.dart';

import '../data/last_session_storage.dart';
import '../util/i18n.dart';
import 'ua_planner_page.dart';
import 'home_page.dart';
import 'home/home_shortcuts_controller.dart';
import 'news_page.dart';
import 'theme_options.dart';
import 'war_page.dart';
import 'friend_codes_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  I18n? _i18n;
  String _themeId = themeOptions.first.id;
  bool _amoledMode = false;
  bool _isPremium = false;
  final HomeShortcutsController _homeShortcuts = HomeShortcutsController();
  late final List<bool> _initializedTabs = List<bool>.filled(5, false);

  String t(String key, String fallback) => _i18n?.t(key, fallback) ?? fallback;

  void _openPremiumFromAnywhere() {
    unawaited(_homeShortcuts.openPremium());
  }

  void _openLastResultsFromAnywhere() {
    unawaited(_homeShortcuts.openLastResults());
  }

  void _openThemeFromAnywhere() {
    unawaited(_homeShortcuts.openTheme());
  }

  void _openLanguageFromAnywhere() {
    unawaited(_homeShortcuts.openLanguage());
  }

  @override
  void initState() {
    super.initState();
    _initializedTabs[_index] = true;
    unawaited(_bootstrapShell());
  }

  Future<void> _bootstrapShell() async {
    final last = await LastSessionStorage.load();
    final lang = (last?.homeState['lang'] as String?)?.trim();
    final resolved = (lang == null || lang.isEmpty) ? 'it' : lang;
    final i18n = await I18n.fromAssets(resolved);
    final stored = (last?.homeState['themeId'] as String?)?.trim();
    final amoled = (last?.homeState['amoledMode'] as bool?) ?? false;
    final resolvedTheme = resolveThemeOption(stored).id;
    final storedIndex = (last?.homeState['shellIndex'] as num?)?.toInt() ?? 0;
    final resolvedIndex = storedIndex.clamp(0, 4);
    if (!mounted) return;
    setState(() {
      _index = resolvedIndex;
      _initializedTabs[resolvedIndex] = true;
      _i18n = i18n;
      _themeId = resolvedTheme;
      _amoledMode = amoled;
    });
  }

  Future<void> _refreshLang(String code) async {
    final i18n = await I18n.fromAssets(code);
    if (!mounted) return;
    setState(() => _i18n = i18n);
  }

  Future<void> _persistShellIndex(int index) async {
    final last = await LastSessionStorage.load();
    final mergedHomeState = <String, Object?>{
      ...(last?.homeState ?? const <String, Object?>{}),
      'shellIndex': index,
    };
    await LastSessionStorage.save(
      LastSessionData(
        homeState: mergedHomeState,
        lastStats: last?.lastStats,
        openResultsOnStart: false,
        premiumExpiryMs: last?.premiumExpiryMs ?? 0,
        savedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = _i18n;
    final themed = buildSeededTheme(
      Theme.of(context),
      _themeId,
      amoled: _amoledMode,
    );
    Widget buildPage(int index) {
      switch (index) {
        case 0:
          return HomePage(
            shellIndex: _index,
            onThemeChanged: (id) => setState(() => _themeId = id),
            onAmoledChanged: (enabled) => setState(() => _amoledMode = enabled),
            onPremiumChanged: (isPremium) {
              if (_isPremium == isPremium) return;
              setState(() => _isPremium = isPremium);
            },
            onLanguageChanged: (code) {
              unawaited(_refreshLang(code));
            },
            shortcutsController: _homeShortcuts,
          );
        case 1:
          return WarPage(
            i18n: i18n,
            isPremium: _isPremium,
            onOpenPremium: _openPremiumFromAnywhere,
            onOpenLastResults: _openLastResultsFromAnywhere,
            onOpenTheme: _openThemeFromAnywhere,
            onOpenLanguage: _openLanguageFromAnywhere,
          );
        case 2:
          return UaPlannerPage(
            i18n: i18n,
            isPremium: _isPremium,
            onOpenPremium: _openPremiumFromAnywhere,
            onOpenLastResults: _openLastResultsFromAnywhere,
            onOpenTheme: _openThemeFromAnywhere,
            onOpenLanguage: _openLanguageFromAnywhere,
          );
        case 3:
          return FriendCodesPage(
            i18n: i18n,
            isPremium: _isPremium,
            onOpenPremium: _openPremiumFromAnywhere,
            onOpenLastResults: _openLastResultsFromAnywhere,
            onOpenTheme: _openThemeFromAnywhere,
            onOpenLanguage: _openLanguageFromAnywhere,
          );
        case 4:
          return NewsPage(
            i18n: i18n,
            isPremium: _isPremium,
            onOpenPremium: _openPremiumFromAnywhere,
            onOpenLastResults: _openLastResultsFromAnywhere,
            onOpenTheme: _openThemeFromAnywhere,
            onOpenLanguage: _openLanguageFromAnywhere,
          );
      }
      return const SizedBox.shrink();
    }

    return Theme(
      data: themed,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: List<Widget>.generate(
            5,
            (index) => _initializedTabs[index]
                ? buildPage(index)
                : const SizedBox.shrink(),
            growable: false,
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() {
              _index = i;
              _initializedTabs[i] = true;
            });
            unawaited(_persistShellIndex(i));
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.shield),
              label: t('nav.epic', 'Raid'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.sports_martial_arts),
              label: t('nav.war', 'War'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month),
              label: t('nav.ua_planner', 'UA Planner'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.group_add_outlined),
              label: t('nav.friends', 'Friends'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note),
              label: t('nav.news', 'News'),
            ),
          ],
        ),
      ),
    );
  }
}
