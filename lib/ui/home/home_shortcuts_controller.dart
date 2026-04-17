typedef HomeShortcutAction = Future<void> Function();

class HomeShortcutsController {
  HomeShortcutAction? _openPremium;
  HomeShortcutAction? _openLastResults;
  HomeShortcutAction? _openTheme;
  HomeShortcutAction? _openLanguage;

  void bind({
    required HomeShortcutAction openPremium,
    required HomeShortcutAction openLastResults,
    required HomeShortcutAction openTheme,
    required HomeShortcutAction openLanguage,
  }) {
    _openPremium = openPremium;
    _openLastResults = openLastResults;
    _openTheme = openTheme;
    _openLanguage = openLanguage;
  }

  void unbind() {
    _openPremium = null;
    _openLastResults = null;
    _openTheme = null;
    _openLanguage = null;
  }

  Future<void> openPremium() async => await _openPremium?.call();

  Future<void> openLastResults() async => await _openLastResults?.call();

  Future<void> openTheme() async => await _openTheme?.call();

  Future<void> openLanguage() async => await _openLanguage?.call();
}
