import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/glass_surface.dart';

class SidebarState extends ChangeNotifier {
  bool _collapsed = false;
  bool _disposed = false;
  bool _toggled = false;
  static const _key = 'sidebar_collapsed';

  bool get collapsed => _collapsed;

  SidebarState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || _toggled) return;
    _collapsed = prefs.getBool(_key) ?? false;
    if (!_disposed) notifyListeners();
  }

  Future<void> toggle() async {
    _toggled = true;
    _collapsed = !_collapsed;
    if (!_disposed) notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _collapsed);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A quiet navigation layer; only this bounded surface samples the backdrop.
class AppSidebar extends StatelessWidget {
  static const width = 164.0;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onSettingsTap;
  final VoidCallback? onRecentTap;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onSettingsTap,
    this.onRecentTap,
  });

  static const _items = [
    (Icons.live_tv_rounded, '动漫'),
    (Icons.menu_book_rounded, '漫画'),
    (Icons.auto_stories_rounded, '轻小说'),
    (Icons.games_rounded, '游戏'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        blur: 16,
        color: cs.surface.withValues(alpha: dark ? 0.72 : 0.68),
        border: Border(
            right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 0, 12),
                child: Text('内容库',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
              ...List.generate(
                _items.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _SidebarItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: selectedIndex == i,
                    onTap: () => onChanged(i),
                  ),
                ),
              ),
              if (onRecentTap != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Divider(height: 1),
                ),
                _SidebarItem(
                    icon: Icons.history_rounded,
                    label: '最近记录',
                    selected: false,
                    onTap: onRecentTap!),
              ],
              const Spacer(),
              _SidebarItem(
                icon: Icons.settings_outlined,
                label: '设置',
                selected: false,
                onTap: onSettingsTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final foreground = widget.selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      label: widget.label,
      button: true,
      selected: widget.selected,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          key: ValueKey('sidebar-bg-${widget.label}'),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.selected
                ? cs.secondaryContainer
                : _hovered
                    ? cs.onSurface.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.selected
                    ? cs.primary.withValues(alpha: 0.12)
                    : Colors.transparent),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHover: (value) => setState(() => _hovered = value),
              borderRadius: BorderRadius.circular(12),
              focusColor: cs.primary.withValues(alpha: 0.12),
              hoverColor: Colors.transparent,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Icon(widget.icon, size: 20, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: widget.selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: foreground))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
