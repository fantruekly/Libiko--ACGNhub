import 'package:flutter/material.dart';
import '../models/work.dart';
import 'ratio_cover.dart';

class WorkCard extends StatefulWidget {
  final Work work;
  final VoidCallback? onTap;
  final String? subtitle;

  const WorkCard({super.key, required this.work, this.onTap, this.subtitle});

  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final work = widget.work;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;

    Widget cover = RatioCover(
      url: work.coverUrl,
      fadeInDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      enabled: false,
      placeholderBuilder: (_) => _placeholder(work, cs),
    );

    return Semantics(
      button: widget.onTap != null,
      label:
          [work.title, if (widget.subtitle != null) widget.subtitle!].join('，'),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
                0, _hovered && !reduceMotion ? -3 : 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _focused
                            ? cs.primary
                            : cs.outlineVariant.withValues(alpha: 0.45)),
                    boxShadow: _hovered || _focused
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                  alpha: cs.brightness == Brightness.dark
                                      ? 0.2
                                      : 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ]
                        : const [],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Hero(tag: 'work_${work.id}', child: cover),
                )),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38 * scale,
                  child: Text(
                    work.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Work work, ColorScheme cs) {
    final hash = work.title.hashCode.abs();
    final bgColors = [
      cs.surfaceContainerLow,
      cs.secondaryContainer,
      cs.surfaceContainer,
      cs.primaryContainer
    ];
    return Container(
      color: bgColors[hash % bgColors.length],
      child: Center(
        child: Text(
          work.title.isEmpty ? '·' : work.title.characters.first,
          style: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 28,
              fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
