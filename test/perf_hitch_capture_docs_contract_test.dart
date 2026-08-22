import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String playbook;

  setUpAll(() {
    playbook = File('docs/perf-hitch-capture.md').readAsStringSync();
  });

  test('perf hitch playbook has required section headings', () {
    const required = <String>[
      '## Goal',
      '## Build',
      '## Instruments template',
      '## Scenario scripts',
      '## Export checklist',
    ];
    for (final heading in required) {
      expect(
        playbook.contains(heading),
        isTrue,
        reason: 'missing heading $heading',
      );
    }
  });

  test('scenario log template exists with cluster placeholders', () {
    final scenario = File('docs/pro-scenario.md').readAsStringSync();
    expect(scenario.contains('Cluster A'), isTrue);
    expect(scenario.contains('Cluster D'), isTrue);
    expect(scenario.contains('ChatOpenPerf'), isTrue);
  });

  test('display-only archive exists for 2026-08-22 capture', () {
    expect(File('docs/pro-display-2026-08-22.md').existsSync(), isTrue);
  });
}
