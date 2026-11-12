import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/wattwise_theme.dart';

class DesignIcon extends StatelessWidget {
  const DesignIcon(this.asset, {super.key, this.color});
  final String asset;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/figma/$asset.svg',
          colorFilter:
              color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn));
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor)),
      child: child);
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant))
      ]));
}

class ChoiceBar extends StatelessWidget {
  const ChoiceBar(
      {super.key,
      required this.labels,
      required this.selected,
      this.compact = false,
      required this.onChanged});
  final bool compact;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(compact ? 0 : 4),
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xfff2f2f2)
              : const Color(0xff2a382f),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
          children: List.generate(
              labels.length,
              (i) => Expanded(
                  child: Semantics(
                      selected: i == selected,
                      child: Material(
                          color: i == selected ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: () => onChanged(i),
                              child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: compact ? 7 : 10,
                                      horizontal: 4),
                                  child: Text(labels[i],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: compact ? 10.5 : 13,
                                          color: i == selected
                                              ? Colors.white
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                          fontWeight: i == selected
                                              ? FontWeight.w600
                                              : FontWeight.w400))))))))));
}

void showFailure(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save your changes. Please try again.')));
