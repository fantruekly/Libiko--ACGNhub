import 'dart:io' show Platform;

/// Whether the desktop-only plugins (`window_manager`) are
/// available. On Android / iOS the app must skip every call into them: the
/// plugins register no mobile implementation, so any method channel call
/// throws `MissingPluginException`.
bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
