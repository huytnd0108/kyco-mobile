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

  @override
  String get navServices => 'Dịch vụ';

  @override
  String get navMessages => 'Tin nhắn';

  @override
  String get bookNow => 'Đặt ngay';

  @override
  String get bookNowKicker => 'Đặt lịch nhanh';

  @override
  String get servicesTitle => 'Dịch vụ';

  @override
  String get searchHint => 'Tìm dịch vụ…';

  @override
  String get allCategories => 'Tất cả';

  @override
  String get viewDetails => 'Xem chi tiết';

  @override
  String get viewAll => 'Xem tất cả';

  @override
  String fromPrice(String price) {
    return 'từ $price';
  }

  @override
  String minutesShort(int n) {
    return '$n phút';
  }

  @override
  String get noResults => 'Không có kết quả';

  @override
  String get popularCategories => 'Danh mục phổ biến';

  @override
  String get howItWorks => 'Cách hoạt động';

  @override
  String get whyKyco => 'Vì sao chọn Kyco';

  @override
  String get exploreServices => 'Khám phá dịch vụ';

  @override
  String get relatedServices => 'Dịch vụ liên quan';

  @override
  String get reviewsTitle => 'Đánh giá';

  @override
  String reviewCount(int n) {
    return '$n đánh giá';
  }

  @override
  String get providersAvailable => 'Đối tác sẵn sàng';

  @override
  String get checkoutTitle => 'Đặt dịch vụ';

  @override
  String get dateLabel => 'Ngày';

  @override
  String get timeLabel => 'Giờ';

  @override
  String get wardLabel => 'Phường xã';

  @override
  String get neighborhoodLabel => 'Khu phố';

  @override
  String get addressLineLabel => 'Địa chỉ';

  @override
  String get notesLabel => 'Ghi chú';

  @override
  String get subtotalLabel => 'Tạm tính';

  @override
  String get confirmBooking => 'Xác nhận đặt lịch';

  @override
  String get signInToConfirm => 'Đăng nhập để xác nhận';

  @override
  String get guestCheckoutNotice =>
      'Bạn có thể điền đầy đủ — chỉ cần đăng nhập khi xác nhận.';

  @override
  String get draftRestored => 'Đã khôi phục thông tin';

  @override
  String get deferredPaymentNotice =>
      'Thanh toán sau khi hoàn thành — tiền mặt.';

  @override
  String bookingCreated(Object id) {
    return 'Đã đặt lịch #$id';
  }

  @override
  String get step1Category => '1. Chọn danh mục';

  @override
  String get step2Service => '2. Chọn dịch vụ';

  @override
  String get locationsTitle => 'Khu vực phục vụ';

  @override
  String cityServices(String city) {
    return 'Dịch vụ tại $city';
  }

  @override
  String get providerTitle => 'Hồ sơ đối tác';

  @override
  String get verifiedBadge => 'Đã xác minh';

  @override
  String jobsCompleted(int n) {
    return '$n công việc';
  }

  @override
  String memberSince(String date) {
    return 'Thành viên từ $date';
  }

  @override
  String get subscriptionsTitle => 'Gói định kỳ';

  @override
  String perMonth(String price) {
    return '$price/tháng';
  }

  @override
  String get notificationsTitle => 'Thông báo';

  @override
  String get markAllRead => 'Đánh dấu đã đọc';

  @override
  String get messagesTitle => 'Tin nhắn';

  @override
  String get noMessages => 'Chưa có tin nhắn';

  @override
  String get signInToView => 'Đăng nhập để xem';

  @override
  String get inviteFriends => 'Mời bạn bè';

  @override
  String get becomePartner => 'Trở thành đối tác';

  @override
  String get contactUs => 'Liên hệ';

  @override
  String get aboutKyco => 'Về Kyco';

  @override
  String get faqs => 'Câu hỏi thường gặp';

  @override
  String get notSignedIn => 'Chưa đăng nhập';

  @override
  String get loadMore => 'Tải thêm';
}
