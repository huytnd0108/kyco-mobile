import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/kyco_api.dart';
import '../../core/config.dart';

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

/// The media category the backend expects for a job-photo slot — mirrors
/// lib/provider/job-photos-write.ts (`before` → `checkin`, `mid`/`after` →
/// `checkout`). The photos route silently DROPS an asset whose category does not
/// match its slot, so this mapping must stay in lockstep with the server.
String mediaCategoryForSlot(String slotWire) => slotWire == 'before' ? 'checkin' : 'checkout';

/// Resolve the upload URL the server returned. Production mints an absolute V4
/// GCS URL; a same-origin relative path (a local/dev storage adapter) is
/// resolved against the API origin so the PUT reaches the backend host.
Uri resolveUploadUrl(String uploadUrl, {String apiBase = AppConfig.apiBase}) {
  final u = Uri.parse(uploadUrl);
  return u.hasScheme ? u : Uri.parse(apiBase).resolveUri(u);
}

/// Camera capture → signed-URL upload → finalize. Wraps image_picker (which
/// throws a PlatformException `camera_access_denied` on a permission refusal)
/// and the three-step media flow:
///   1. POST /media/request-upload {category, entityType:'booking', entityId:
///      bookingId, fileName, mimeType, sizeBytes} → {assetId, uploadUrl,
///      requiredContentType}
///   2. PUT the raw bytes to uploadUrl with Content-Type == requiredContentType
///      (signed header) — no app auth, own Dio
///   3. POST /media/finalize {mediaId} (server HEADs the object → ready)
/// The caller then attaches the asset via POST /provider/jobs/{id}/photos.
class PhotoCaptureService {
  const PhotoCaptureService(this._api, {ImagePicker? picker, Dio? uploader})
      : _picker = picker,
        _uploader = uploader;

  final KycoApi _api;
  final ImagePicker? _picker;
  final Dio? _uploader;

  Future<PhotoUploadResult> captureAndUpload({
    required int bookingId,
    required String slotWire,
  }) async {
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
      return await uploadBytes(
        bookingId: bookingId,
        slotWire: slotWire,
        bytes: bytes,
        fileName: shot.name,
        mimeType: shot.mimeType,
      );
    } catch (_) {
      return const PhotoUploadResult.fail(CaptureFailure.error);
    }
  }

  /// Steps 1–3 for already-captured bytes (split out so the wire contract is
  /// testable without a camera). Never throws.
  Future<PhotoUploadResult> uploadBytes({
    required int bookingId,
    required String slotWire,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      if (bytes.isEmpty) return const PhotoUploadResult.fail(CaptureFailure.error);
      final contentType = (mimeType == null || mimeType.isEmpty)
          ? mimeForFileName(fileName)
          : mimeType.toLowerCase();
      final name = fileName.isEmpty ? 'photo.${extForMime(contentType)}' : fileName;

      // 1. request-upload.
      final ticket = await _api.requestMediaUpload(
        category: mediaCategoryForSlot(slotWire),
        entityType: 'booking',
        entityId: bookingId,
        fileName: name,
        mimeType: contentType,
        sizeBytes: bytes.length,
      );
      if (!ticket.isUsable) return const PhotoUploadResult.fail(CaptureFailure.error);

      // 2. PUT the bytes to the signed URL. The Content-Type is part of the V4
      //    signature, so send EXACTLY requiredContentType.
      final res = await (_uploader ?? Dio()).putUri<void>(
        resolveUploadUrl(ticket.uploadUrl!),
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: ticket.requiredContentType ?? contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          validateStatus: (_) => true,
        ),
      );
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return const PhotoUploadResult.fail(CaptureFailure.error);
      }

      // 3. finalize → pending → ready.
      await _api.finalizeMedia(mediaId: ticket.assetId!);
      return PhotoUploadResult.ok(ticket.assetId!);
    } catch (_) {
      return const PhotoUploadResult.fail(CaptureFailure.error);
    }
  }
}
