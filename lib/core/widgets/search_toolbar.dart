import 'package:flutter/material.dart';

/// Shared search chrome with a flexible input height and full-size touch targets.
class SearchToolbar extends StatefulWidget {
  const SearchToolbar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSearch,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearch;
  final bool autofocus;

  @override
  State<SearchToolbar> createState() => _SearchToolbarState();
}

class _SearchToolbarState extends State<SearchToolbar> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(cs.primary.withValues(alpha: 0.07), cs.surface),
            cs.surface,
          ],
        ),
        border: Border(
            bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.55), width: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => Row(children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.search,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 15, height: 1.45),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      filled: true,
                      fillColor: cs.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: cs.onSurfaceVariant),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空输入',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                widget.controller.clear();
                                _focus.requestFocus();
                              },
                            ),
                      border: border,
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                          borderSide:
                              BorderSide(color: cs.primary, width: 1.4)),
                    ),
                    onSubmitted: (_) => widget.onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: value.text.trim().isEmpty ? null : widget.onSearch,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: const Text('搜索'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchResultSummary extends StatelessWidget {
  const SearchResultSummary(
      {super.key, required this.count, this.pending = false});
  final int count;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('搜索结果', style: theme.textTheme.titleMedium),
            Text('$count 个结果',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (pending)
              Text('部分来源仍在搜索',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
