// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Kyco';

  @override
  String get login => 'Đăng nhập';

  @override
  String get signup => 'Đăng ký';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get email => 'Email';

  @override
  String get emailInvalid => 'Email không hợp lệ';

  @override
  String get password => 'Mật khẩu';

  @override
  String get passwordMin8 => 'Tối thiểu 8 ký tự';

  @override
  String get showPassword => 'Hiện mật khẩu';

  @override
  String get hidePassword => 'Ẩn mật khẩu';

  @override
  String get fullName => 'Họ tên';

  @override
  String get createAccount => 'Tạo tài khoản';

  @override
  String get noAccountSignup => 'Chưa có tài khoản? Đăng ký';

  @override
  String get haveAccountLogin => 'Đã có tài khoản? Đăng nhập';

  @override
  String get browseWithoutLogin => 'Xem dịch vụ (không cần đăng nhập)';

  @override
  String get genericError => 'Có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get retry => 'Thử lại';

  @override
  String helloGreeting(String name) {
    return 'Xin chào, $name 👋';
  }

  @override
  String get homeTagline => 'Dịch vụ vệ sinh nhà cửa';

  @override
  String get noServicesYet => 'Chưa có dịch vụ nào — sắp ra mắt.';

  @override
  String homeLoadError(String error) {
    return 'Không tải được trang chủ.\n$error';
  }

  @override
  String get myBookings => 'Đơn của tôi';

  @override
  String bookingsLoadError(String error) {
    return 'Không tải được đơn.\n$error';
  }

  @override
  String get noBookingsYet => 'Chưa có đơn nào.';

  @override
  String bookingNumber(Object id) {
    return 'Đơn #$id';
  }

  @override
  String get bookingDetailTitle => 'Chi tiết đơn';

  @override
  String get selectBookingPlaceholder => 'Chọn một đơn để xem chi tiết';

  @override
  String bookingNotFound(Object id) {
    return 'Không tìm thấy đơn #$id';
  }

  @override
  String get statusLabel => 'Trạng thái';

  @override
  String get totalLabel => 'Tổng tiền';

  @override
  String get createdLabel => 'Ngày tạo';

  @override
  String get serviceLabel => 'Dịch vụ';

  @override
  String get statusPending => 'Chờ xác nhận';

  @override
  String get statusConfirmed => 'Đã xác nhận';

  @override
  String get statusCompleted => 'Hoàn thành';

  @override
  String get statusSettled => 'Đã thanh toán';

  @override
  String get statusCancelled => 'Đã hủy';

  @override
  String get statusBadDebt => 'Nợ xấu';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navBookings => 'Đơn của tôi';

  @override
  String get navAccount => 'Tài khoản';

  @override
  String get accountTitle => 'Tài khoản';

  @override
  String get myAccount => 'Tài khoản của tôi';

  @override
  String get appearance => 'Giao diện';

  @override
  String get themeSystem => 'Theo hệ thống';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get langSystem => 'Theo hệ thống';

  @override
  String get langVi => 'Tiếng Việt';

  @override
  String get langEn => 'English';

  @override
  String get signInPrompt => 'Đăng nhập để xem đơn và tài khoản của bạn';

  @override
  String pageNotFound(Object uri) {
    return 'Không tìm thấy trang: $uri';
  }
}
