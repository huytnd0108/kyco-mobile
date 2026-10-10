import 'package:kyco_mobile/core/api/token_store.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';

/// Fixed, boundary-hunting fake data for goldens — never random.
class Fakes {
  static const user = AuthUser(id: 7, role: 'customer', name: 'Ngọc Anh');
  static const signedIn = AuthState(status: AuthStatus.signedIn, user: user);
  static const signedOut = AuthState(status: AuthStatus.signedOut);
  static const signedOutError =
      AuthState(status: AuthStatus.signedOut, error: 'Email hoặc mật khẩu không đúng');

  /// imageUrl null → deterministic _CardPlaceholder (no network). One long name
  /// pins the maxLines:2 ellipsis.
  static HomeComposite home({int count = 8}) => HomeComposite(categories: [
        for (var i = 0; i < count; i++)
          ServiceCategory(id: i + 1, name: _catNames[i % _catNames.length]),
      ]);
  static const _catNames = [
    'Vệ sinh nhà theo giờ', 'Tổng vệ sinh', 'Vệ sinh máy lạnh',
    'Vệ sinh sofa – nệm – rèm cửa cao cấp định kỳ', // ellipsis canary
    'Giặt thảm', 'Vệ sinh kính', 'Khử khuẩn', 'Vệ sinh văn phòng',
  ];
  static HomeComposite homeEmpty() => const HomeComposite(categories: []);

  /// One booking per _StatusChip branch + the model's null paths. createdAt at
  /// noon UTC → same calendar date in any realistic host TZ (TZ-independent).
  static List<Booking> bookings() => const [
        Booking(id: 1042, status: 'PENDING', serviceName: 'Vệ sinh nhà theo giờ', totalVnd: 480000, createdAt: '2026-01-15T12:00:00Z'),
        Booking(id: 1041, status: 'CONFIRMED', serviceName: 'Vệ sinh máy lạnh treo tường 2 chiều công suất lớn', totalVnd: 12345678, createdAt: '2026-01-12T12:00:00Z'),
        Booking(id: 1040, status: 'COMPLETED', serviceName: 'Tổng vệ sinh', totalVnd: 2400000, createdAt: '2026-01-08T12:00:00Z'),
        Booking(id: 1039, status: 'SETTLED', serviceName: 'Giặt thảm', totalVnd: 350000, createdAt: '2025-12-30T12:00:00Z'),
        Booking(id: 1038, status: 'CANCELLED', serviceName: null, totalVnd: null, createdAt: null),
        Booking(id: 1037, status: 'BAD_DEBT', serviceName: 'Khử khuẩn', totalVnd: 900000, createdAt: '2025-12-01T12:00:00Z'),
        Booking(id: 1036, status: 'SOMETHING_NEW', serviceName: 'Vệ sinh kính', totalVnd: 150000, createdAt: '2025-11-20T12:00:00Z'),
      ];
}

/// Fixed-state AuthController for goldens (never bootstraps / hits the API).
class FakeAuthController extends AuthController {
  FakeAuthController(this._fixed);
  final AuthState _fixed;
  @override
  AuthState build() => _fixed;
  @override
  Future<void> bootstrap() async {}
}

/// Copy of the fake in test/api_client_test.dart (which stays untouched).
class InMemoryTokenStore implements TokenStore {
  String? _a;
  String? _r;
  DateTime? _exp;
  @override
  Future<String?> get accessToken async => _a;
  @override
  Future<String?> get refreshToken async => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }
  @override
  Future<void> setAccess(String access) async => _a = access;
  @override
  Future<DateTime?> get accessExpiresAt async => _exp;
  @override
  Future<void> setAccessExpiresAt(DateTime? at) async => _exp = at;
  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
    _exp = null;
  }
  @override
  Future<bool> get hasSession async => _a != null;
}
