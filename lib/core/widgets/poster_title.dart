import 'package:flutter/material.dart';

/// Reserves two lines so short and long poster titles align in a row.
class PosterTitle extends StatelessWidget {
  static const gap = 8.0;
  static const _fontSize = 13.0;

  static double heightOf(BuildContext context) =>
      38 * MediaQuery.textScalerOf(context).scale(_fontSize) / _fontSize;

  final String title;

  const PosterTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: gap),
        child: SizedBox(
          height: heightOf(context),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
}
