import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/di.dart';
import '../../core/ui/error_text.dart';
import '../tasker_job_detail/native_capture.dart';

/// Resolves a best-effort GPS fix for the SOS payload. Overridden in tests.
typedef SosLocator = Future<GpsFix?> Function();

final sosLocatorProvider = Provider<SosLocator>((ref) {
  return () async {
    try {
      final gps = await const LocationService().currentPosition().timeout(const Duration(seconds: 8));
      return gps.fix;
    } catch (_) {
      return null; // never let a slow / denied GPS delay or block the alert
    }
  };
});

/// "Báo sự cố khẩn cấp" on an active booking (UX-M13): confirm -> best-effort
/// GPS -> `POST /v1/sos {bookingId, lat, lng, accuracyM}`. The server accepts
/// customers, attributes the booking only when the caller owns it, dedups
/// repeat presses for 90 s and never blocks an emergency.
class CustomerSosButton extends ConsumerStatefulWidget {
  const CustomerSosButton({super.key, required this.bookingId});
  final int bookingId;

  @override
  ConsumerState<CustomerSosButton> createState() => _CustomerSosButtonState();
}

class _CustomerSosButtonState extends ConsumerState<CustomerSosButton> {
  bool _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.emergency, color: Theme.of(ctx).colorScheme.error),
        title: Text(l.sosCustomerTitle),
        content: Text(l.sosCustomerBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cust2Cancel)),
          FilledButton(
            key: const ValueKey('sos-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.provJdSosConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final fix = await ref.read(sosLocatorProvider)();
      await ref.read(kycoApiProvider).triggerSos(
            bookingId: widget.bookingId,
            lat: fix?.lat,
            lng: fix?.lon,
            accuracyM: fix?.accuracyM,
            note: 'SOS from the Kyco customer app',
          );
      messenger.showSnackBar(SnackBar(content: Text(l.provJdSosSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      key: const ValueKey('customer-sos'),
      onPressed: _busy ? null : _press,
      icon: _busy
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sos),
      label: Text(l.sosCustomerCta),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.error,
        side: BorderSide(color: cs.error),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
