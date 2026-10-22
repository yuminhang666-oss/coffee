import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const espresso = Color(0xFF33251F),
    caramel = Color(0xFFA45F36),
    cream = Color(0xFFF8F4ED);

class CoffeeRoute<T> extends CupertinoPageRoute<T> {
  final bool reduced;
  CoffeeRoute({required BuildContext context, required super.builder})
    : reduced = MediaQuery.disableAnimationsOf(context);
  @override
  Duration get transitionDuration => Duration(milliseconds: reduced ? 0 : 260);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduced ? 0 : 200);
}

Color ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color muted(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;
Color panel(BuildContext c) => Theme.of(c).colorScheme.surface;
ThemeData coffeeTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: caramel, brightness: b)
      .copyWith(
        primary: dark ? const Color(0xFFE8AC7F) : caramel,
        surface: dark ? const Color(0xFF28221E) : const Color(0xFFFFFDFA),
        onSurface: dark ? const Color(0xFFF3E8DB) : espresso,
        onSurfaceVariant: dark
            ? const Color(0xFFBEB0A2)
            : const Color(0xFF81756B),
        secondary: dark ? const Color(0xFFD7B999) : const Color(0xFF88654B),
        secondaryContainer: dark
            ? const Color(0xFF493529)
            : const Color(0xFFF0E1CE),
        onSecondaryContainer: dark ? const Color(0xFFF3E8DB) : espresso,
        tertiary: caramel,
        surfaceContainerHighest: dark
            ? const Color(0xFF392E27)
            : const Color(0xFFF0E9DF),
        surfaceContainerHigh: dark
            ? const Color(0xFF302823)
            : const Color(0xFFF4EEE5),
        surfaceContainer: dark
            ? const Color(0xFF28221E)
            : const Color(0xFFFAF6EF),
        surfaceContainerLow: dark
            ? const Color(0xFF221D19)
            : const Color(0xFFFFFDFA),
        surfaceContainerLowest: dark ? const Color(0xFF171310) : cream,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: scheme.primary,
      brightness: b,
    ),
    colorScheme: scheme,
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.secondaryContainer,
      disabledColor: scheme.surfaceContainerHigh,
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide.none,
    ),
    scaffoldBackgroundColor: dark ? const Color(0xFF1A1715) : cream,
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF1A1715) : cream,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .5),
      thickness: .6,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF1A1715) : cream,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
  );
}

class BeanPhoto extends StatelessWidget {
  final String photo;
  final String? directory;
  final bool thumbnail;
  final double? width, height;
  const BeanPhoto({
    super.key,
    required this.photo,
    required this.directory,
    this.thumbnail = true,
    this.width,
    this.height,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: SizedBox(
      width: width,
      height: height,
      child: photo.isEmpty || directory == null
          ? const ColoredBox(
              color: Color(0xFFEDE1CE),
              child: CoffeeArt(bean: true),
            )
          : Image.file(
              File('$directory/${thumbnail ? 'thumb-' : ''}$photo'),
              fit: BoxFit.cover,
              cacheWidth: thumbnail ? 360 : 1600,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFEDE1CE),
                child: CoffeeArt(bean: true),
              ),
            ),
    ),
  );
}

void showBeanPhoto(BuildContext context, String photo, String? directory) {
  if (photo.isEmpty || directory == null) return;
  Navigator.of(context).push(
    CoffeeRoute(
      context: context,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('豆袋照片')),
        body: Center(
          child: InteractiveViewer(
            minScale: .8,
            maxScale: 4,
            child: BeanPhoto(
              photo: photo,
              directory: directory,
              thumbnail: false,
            ),
          ),
        ),
      ),
    ),
  );
}

