import 'dart:async';

import '../goldens/flutter_test_config.dart' as base;

/// Real fonts (not Ahem) for the full-app router tests so layouts match devices.
Future<void> testExecutable(FutureOr<void> Function() testMain) => base.testExecutable(testMain);
