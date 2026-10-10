import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../config.dart';
import '../di.dart';

/// The numeric id of an internal `media:<id>` image reference, else null.
int? mediaIdOf(String? url) {
  if (url == null || !url.startsWith('media:')) return null;
  return int.tryParse(url.substring('media:'.length).trim());
}

/// Cache key of [mediaReadUrlProvider]: the media id plus the auth state, so an
/// anonymous result is never served to (or from) a signed-in session.
typedef MediaReadKey = ({int id, bool signedIn});

/// Resolves an internal `media:<id>` reference to a short-lived signed https
/// URL via `GET /v1/media/{id}` (UX-M15).
///
/// Signed-in users use the Bearer call. Signed-out visitors make the same call
/// with `auth: false` (no token; the backend serves public catalogue media only
/// and 404s the rest). Only catalogue surfaces reach this (via
/// [ResolvedImageUrl]: ServiceCard, CategoryTile, service-detail and
/// city-service heroes). Any failure (401/403/404/network, or an older
/// Bearer-only backend) resolves to null and the caller keeps its placeholder.
/// The URL is cached for most of its lifetime, then dropped so a stale
/// signature is never reused.
final mediaReadUrlProvider = FutureProvider.autoDispose.family<String?, MediaReadKey>((ref, key) async {
  try {
    final r = await ref.watch(kycoApiProvider).mediaReadUrl(key.id, anonymous: !key.signedIn);
    if (r.url != null && r.expiresInSeconds > 60) {
      final link = ref.keepAlive();
      final t = Timer(Duration(seconds: r.expiresInSeconds - 30), link.close);
      ref.onDispose(t.cancel);
    }
    return r.url;
  } catch (_) {
    return null;
  }
});

/// Normalises a raw `imageUrl` into something `Image.network` can load, or
/// null: absolute http(s) (any host) passes through; protocol-relative
/// `//host/x` becomes https; a root-relative `/images/x` resolves against the
/// website origin (as the browser does on kyco.vn). `media:<id>` and anything
/// unrecognised return null (media ids go through [mediaReadUrlProvider]).
String? resolveImageUrl(String? raw) {
  final u = raw?.trim();
  if (u == null || u.isEmpty) return null;
  final lower = u.toLowerCase();
  if (lower.startsWith('https://') || lower.startsWith('http://')) {
    return Uri.tryParse(u)?.hasAuthority == true ? u : null;
  }
  if (u.startsWith('//')) return 'https:$u';
  if (u.startsWith('/')) return '${AppConfig.webBase}$u';
  return null;
}

/// Last resort for a `media:<id>` list/home image the anonymous media endpoint
/// could not sign: the service detail endpoint resolves it server-side (that is
/// what the website renders). Null when it has no loadable image either.
final serviceImageFallbackProvider =
    FutureProvider.autoDispose.family<String?, int>((ref, serviceId) async {
  try {
    final d = await ref.watch(kycoApiProvider).serviceDetail(serviceId);
    return resolveImageUrl(d.imageUrl);
  } catch (_) {
    return null;
  }
});

/// Gives [builder] a loadable image URL for [url] (see [resolveImageUrl];
/// `media:<id>` is resolved through [mediaReadUrlProvider], falling back to the
/// service detail when [fallbackServiceId] is given). While resolving (or when
/// it cannot be resolved) [builder] gets a null URL.
class ResolvedImageUrl extends ConsumerWidget {
  const ResolvedImageUrl({super.key, required this.url, required this.builder, this.fallbackServiceId});
  final String? url;
  final int? fallbackServiceId;
  final Widget Function(BuildContext context, String? resolvedUrl, bool loading) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = url;
    if (raw == null || raw.trim().isEmpty) return builder(context, null, false);
    final id = mediaIdOf(raw);
    if (id == null) return builder(context, resolveImageUrl(raw), false);
    final signedIn = ref.watch(authUserIdProvider) != null;
    final async = ref.watch(mediaReadUrlProvider((id: id, signedIn: signedIn)));
    if (async.isLoading) return builder(context, null, true);
    final direct = async.valueOrNull;
    if (direct != null || fallbackServiceId == null) return builder(context, direct, false);
    final fb = ref.watch(serviceImageFallbackProvider(fallbackServiceId!));
    return builder(context, fb.valueOrNull, fb.isLoading);
  }
}