class CoffeeScroll extends MaterialScrollBehavior {
  const CoffeeScroll();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  const Press({super.key, required this.child, this.onTap, this.label});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool down = false;
  @override
  Widget build(BuildContext c) => Semantics(
    button: true,
    label: widget.label,
    enabled: widget.onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: down ? 0.975 : 1,
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(c) ? 0 : 120,
        ),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    ),
  );
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  @override
  Widget build(BuildContext c) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? panel(c),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: ink(c).withValues(alpha: .045)),
    ),
    child: child,
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.4,
      color: muted(c),
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String english, title, subtitle;
  final Widget? trailing;
  const PageHeading(
    this.english,
    this.title,
    this.subtitle, {
    super.key,
    this.trailing,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(english),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: muted(c), height: 1.4),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title, aside;
  const SectionTitle(this.title, {super.key, this.aside = ''});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        Text(aside, style: TextStyle(fontSize: 11, color: muted(c))),
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  const Tag(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(c).colorScheme.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: Theme.of(c).colorScheme.primary),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, detail;
  final VoidCallback? onTap;
  final String action;
  const EmptyState(
    this.title,
    this.detail, {
    super.key,
    this.onTap,
    this.action = '记下第一杯',
  });
  @override
  Widget build(BuildContext c) => Surface(
    child: Column(
      children: [
        const SizedBox(height: 6),
        const SizedBox(width: 110, height: 95, child: CoffeeArt()),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.7, color: muted(c)),
        ),
        if (onTap != null) ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: onTap, child: Text(action)),
        ],
        const SizedBox(height: 6),
      ],
    ),
  );
}

class CoffeeArt extends StatelessWidget {
  final bool bean;
  const CoffeeArt({super.key, this.bean = false});
  @override
  Widget build(BuildContext c) => RepaintBoundary(
    child: CustomPaint(painter: _CoffeePainter(bean: bean)),
  );
}

class _CoffeePainter extends CustomPainter {
  final bool bean;
  _CoffeePainter({this.bean = false});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final s = math.min(size.width, size.height) / 180;
    canvas.scale(s);
    final p = Paint()..isAntiAlias = true;
    if (bean) {
      for (final pos in [const Offset(-25, -14), const Offset(23, 17)]) {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(-.55);
        p.color = const Color(0xFF6D432B);
        canvas.drawOval(const Rect.fromLTWH(-23, -37, 46, 74), p);
        p
          ..color = const Color(0xFFE4BC91)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawPath(
          Path()
            ..moveTo(0, -30)
            ..cubicTo(-14, -8, 15, 4, 0, 30),
          p,
        );
        p.style = PaintingStyle.fill;
        canvas.restore();
      }
    } else {
      p.color = const Color(0xFF000000).withValues(alpha: .07);
      canvas.drawOval(const Rect.fromLTWH(-65, -40, 140, 114), p);
      p.color = const Color(0xFFEADAC5);
      canvas.drawCircle(Offset.zero, 74, p);
      p.color = const Color(0xFFF9F2E7);
      canvas.drawCircle(Offset.zero, 68, p);
      p
        ..color = const Color(0xFFF9F2E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12;
      canvas.drawOval(const Rect.fromLTWH(45, -16, 37, 34), p);
      p.style = PaintingStyle.fill;
      p.color = const Color(0xFFCDB396);
      canvas.drawCircle(Offset.zero, 51, p);
      p.shader = const RadialGradient(
        colors: [Color(0xFFC88750), Color(0xFF633723)],
      ).createShader(const Rect.fromLTWH(-48, -48, 96, 96));
      canvas.drawCircle(Offset.zero, 47, p);
      p.shader = null;
      canvas.save();
      canvas.rotate(-.4);
      p.color = const Color(0xFFF8DFBA);
      for (var i = 0; i < 5; i++) {
        final y = 21.0 - i * 10;
        final w = 25.0 - i * 4;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(-w / 2 + 2, y), width: w, height: 8),
          p,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w / 2 - 2, y), width: w, height: 8),
          p,
        );
      }
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawPath(
        Path()
          ..moveTo(0, 30)
          ..quadraticBezierTo(5, 0, 0, -27),
        p,
      );
      p.style = PaintingStyle.fill;
      canvas.restore();
      p.color = const Color(0xFF98775A);
      canvas.save();
      canvas.translate(-61, 62);
      canvas.rotate(-.5);
      canvas.drawOval(const Rect.fromLTWH(-7, -11, 14, 22), p);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoffeePainter old) => old.bean != bean;
}

String clock(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
String money(int cents) =>
    (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
void message(BuildContext c, String text) => ScaffoldMessenger.of(c)
    .showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
    );
