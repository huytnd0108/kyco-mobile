import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/kyco_api.dart';

/// Why a native capture could not produce a value. Every failure mode is a
/// user-facing branch — nothing here throws past the call site, so the screen
/// can show a graceful message instead of a red error frame.
enum CaptureFailure {
  /// Device location services are switched off entirely.
  locationServiceOff,

  /// The runtime permission was denied this once.
  permissionDenied,

  /// Denied permanently ("Don't ask again" / iOS Settings) — needs Settings.
  permissionDeniedForever,

  /// The user backed out of the camera / permission sheet without capturing.
  cancelled,

  /// Anything else (timeout, plugin error, upload transport failure).
  error,
}

/// A real GPS fix. Fields map straight onto `checkIn(lat, lon, accuracyM)` and
/// `checkOut(lat, lng, accuracyM)` — the app NEVER fabricates coordinates.
class GpsFix {
  const GpsFix({required this.lat, required this.lon, this.accuracyM});
  final double lat;
  final double lon;
  final double? accuracyM;
}

/// Discriminated result: exactly one of [fix] / [failure] is non-null.
class GpsResult {
  const GpsResult._(this.fix, this.failure);
  const GpsResult.ok(GpsFix fix) : this._(fix, null);
  const GpsResult.fail(CaptureFailure failure) : this._(null, failure);
  final GpsFix? fix;
  final CaptureFailure? failure;
  bool get isOk => fix != null;
}

/// Requests a single high-accuracy position, handling the full geolocator
/// permission ladder gracefully (service off → denied → deniedForever).
class LocationService {
  const LocationService();

  Future<GpsResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const GpsResult.fail(CaptureFailure.locationServiceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return const GpsResult.fail(CaptureFailure.permissionDeniedForever);
      }
      if (perm == LocationPermission.denied) {
        return const GpsResult.fail(CaptureFailure.permissionDenied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return GpsResult.ok(GpsFix(lat: pos.latitude, lon: pos.longitude, accuracyM: pos.accuracy));
    } catch (_) {
      return const GpsResult.fail(CaptureFailure.error);
    }
  }
}

/// Result of a full capture→upload round-trip. On success [mediaId] is the
/// finalized asset id to hand to `uploadJobPhotos`.
class PhotoUploadResult {
  const PhotoUploadResult._(this.mediaId, this.failure);
  const PhotoUploadResult.ok(int mediaId) : this._(mediaId, null);
  const PhotoUploadResult.fail(CaptureFailure failure) : this._(null, failure);
  final int? mediaId;
  final CaptureFailure? failure;
  bool get isOk => mediaId != null;
}

/// Camera capture → presigned upload → finalize. Wraps image_picker (which
/// throws a PlatformException `camera_access_denied` on a permission refusal)
/// and the three-step media flow (request-upload → PUT bytes to GCS → finalize).
class PhotoCaptureService {
  const PhotoCaptureService(this._api, {ImagePicker? picker, Dio? uploader})
      : _picker = picker,
        _uploader = uploader;

  final KycoApi _api;
  final ImagePicker? _picker;
  final Dio? _uploader;

  Future<PhotoUploadResult> captureAndUpload({required String purpose}) async {
    final XFile? shot;
    try {
      shot = await (_picker ?? ImagePicker()).pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 2048,
      );
    } catch (e) {
      // image_picker surfaces a permission refusal as this platform code.
      final denied = e.toString().contains('camera_access_denied');
      return PhotoUploadResult.fail(
          denied ? CaptureFailure.permissionDenied : CaptureFailure.error);
    }
    if (shot == null) return const PhotoUploadResult.fail(CaptureFailure.cancelled);

    try {
      final bytes = await shot.readAsBytes();
      final contentType = shot.mimeType ?? _mimeForName(shot.name);

      // 1. request-upload → { mediaId/assetId, uploadUrl, requiredContentType }.
      final signed = await _api.requestMediaUpload(
        contentType: contentType,
        sizeBytes: bytes.length,
        purpose: purpose,
      );
      final uploadUrl = signed['uploadUrl'] as String?;
      final mediaId = (signed['mediaId'] ?? signed['assetId']);
      final requiredCt = (signed['requiredContentType'] as String?) ?? contentType;
      final key = (signed['key'] ?? signed['objectKey'] ?? '') as String;
      if (uploadUrl == null || mediaId is! num) {
        return const PhotoUploadResult.fail(CaptureFailure.error);
      }

      // 2. PUT the bytes straight to the signed (GCS) URL — no app auth, own Dio.
      await (_uploader ?? Dio()).put<void>(
        uploadUrl,
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': requiredCt,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      // 3. finalize → commit the object (pending → ready).
      await _api.finalizeMedia(key: key, mediaId: mediaId.toInt());
      return PhotoUploadResult.ok(mediaId.toInt());
    } catch (_) {
      return const PhotoUploadResult.fail(CaptureFailure.error);
    }
  }

  static String _mimeForName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
