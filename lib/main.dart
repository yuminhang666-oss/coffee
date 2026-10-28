import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/controller.dart';
import 'ui/app.dart';
import 'ui/design.dart';
import 'ui/flavor_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final controller = CoffeeController(AndroidStore());
  runApp(CoffeeApp(controller: controller));
  await controller.load();
}

class CoffeeApp extends StatelessWidget {
  final CoffeeController controller;
  const CoffeeApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: '咖啡手记',
      debugShowCheckedModeBanner: false,
      theme: coffeeTheme(Brightness.light),
      darkTheme: coffeeTheme(Brightness.dark),
      themeMode: switch (controller.data.theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const CoffeeScroll(),
      builder: (c, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(c).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                systemNavigationBarColor: Colors.transparent,
              ),
        child: FlavorPalette(
          terms: controller.data.customFlavors,
          child: child!,
        ),
      ),
      home: CoffeeRoot(controller: controller),
    ),
  );
}
