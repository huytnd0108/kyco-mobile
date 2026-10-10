import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Paths that are the ROOT page of a tab in one of the two shells. Pushing one
/// of these over a live shell from a root-level screen (e.g. a notification
/// link to `/bookings`) re-reserves the shell's navigator keys and trips the
/// Navigator `keyReservation` assertion (OCD-025), so they are navigated with
/// `go` (switch tab) instead of `push`.
const _shellTabRoots = {
  '/',
  '/services',
  '/bookings',
  '/messages',
  '/account',
  '/p',
  '/p/jobs',
  '/p/wallet',
  '/p/availability',
  '/p/more',
};

bool isShellTabRoot(String target) {
  final uri = Uri.tryParse(target);
  return uri != null && _shellTabRoots.contains(uri.path);
}

/// Open an in-app [target] from anywhere: tab roots switch tabs (`go`), every
/// other (root-navigator) route is pushed so Back returns to the caller.
void openInApp(BuildContext context, String target) {
  if (isShellTabRoot(target)) {
    context.go(target);
  } else {
    context.push(target);
  }
}
