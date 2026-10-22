// Opt-in profiling entrypoint. Production packages use lib/main.dart.
// flutter build apk --profile --target tools/profile_main.dart --no-pub
import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:coffee_journal/main.dart' as app;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final started = DateTime.now();
  final build = <int>[], raster = <int>[];
  SchedulerBinding.instance.addTimingsCallback((frames) {
    if (DateTime.now().difference(started).inSeconds < 3) return;
    for (final f in frames) {
      build.add(f.buildDuration.inMicroseconds);
      raster.add(f.rasterDuration.inMicroseconds);
    }
  });
  var previous = 0;
  Timer.periodic(const Duration(seconds: 5), (_) {
    if (build.length == previous || build.isEmpty) return;
    previous = build.length;
    Map<String, num> summary(List<int> raw) {
      final values = [...raw]..sort();
      return {
        'medianMs': values[values.length ~/ 2] / 1000,
        'p90Ms': values[((values.length - 1) * .9).round()] / 1000,
        'maxMs': values.last / 1000,
        'over16_67ms': values.where((v) => v > 16667).length,
      };
    }

    // ignore: avoid_print
    print(
      'COFFEE_PROFILE ${jsonEncode({'frames': build.length, 'build': summary(build), 'raster': summary(raster)})}',
    );
  });
  app.main();
}
