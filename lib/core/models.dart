// Barrel over the split model files. Every screen/test imports
// `core/models.dart` (or `package:kyco_mobile/core/models.dart`) and gets the
// full typed surface for the kyco /api/v1 responses. All models parse
// tolerantly — the backend envelope wraps these as `{ ok:true, data, meta? }`.
export 'models/auth.dart';
export 'models/catalog.dart';
export 'models/home.dart';
export 'models/locations.dart';
export 'models/booking.dart';
export 'models/social.dart';
