import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../platform.dart';

class WindowControls extends StatefulWidget {
  final Color? foregroundColor;
  final Color? hoverColor;

  const WindowControls({super.key, this.foregroundColor, this.hoverColor});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (!isDesktop) return;
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    if (isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WindowButton(
          icon: Icons.remove_rounded,
          tooltip: '最小化',
          foregroundColor: widget.foregroundColor,
          hoverColor: widget.hoverColor,
          onTap: () => windowManager.minimize(),
        ),
        WindowButton(
          icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          tooltip: _isMaximized ? '还原' : '最大化',
          foregroundColor: widget.foregroundColor,
          hoverColor: widget.hoverColor,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        WindowButton(
          icon: Icons.close_rounded,
          tooltip: '关闭',
          danger: true,
          foregroundColor: widget.foregroundColor,
          hoverColor: widget.hoverColor,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class WindowButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  final Color? foregroundColor;
  final Color? hoverColor;

  const WindowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.foregroundColor,
    this.hoverColor,
  });

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover
        ? (widget.danger
            ? const Color(0xFFE81123)
            : (widget.hoverColor ?? const Color(0x0D000000)))
        : Colors.transparent;
    final fg = (_hover && widget.danger)
        ? Colors.white
        : (widget.foregroundColor ??
            (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1C1C1E).withValues(alpha: 0.55)));

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 46,
            height: 48,
            color: bg,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}
