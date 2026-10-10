import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The tasker (CTV) home in a single hop: `GET /api/v1/tasker/workspace`
/// returns the dashboard (KPI 30d + job counts + earnings), the first assigned-
/// jobs page and the current goals — all in one Bearer read. The `/p` home
/// screen watches this and renders via `AsyncValue.when`. Money in the payload
/// is server-derived and DISPLAY-ONLY here — the app never computes an amount.
///
/// autoDispose so leaving the tasker shell drops the cache; a `RefreshIndicator`
/// pull `invalidate`s it to refetch.
final taskerWorkspaceProvider =
    FutureProvider.autoDispose<TaskerWorkspace>((ref) async {
  return ref.watch(kycoApiProvider).taskerWorkspace();
});
