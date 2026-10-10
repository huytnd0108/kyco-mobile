import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/problem.dart';
import '../../core/api/kyco_api.dart';
import '../../core/di.dart';

/// Fetch the current month's wallet ledger as CSV bytes
/// (`GET /v1/tasker/wallet/export?year&month`) and hand them to the OS share
/// sheet. Returns null on success, or a short human message on failure — the
/// caller shows it in a snackbar. Bytes are never written anywhere persistent.
Future<String?> exportWalletCsv(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final now = DateTime.now();
  try {
    final bytes = await ref
        .read(kycoApiProvider)
        .walletExportCsv(year: now.year, month: now.month);
    final fileName = 'kyco-wallet-${now.year}-${now.month.toString().padLeft(2, '0')}.csv';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: 'text/csv',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'Kyco wallet ${now.year}-${now.month.toString().padLeft(2, '0')}',
      ),
    );
    return null;
  } on ApiException catch (e) {
    return e.isMaintenance ? l.provWalletExportMaintenance : e.message;
  } catch (_) {
    return l.genericError;
  }
}
