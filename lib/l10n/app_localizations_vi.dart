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

  @override
  String get noReviewsYet => 'Chưa có đánh giá';

  @override
  String get noDescription => 'Chưa có mô tả';

  @override
  String get serviceNotFound => 'Không tìm thấy dịch vụ';

  @override
  String get partnerNotFound => 'Không tìm thấy đối tác';

  @override
  String get noNotifications => 'Chưa có thông báo';

  @override
  String wardsCount(Object count) {
    return '$count khu vực';
  }

  @override
  String get completeRequiredFields => 'Vui lòng điền đủ thông tin bắt buộc';

  @override
  String get confirmationCode => 'Mã xác nhận';

  @override
  String get mySubscriptions => 'Gói của tôi';

  @override
  String get plansTitle => 'Các gói';

  @override
  String monthsCount(Object count) {
    return '$count tháng';
  }

  @override
  String get noActiveSubscriptions => 'Chưa có gói đang hoạt động';

  @override
  String sessionsProgress(Object done, Object total) {
    return 'Buổi $done/$total';
  }

  @override
  String nextChargeLabel(Object date) {
    return 'Kỳ tính kế: $date';
  }

  @override
  String get manageOnWeb => 'Tạo hoặc đổi gói trên kyco.vn';

  @override
  String get provWorkspace => 'Khu vực đối tác';

  @override
  String get provComingSoon => 'Sắp ra mắt';

  @override
  String get provTabHome => 'Trang chủ';

  @override
  String get provTabJobs => 'Công việc';

  @override
  String get provTabWallet => 'Ví';

  @override
  String get provTabAvailability => 'Lịch rảnh';

  @override
  String get provTabMore => 'Thêm';

  @override
  String get provHomeTitle => 'Bảng điều khiển';

  @override
  String get provJobsTitle => 'Công việc';

  @override
  String get provJobsAssigned => 'Được giao';

  @override
  String get provJobsAvailable => 'Khả dụng';

  @override
  String get provWalletTitle => 'Ví của tôi';

  @override
  String get provAvailabilityTitle => 'Lịch rảnh';

  @override
  String get provMoreTitle => 'Thêm';

  @override
  String get provBonusesTitle => 'Thưởng';

  @override
  String get provGoalsTitle => 'Mục tiêu';

  @override
  String get provLeaderboardTitle => 'Bảng xếp hạng';

  @override
  String get provFinesTitle => 'Phí phạt';

  @override
  String get provAppealTitle => 'Khiếu nại';

  @override
  String get provCancellationsTitle => 'Hủy đơn';

  @override
  String get provReferralsTitle => 'Giới thiệu';

  @override
  String get provSupportTitle => 'Hỗ trợ';

  @override
  String get provVipTitle => 'VIP';

  @override
  String get provSwitchToCustomer => 'Chuyển sang khách hàng';

  @override
  String get provSignInRequired => 'Vui lòng đăng nhập để tiếp tục.';

  @override
  String get provAvailLoadError =>
      'Chưa tải được lịch làm việc. Máy chủ có thể đang bảo trì.';

  @override
  String get provAvailWeeklyHeading => 'Lịch lặp hằng tuần';

  @override
  String get provAvailWeeklySub =>
      'Khung giờ bạn nhận đơn mỗi tuần. Chạm một ngày để chỉnh.';

  @override
  String get provAvailOverridesHeading => 'Điều chỉnh theo ngày';

  @override
  String get provAvailOverridesSub =>
      'Thay lịch cho một ngày cụ thể (ngày lễ, nghỉ phép…).';

  @override
  String get provAvailAddOverride => 'Thêm điều chỉnh';

  @override
  String get provAvailFreeHoursTitle => 'Tổng giờ rảnh mỗi tuần';

  @override
  String get provAvailNoSlots => 'Không nhận đơn';

  @override
  String get provAvailUnavailableFull => 'Nghỉ cả ngày';

  @override
  String get provAvailEditDay => 'Chỉnh lịch ngày';

  @override
  String get provAvailAddSlot => 'Thêm khung giờ';

  @override
  String get provAvailStart => 'Bắt đầu';

  @override
  String get provAvailEnd => 'Kết thúc';

  @override
  String get provAvailSave => 'Lưu';

  @override
  String get provAvailCancel => 'Huỷ';

  @override
  String get provAvailSaved => 'Đã lưu lịch làm việc.';

  @override
  String get provAvailSaveFailed => 'Lưu thất bại. Vui lòng thử lại.';

  @override
  String get provAvailPickDate => 'Chọn ngày';

  @override
  String get provAvailConflictTitle => 'Trùng với đơn đã nhận';

  @override
  String get provAvailSaveAnyway => 'Vẫn lưu';

  @override
  String get provAvailEmptyOverrides => 'Chưa có điều chỉnh nào.';

  @override
  String get provAvailHoursUnit => 'giờ';

  @override
  String get provAvailSlotOrderError => 'Giờ kết thúc phải sau giờ bắt đầu.';

  @override
  String provAvailConflictBody(String ids) {
    return 'Các đơn đã nhận sẽ không còn nằm trong lịch rảnh: $ids. Vẫn lưu?';
  }

  @override
  String get provAvailWeekdayShort0 => 'CN';

  @override
  String get provAvailWeekdayShort1 => 'T2';

  @override
  String get provAvailWeekdayShort2 => 'T3';

  @override
  String get provAvailWeekdayShort3 => 'T4';

  @override
  String get provAvailWeekdayShort4 => 'T5';

  @override
  String get provAvailWeekdayShort5 => 'T6';

  @override
  String get provAvailWeekdayShort6 => 'T7';

  @override
  String get provAvailWeekdayLong0 => 'Chủ nhật';

  @override
  String get provAvailWeekdayLong1 => 'Thứ hai';

  @override
  String get provAvailWeekdayLong2 => 'Thứ ba';

  @override
  String get provAvailWeekdayLong3 => 'Thứ tư';

  @override
  String get provAvailWeekdayLong4 => 'Thứ năm';

  @override
  String get provAvailWeekdayLong5 => 'Thứ sáu';

  @override
  String get provAvailWeekdayLong6 => 'Thứ bảy';

  @override
  String provAvailHours(int h, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '$h giờ $m',
      zero: '$h giờ',
    );
    return '$_temp0';
  }

  @override
  String get provJobStatusPending => 'Chờ xác nhận';

  @override
  String get provJobStatusActive => 'Đang làm';

  @override
  String get provJobStatusClosed => 'Đã đóng';

  @override
  String get provJobNetHint => '≈ 80% về bạn';

  @override
  String get provJobsAssignedEmpty => 'Chưa có công việc nào';

  @override
  String get provPoolEmpty => 'Hiện chưa có đơn nào để nhận';

  @override
  String get provJobsLoadError => 'Không tải được công việc';

  @override
  String get provPoolAvailable => 'Đơn có thể nhận';

  @override
  String get provPoolAssigned => 'Đơn của bạn';

  @override
  String get provClaimAction => 'Nhận đơn';

  @override
  String get provClaimGateTitle => 'Bạn chưa thể nhận đơn';

  @override
  String get provClaimGateBody =>
      'Tài khoản của bạn đang bị tạm hạn chế nhận đơn.';

  @override
  String get provClaimSuccess => 'Đã nhận đơn';

  @override
  String get provClaimError => 'Không nhận được đơn, vui lòng thử lại';

  @override
  String provHomeGreeting(String name) {
    return 'Xin chào, $name';
  }

  @override
  String get provHomeGreetingPlain => 'Xin chào';

  @override
  String get provHomeSubtitle =>
      'Quản lý công việc, theo dõi thu nhập, và tận dụng giờ cao điểm.';

  @override
  String get provHomeKpi30d => 'KPI 30 ngày qua';

  @override
  String get provKpiAcceptanceLabel => 'Nhận job';

  @override
  String get provKpiCompletionLabel => 'Hoàn thành';

  @override
  String get provKpiRatingLabel => 'Đánh giá';

  @override
  String get provKpiPunctualityLabel => 'Đúng giờ';

  @override
  String get provHomeEarningsMonth => 'THU NHẬP THÁNG';

  @override
  String get provHomeBalance => 'Số dư ví';

  @override
  String get provHomeLifetime => 'Luỹ kế';

  @override
  String get provHomeStatActive => 'Đang làm';

  @override
  String get provHomeStatTotal => 'Tổng';

  @override
  String get provHomeToday => 'Hôm nay';

  @override
  String get provHomeTodayEmpty =>
      'Không có lịch hôm nay. Tận hưởng ngày nghỉ ☕.';

  @override
  String get provHomeUpcoming => 'Sắp tới';

  @override
  String get provHomeUpcomingEmpty => 'Chưa có lịch sắp tới.';

  @override
  String get provHomeSeeAll => 'Xem tất cả →';

  @override
  String get provStatusPending => 'đang chờ';

  @override
  String get provStatusActive => 'đang làm';

  @override
  String get provStatusClosed => 'đã đóng';

  @override
  String get provWalletExportTooltip => 'Xuất CSV tháng này';

  @override
  String get provWalletTxns => 'Giao dịch';

  @override
  String get provWalletWithdrawHistory => 'Lịch sử rút tiền';

  @override
  String get provWalletPayoutHint =>
      'Tiền được giữ và giải ngân theo lịch của Kyco.';

  @override
  String get provWalletAvailableBalance => 'SỐ DƯ KHẢ DỤNG';

  @override
  String get provWalletBalanceSchedule =>
      'Giải ngân sau khi khách xác nhận, chuyển về tài khoản ngân hàng đã đăng ký.';

  @override
  String get provWalletTileTotal => 'Tổng thu nhập';

  @override
  String get provWalletTileMonth => 'Tháng này';

  @override
  String get provWalletTileJobs => 'Số công việc';

  @override
  String get provWalletTileFees => 'Phí đã trừ';

  @override
  String get provWalletWithdrawTitle => 'Rút tiền về ngân hàng';

  @override
  String get provWalletWithdrawBody =>
      'Yêu cầu rút tiền cần xác minh bảo mật để bảo vệ tài khoản.';

  @override
  String provWalletWithdrawMin(String min) {
    return 'Cần tối thiểu $min để rút tiền.';
  }

  @override
  String get provWalletWithdrawAction => 'Rút tiền';

  @override
  String provWalletBalanceAfter(String amount) {
    return 'Số dư $amount';
  }

  @override
  String get provWalletReasonEarning => 'Thu nhập công việc';

  @override
  String get provWalletReasonTip => 'Tiền tip';

  @override
  String get provWalletReasonBonus => 'Thưởng';

  @override
  String get provWalletReasonPayout => 'Rút tiền';

  @override
  String get provWalletReasonCommission => 'Hoa hồng';

  @override
  String get provWalletReasonClawback => 'Thu hồi';

  @override
  String get provWalletReasonAdjustment => 'Điều chỉnh';

  @override
  String get provWalletReasonDefault => 'Giao dịch';

  @override
  String get provWalletPayoutReleased => 'Đã giải ngân';

  @override
  String get provWalletPayoutWithdrawn => 'Đã rút';

  @override
  String get provWalletPayoutReversed => 'Đã hoàn';

  @override
  String get provWalletPayoutHeld => 'Đang giữ';

  @override
  String provWalletWithdrawMinError(String min) {
    return 'Số tiền tối thiểu là $min.';
  }

  @override
  String provWalletWithdrawMaxError(String max) {
    return 'Số tiền tối đa mỗi lần là $max.';
  }

  @override
  String provWalletSheetBalance(String amount) {
    return 'Số dư khả dụng: $amount';
  }

  @override
  String get provWalletAmountLabel => 'Số tiền (₫)';

  @override
  String provWalletAmountHint(String min, String max) {
    return 'Từ $min đến $max · số nguyên đồng. Kyco kiểm tra và trừ số dư trên máy chủ.';
  }

  @override
  String get provWalletContinue => 'Tiếp tục';

  @override
  String get provWalletMaintenance => 'Tính năng rút tiền sắp ra mắt.';

  @override
  String provWalletWithdrawSubmitted(String amount, String bank, String tail) {
    return 'Đã gửi yêu cầu rút $amount về $bank ••••$tail. Kyco chuyển trong 1-2 ngày làm việc.';
  }

  @override
  String provWalletWithdrawSubmittedNoBank(String amount) {
    return 'Đã ghi nhận yêu cầu rút $amount. Kyco chuyển trong 1-2 ngày làm việc.';
  }

  @override
  String get provWalletWithdrawPending =>
      'Một yêu cầu rút tiền đang được xử lý. Vui lòng thử lại sau giây lát.';

  @override
  String get provWalletWithdrawStepUp =>
      'Cần xác minh bảo mật để rút tiền. Vui lòng thử lại.';

  @override
  String get provWalletStepUpTitle => 'Xác minh bảo mật';

  @override
  String get provWalletStepUpPassword =>
      'Nhập mật khẩu để xác nhận yêu cầu rút tiền.';

  @override
  String get provWalletStepUpPhonePrompt =>
      'Nhập số điện thoại đã đăng ký để nhận mã OTP xác nhận rút tiền.';

  @override
  String get provWalletStepUpOtpPrompt =>
      'Nhập mã OTP vừa gửi tới điện thoại để xác nhận yêu cầu rút tiền.';

  @override
  String get provWalletConfirm => 'Xác nhận';

  @override
  String get provWalletResendSending => 'Đang gửi lại…';

  @override
  String get provWalletResend => 'Gửi lại mã';

  @override
  String get provWalletExportMaintenance => 'Tính năng xuất CSV sắp ra mắt.';

  @override
  String get provOtpInvalidPhone => 'Số điện thoại không hợp lệ.';

  @override
  String get provOtpRateLimited =>
      'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau.';

  @override
  String get provOtpSendFailed => 'Không gửi được mã OTP. Vui lòng thử lại.';

  @override
  String provOtpSentTo(String phone) {
    return 'Đã gửi mã OTP tới $phone.';
  }

  @override
  String get provPhoneLabel => 'Số điện thoại';

  @override
  String get provSendOtp => 'Gửi mã OTP';

  @override
  String get provOtpLabel => 'Mã OTP';

  @override
  String get changePhoneTitle => 'Đổi số điện thoại';

  @override
  String get changePhonePrompt =>
      'Nhập số điện thoại mới. Chúng tôi sẽ gửi mã xác minh tới số đó.';

  @override
  String get changePhoneNewLabel => 'Số điện thoại mới';

  @override
  String get changePhoneCodePrompt =>
      'Nhập mã 6 số vừa gửi tới số điện thoại mới.';

  @override
  String get changePhoneSubmit => 'Xác nhận đổi số';

  @override
  String get changePhoneSuccess => 'Đã cập nhật số điện thoại.';

  @override
  String get changePhoneConflict => 'Số điện thoại này đã được sử dụng.';

  @override
  String get changePhoneInvalidCode => 'Mã xác minh không đúng.';

  @override
  String get changePhoneCodeRequired => 'Vui lòng nhập mã xác minh gồm 6 số.';

  @override
  String get provJdNotFound => 'Không tìm thấy công việc';

  @override
  String get provJdTitle => 'Chi tiết công việc';

  @override
  String get provJdFeatureEnabling =>
      'Tính năng đang được bật, vui lòng thử lại sau ít phút.';

  @override
  String get provJdGpsOff => 'Vui lòng bật Dịch vụ vị trí (GPS) để check-in.';

  @override
  String get provJdGpsPermNeeded =>
      'Ứng dụng cần quyền vị trí để check-in tại địa điểm khách.';

  @override
  String get provJdGpsPermOff =>
      'Quyền vị trí đã bị tắt. Hãy cấp lại trong Cài đặt.';

  @override
  String get provJdGpsFailed => 'Không lấy được vị trí, vui lòng thử lại.';

  @override
  String get provJdCamPermNeeded =>
      'Ứng dụng cần quyền camera để chụp ảnh công việc.';

  @override
  String get provJdPhotoUploadFailed =>
      'Không tải được ảnh lên, vui lòng thử lại.';

  @override
  String get provJdDeclineTitle => 'Từ chối công việc';

  @override
  String get provJdDeclineWarning =>
      'Từ chối sau khi đã nhận có thể bị tính phí phạt và ảnh hưởng điểm uy tín. Kyco sẽ hiển thị mức phí (nếu có) sau khi xác nhận.';

  @override
  String get provJdReasonOptional => 'Lý do (không bắt buộc)';

  @override
  String get provJdDecline => 'Từ chối';

  @override
  String get provJdDeclined => 'Đã từ chối công việc';

  @override
  String get provJdCancelTitle => 'Huỷ công việc';

  @override
  String get provJdCancelWarning =>
      'Huỷ đơn đã nhận có thể phát sinh phí phạt theo chính sách. Mức phí do Kyco tính và hiển thị sau khi xác nhận.';

  @override
  String get provJdCancelReason => 'Lý do huỷ';

  @override
  String get provJdCancelJob => 'Huỷ đơn';

  @override
  String get provJdCancelled => 'Đã huỷ công việc';

  @override
  String get provJdEnRouteSnack => 'Đã bắt đầu di chuyển đến khách';

  @override
  String get provJdCheckedOutSnack =>
      'Đã check-out. Đơn được chuyển sang chờ khách xác nhận & thanh toán.';

  @override
  String get provJdPhotoUploaded => 'Đã tải ảnh lên';

  @override
  String get provJdFaceSubmitted => 'Đã gửi xác minh khuôn mặt';

  @override
  String get provJdMarkedComplete => 'Đã báo hoàn thành công việc';

  @override
  String get provJdCashConfirmTitle => 'Xác nhận đã nhận tiền mặt';

  @override
  String get provJdCashConfirmBody =>
      'Kyco sẽ thu hoa hồng 20% cho đơn tiền mặt này. Xác nhận bạn đã nhận đủ tiền từ khách?';

  @override
  String get provJdCashReceived => 'Đã nhận tiền';

  @override
  String get provJdComplaintTitle => 'Gửi khiếu nại';

  @override
  String get provJdComplaintBody =>
      'Mô tả sự cố với đơn này. Đội hỗ trợ Kyco sẽ xem xét.';

  @override
  String get provJdComplaintHint => 'Nội dung khiếu nại';

  @override
  String get provJdSend => 'Gửi';

  @override
  String get provJdComplaintSent => 'Đã gửi khiếu nại';

  @override
  String get provJdSosBody =>
      'Gửi cảnh báo khẩn cấp tới Kyco cho công việc này? Đội an toàn sẽ liên hệ ngay.';

  @override
  String get provJdSosConfirm => 'Gửi SOS';

  @override
  String get provJdSosSent => 'Đã gửi SOS. Đội an toàn Kyco sẽ liên hệ ngay.';

  @override
  String get provJdCheckedIn => 'Đã check-in';

  @override
  String get provJdWithinGeofence => 'trong phạm vi địa điểm';

  @override
  String provJdMetersAway(Object m) {
    return 'cách ~${m}m';
  }

  @override
  String provJdMinLate(Object n) {
    return 'trễ $n phút';
  }

  @override
  String get provJdLateFineTitle => 'Phí trễ giờ';

  @override
  String provJdLateFineBody(String amount) {
    return 'Kyco ghi nhận phí trễ giờ: $amount. Số tiền do hệ thống tính.';
  }

  @override
  String get provJdFineTitle => 'Phí phạt';

  @override
  String provJdFineBody(String amount) {
    return 'Kyco áp dụng phí phạt: $amount. Số tiền do hệ thống tính, không thể thay đổi.';
  }

  @override
  String get provJdCashRecorded => 'Đã ghi nhận tiền mặt';

  @override
  String get provJdCashRecordedBody =>
      'Kyco đã tính hoa hồng 20% cho đơn này. Số liệu dưới đây do hệ thống tính:';

  @override
  String get provJdSeeWallet => 'Xem ví để biết chi tiết.';

  @override
  String get provJdClose => 'Đóng';

  @override
  String get provJdDialogCancel => 'Đóng';

  @override
  String provJdNeedMore(Object missing) {
    return 'còn thiếu $missing';
  }

  @override
  String get provJdCompleteTitle => 'Hoàn thành công việc';

  @override
  String get provJdCompleteGateBody =>
      'Cần đủ ảnh trước/giữa/sau ca mới được báo hoàn thành:';

  @override
  String get provJdBefore => 'Trước ca';

  @override
  String get provJdMid => 'Giữa ca';

  @override
  String get provJdAfter => 'Sau ca';

  @override
  String get provJdMarkComplete => 'Báo hoàn thành';

  @override
  String get provJdReportProblem => 'Gửi khiếu nại về đơn này';

  @override
  String get provJdPhasePending => 'Chờ bạn xác nhận';

  @override
  String get provJdPhaseEnRoute => 'Chuẩn bị di chuyển';

  @override
  String get provJdPhaseOnSite => 'Đang làm việc tại địa điểm';

  @override
  String get provJdPhaseWrapUp => 'Hoàn tất & báo xong';

  @override
  String get provJdPhaseAwaitingCustomer =>
      'Chờ khách xác nhận (tự động sau 2h)';

  @override
  String get provJdPhaseAwaitingCash => 'Chờ xác nhận tiền mặt';

  @override
  String get provJdPhaseAwaitingPayment => 'Khách đang thanh toán';

  @override
  String get provJdPhaseSettled => 'Đã tất toán';

  @override
  String get provJdPhaseClosed => 'Đã đóng';

  @override
  String get provJdPhaseCancelled => 'Đã huỷ';

  @override
  String get provJdPhaseUnknown => 'Trạng thái công việc';

  @override
  String get provJdOrderInfo => 'Thông tin đơn';

  @override
  String get provJdCustomer => 'Khách hàng';

  @override
  String get provJdTime => 'Thời gian';

  @override
  String get provJdDuration => 'Thời lượng';

  @override
  String get provJdAddress => 'Địa chỉ';

  @override
  String get provJdPayment => 'Thanh toán';

  @override
  String get provJdYourEarnings => 'Thu nhập của bạn';

  @override
  String get provJdAmountsComputed =>
      'Số tiền do Kyco tính và hiển thị — ứng dụng không tự tính.';

  @override
  String get provJdPayCash => 'Tiền mặt';

  @override
  String get provJdPayBankTransfer => 'Chuyển khoản';

  @override
  String get provJdConfirmAccept => 'Xác nhận & nhận việc';

  @override
  String get provJdStartTracking => 'Bắt đầu di chuyển (dùng GPS)';

  @override
  String get provJdCheckIn => 'Check-in tại địa điểm (GPS)';

  @override
  String provJdBeforePhotoGate(Object need, Object have) {
    return 'Cần ≥ $need ảnh \"trước ca\" mới được check-out (hiện $have/$need). Chụp ở khung ảnh bên dưới.';
  }

  @override
  String get provJdFaceVerify => 'Xác minh khuôn mặt';

  @override
  String get provJdCheckOut => 'Check-out (GPS)';

  @override
  String get provJdCashReceivedAction => '✅ Đã nhận tiền mặt từ khách';

  @override
  String get provJdCashCommissionNote =>
      'Kyco sẽ thu hoa hồng 20% cho đơn tiền mặt này (số tiền do hệ thống tính).';

  @override
  String get provJdAwaitingCustomerInfo =>
      '⏳ Chờ khách xác nhận hoàn thành (tự động sau 2h).';

  @override
  String get provJdAwaitingPaymentInfo =>
      '⏳ Khách đang thanh toán — Kyco sẽ chuyển 80% khi xác nhận.';

  @override
  String get provJdClosedInfo =>
      '🔒 Công việc đã đóng. Không còn hành động nào.';

  @override
  String get provJdCancelledInfo => 'Công việc đã huỷ.';

  @override
  String get provJdNoActions => 'Không có hành động khả dụng.';

  @override
  String get provJdLifecycle => 'Vòng đời công việc';

  @override
  String provJdPhotosRequired(Object total, Object req) {
    return 'Ảnh cần để hoàn thành ($total/$req)';
  }

  @override
  String get provJdSettledThanks =>
      '✅ Kyco đã thanh toán cho bạn 80% giá trị đơn hàng, cảm ơn bạn đã đồng hành!';

  @override
  String get provJdJobPhotos => 'Ảnh công việc (camera)';

  @override
  String get provJdCapture => 'Chụp';

  @override
  String get provJdSafety => 'An toàn';

  @override
  String get provJdSendSos => 'Gửi SOS khẩn cấp';

  @override
  String get provJdShareLocation => '📍 Chia sẻ vị trí với khách';

  @override
  String get provJdShareLiveTitle => 'Chia sẻ vị trí trực tiếp — sắp ra mắt';

  @override
  String get provJdShareLiveBody =>
      'Tính năng đang được phát triển. Khách chưa thể xem vị trí của bạn.';

  @override
  String get provJdChatTitle => 'Trò chuyện với khách';

  @override
  String get provJdChatEmpty => 'Chưa có tin nhắn nào.';

  @override
  String get provJdChatHint => 'Nhập tin nhắn…';

  @override
  String get provJdCommission20 => 'Hoa hồng (20%)';

  @override
  String get provJdWalletBalance => 'Số dư ví';

  @override
  String get provJdOrderTotal => 'Tổng đơn';

  @override
  String get provJdFine => 'Phí phạt';

  @override
  String get provBonusesWeekTitle => 'Thưởng tuần này';

  @override
  String get provBonusesMonthTitle => 'Thưởng tháng này';

  @override
  String get provBonusesHistoryTitle => 'Lịch sử thưởng';

  @override
  String get provBonusesHistoryEmpty => 'Chưa có khoản thưởng nào được chi.';

  @override
  String get provBonusesNone => 'Không có thưởng khả dụng.';

  @override
  String get provBonusEarned => 'Đã đạt';

  @override
  String get provBonusMax => 'Tối đa';

  @override
  String get provBonusNotEarned => 'Chưa đạt';

  @override
  String get provBonusKindWeeklyJobs => '🏆 Thưởng tuần (số đơn)';

  @override
  String get provBonusKindMonthlyRevenue => '🏅 Thưởng tháng (doanh thu)';

  @override
  String get provBonusKindPunctuality => '📅 Thưởng chuyên cần';

  @override
  String get provBonusKindRating => '⭐ Thưởng rating cao';

  @override
  String get provBonusKindReferral => '👥 Thưởng giới thiệu';

  @override
  String get provGoalsThisWeek => 'Tuần này';

  @override
  String get provGoalsThisMonth => 'Tháng này';

  @override
  String get provGoalJobs => 'Số đơn';

  @override
  String get provGoalIncome => 'Thu nhập';

  @override
  String get provGoalSet => 'Đặt mục tiêu';

  @override
  String get provGoalEdit => 'Sửa mục tiêu';

  @override
  String get provGoalSaved => 'Đã lưu mục tiêu';

  @override
  String get provGoalTitle => 'Mục tiêu';

  @override
  String get provGoalTargetJobs => 'Mục tiêu số đơn';

  @override
  String get provGoalTargetIncome => 'Mục tiêu thu nhập (₫)';

  @override
  String get provGoalSave => 'Lưu';

  @override
  String get provGoalCancel => 'Huỷ';

  @override
  String provLbYourRank(Object n) {
    return 'Hạng của bạn: #$n';
  }

  @override
  String get provLbEmpty => 'Chưa có dữ liệu xếp hạng.';

  @override
  String get provLbWeek => 'Tuần';

  @override
  String get provLbMonth => 'Tháng';

  @override
  String get provLbNationwide => 'Toàn quốc';

  @override
  String get provLbYou => 'Bạn';

  @override
  String provLbJobs(Object n) {
    return '$n đơn';
  }

  @override
  String get provVipPerkPriorityTitle => 'Ưu tiên nhận đơn';

  @override
  String get provVipPerkPriorityBody =>
      'Được ưu tiên phân bổ các đơn giá trị cao trước các CTV khác.';

  @override
  String get provVipPerkAreaTitle => 'Mở rộng khu vực';

  @override
  String get provVipPerkAreaBody =>
      'Nhận đơn ở nhiều quận/khu vực hơn để tối đa thu nhập.';

  @override
  String get provVipPerkSupportTitle => 'Hỗ trợ VIP riêng';

  @override
  String get provVipPerkSupportBody =>
      'Đường dây hỗ trợ riêng 1900-VIP-XX, phản hồi nhanh 24/7.';

  @override
  String get provVipPerkBadgeTitle => 'Huy hiệu VIP';

  @override
  String get provVipPerkBadgeBody =>
      'Hiển thị huy hiệu Bạch kim với khách hàng để tăng độ tin cậy.';

  @override
  String get provVipPerkGiftTitle => 'Quà & ưu đãi';

  @override
  String get provVipPerkGiftBody =>
      'Nhận quà tri ân và các ưu đãi độc quyền dành cho CTV VIP.';

  @override
  String get provVipPerkBonusTitle => 'Thưởng cao hơn';

  @override
  String get provVipPerkBonusBody =>
      'Hệ số thưởng cao hơn cho cùng một mức thành tích.';

  @override
  String get provVipWelcome => 'Chào mừng CTV VIP 💎';

  @override
  String get provVipPerksTitle => 'Đặc quyền VIP';

  @override
  String get provVipPerksSubtitle =>
      'Những quyền lợi dành cho CTV hạng Bạch kim.';

  @override
  String get provVipReqJobs => 'Hoàn thành ≥ 800 đơn';

  @override
  String get provVipReqRating => 'Điểm đánh giá ≥ 4.85';

  @override
  String get provVipReqCompletion => 'Duy trì tỉ lệ hoàn thành cao';

  @override
  String get provVipReqComplaints => 'Không có khiếu nại nghiêm trọng';

  @override
  String get provVipUnlockTitle => 'Mở khoá đặc quyền VIP';

  @override
  String provVipUpsellBody(String tier) {
    return 'Đạt hạng Bạch kim để nhận toàn bộ quyền lợi VIP. Hạng hiện tại: $tier.';
  }

  @override
  String get provVipReqTitle => 'Điều kiện lên hạng';

  @override
  String get provVipBackDashboard => 'Về trang chủ CTV';

  @override
  String get provVipTierPlatinum => 'Bạch kim';

  @override
  String get provVipTierGold => 'Vàng';

  @override
  String get provVipTierSilver => 'Bạc';

  @override
  String get provVipTierBronze => 'Đồng';

  @override
  String get provFinesPending => 'Đang chờ';

  @override
  String get provFinesDeducted => 'Đã trừ';

  @override
  String get provFinesRefunded => 'Hoàn lại';

  @override
  String get provFinesHistory => 'Lịch sử phạt';

  @override
  String get provFineAppealAction => 'Khiếu nại';

  @override
  String get provAppealNotFound => 'Không tìm thấy khoản phạt';

  @override
  String get provAppealYours => 'Khiếu nại của bạn';

  @override
  String get provAppealStatusLabel => 'Trạng thái: ';

  @override
  String get provAppealSent => 'Đã gửi khiếu nại';

  @override
  String get provAppealAlready => 'Khoản phạt này đã được khiếu nại.';

  @override
  String provAppealMinChars(Object n) {
    return 'Nội dung khiếu nại phải có ít nhất $n ký tự.';
  }

  @override
  String get provAppealReasonLabel => 'Lý do khiếu nại';

  @override
  String get provAppealPlaceholder =>
      'Mô tả vì sao bạn cho rằng khoản phạt này chưa hợp lý…';

  @override
  String provAppealCounter(Object n, Object max) {
    return '$n/$max ký tự';
  }

  @override
  String get provAppealSubmit => 'Gửi khiếu nại';

  @override
  String get provAppealReviewNote =>
      'Đội ngũ Kyco sẽ xem xét khiếu nại của bạn trong thời gian sớm nhất.';

  @override
  String get provCancels30d => 'Huỷ trong 30 ngày';

  @override
  String get provCancelsPenaltyPoints => 'Điểm phạt';

  @override
  String get provCancelsSuspend30Title => 'Sắp bị tạm khoá 30 ngày';

  @override
  String provCancelsSuspend30Body(Object count, Object limit) {
    return 'Bạn đã huỷ $count lần trong 30 ngày. Đạt $limit lần sẽ bị tạm khoá 30 ngày.';
  }

  @override
  String get provCancelsSuspend7Title => 'Sắp bị tạm khoá 7 ngày';

  @override
  String provCancelsSuspend7Body(Object count, Object limit) {
    return 'Bạn đã huỷ $count lần trong 30 ngày. Đạt $limit lần sẽ bị tạm khoá 7 ngày.';
  }

  @override
  String get provCancelsHistory => 'Lịch sử huỷ';

  @override
  String get provOrderNoNumber => 'Đơn #—';

  @override
  String provCancelsPoints(Object n) {
    return '+$n điểm';
  }

  @override
  String get provReferralsNoCode => 'Chưa có mã giới thiệu';

  @override
  String get provReferralsActive => 'Đang hoạt động';

  @override
  String get provReferralsCompleted => 'Hoàn thành';

  @override
  String get provReferralsEarned => 'Đã nhận (≈)';

  @override
  String get provReferralsApproxNote =>
      '* Số tiền đã nhận chỉ mang tính ước tính.';

  @override
  String get provReferralsList => 'Danh sách giới thiệu';

  @override
  String get provReferralsShareSubject => 'Tham gia Kyco với mã của tôi';

  @override
  String get provReferralsYourCode => 'MÃ GIỚI THIỆU CỦA BẠN';

  @override
  String get provReferralsShare => 'Chia sẻ';

  @override
  String get provReferralsColPartner => 'Đối tác';

  @override
  String get provReferralsColArea => 'Khu vực';

  @override
  String get provReferralsColTarget => 'Chỉ tiêu';

  @override
  String get provSupportSubtitle =>
      'Hỗ trợ 24/7 — nhắn Zalo, email, hoặc gửi yêu cầu bên dưới.';

  @override
  String get provSupportZaloHint => 'Phản hồi trong vài phút';

  @override
  String get provSupportEmailHint => 'Phản hồi trong 24 giờ';

  @override
  String get provSupportCatWallet => 'Ví & thanh toán';

  @override
  String get provSupportCatTech => 'Kỹ thuật / ứng dụng';

  @override
  String get provSupportCatTechShort => 'Kỹ thuật';

  @override
  String get provSupportCatPolicy => 'Chính sách';

  @override
  String get provSupportCatOther => 'Khác';

  @override
  String get provSupportPrioNormal => 'Bình thường';

  @override
  String get provSupportPrioHigh => 'Cao';

  @override
  String get provSupportPrioUrgent => 'Khẩn cấp';

  @override
  String get provSupportFormTitle => 'Gửi yêu cầu hỗ trợ';

  @override
  String get provSupportCategoryField => 'Nhóm';

  @override
  String get provSupportPriorityField => 'Ưu tiên';

  @override
  String get provSupportSubjectLabel => 'Tiêu đề';

  @override
  String get provSupportSubjectHint => 'Tóm tắt ngắn gọn vấn đề';

  @override
  String get provSupportSubjectMin => 'Tối thiểu 5 ký tự';

  @override
  String get provSupportBodyLabel => 'Nội dung';

  @override
  String get provSupportBodyHint => 'Mô tả chi tiết (tuỳ chọn)';

  @override
  String get provSupportSubmit => 'Gửi yêu cầu';

  @override
  String get provSupportSent => 'Đã gửi yêu cầu hỗ trợ.';

  @override
  String get provSupportSendError =>
      'Không gửi được yêu cầu. Vui lòng thử lại.';

  @override
  String get provSupportMyTickets => 'Yêu cầu của tôi';

  @override
  String get provSupportNoTickets => 'Chưa có yêu cầu hỗ trợ nào.';

  @override
  String provSupportTicketNumber(Object id) {
    return 'Yêu cầu #$id';
  }

  @override
  String get provSupportStatusOpen => 'Đang mở';

  @override
  String get provSupportStatusInProgress => 'Đang xử lý';

  @override
  String get provSupportStatusResolved => 'Đã xử lý';

  @override
  String get provTaskerCityHcm => 'TP. Hồ Chí Minh';

  @override
  String get provTaskerCityHn => 'Hà Nội (sắp khai trương)';

  @override
  String get provTaskerCityDn => 'Đà Nẵng (sắp khai trương)';

  @override
  String get provTaskerKycFront => 'CCCD mặt trước';

  @override
  String get provTaskerKycBack => 'CCCD mặt sau';

  @override
  String get provTaskerKycSelfie => 'Ảnh chân dung';

  @override
  String get provTaskerOtpFormat => 'Mã OTP gồm 6–8 chữ số.';

  @override
  String get provTaskerCameraDenied =>
      'Không mở được camera. Vui lòng cấp quyền camera trong Cài đặt.';

  @override
  String get provTaskerNameDistrictRequired =>
      'Vui lòng nhập họ tên và quận/huyện.';

  @override
  String get provTaskerNeed3Photos => 'Vui lòng chụp đủ 3 ảnh giấy tờ.';

  @override
  String get provTaskerPhotoReadFailed =>
      'Không đọc được ảnh. Vui lòng chụp lại.';

  @override
  String get provTaskerVerifyPhoneTitle => 'Xác minh số điện thoại';

  @override
  String get provTaskerSending => 'Đang gửi…';

  @override
  String get provTaskerEnterOtpTitle => 'Nhập mã OTP';

  @override
  String provTaskerOtpSentTo(String phone) {
    return 'Mã đã gửi tới $phone';
  }

  @override
  String get provTaskerChangePhone => 'Đổi số điện thoại';

  @override
  String get provTaskerContinue => 'Tiếp tục';

  @override
  String get provTaskerProfileTitle => 'Thông tin & giấy tờ';

  @override
  String get provTaskerFullName => 'Họ và tên';

  @override
  String get provTaskerCity => 'Thành phố';

  @override
  String get provTaskerDistrict => 'Quận / Huyện';

  @override
  String get provTaskerDistrictHint => 'VD: Quận 1';

  @override
  String get provTaskerReferral => 'Mã giới thiệu (tuỳ chọn)';

  @override
  String get provTaskerCaptureDocsTitle => 'Chụp ảnh giấy tờ';

  @override
  String get provTaskerSubmit => 'Gửi hồ sơ';

  @override
  String get provTaskerStepPhone => 'Xác minh SĐT';

  @override
  String get provTaskerStepProfile => 'Hồ sơ & KYC';

  @override
  String get provTaskerStepReview => 'Duyệt hồ sơ';

  @override
  String get provTaskerDoneTitle => 'Đã gửi hồ sơ';

  @override
  String get provTaskerDoneBody =>
      'Kyco đã nhận giấy tờ của bạn và sẽ liên hệ để hoàn tất đăng ký.';

  @override
  String get provTaskerBackHome => 'Về trang chủ';

  @override
  String get provTaskerNotLiveTitle => 'Sắp ra mắt trên ứng dụng';

  @override
  String get provTaskerNotLiveBody =>
      'Đăng ký cộng tác viên chưa mở trên ứng dụng, nên hồ sơ chưa được gửi đi. Vui lòng hoàn tất đăng ký tại kyco.vn hoặc email tasker@kyco.vn.';

  @override
  String get provTaskerRetake => 'Chụp lại';

  @override
  String get provTaskerCapturePhoto => 'Chụp ảnh';

  @override
  String get cust2ErrNetwork =>
      'Không có kết nối mạng. Vui lòng kiểm tra kết nối và thử lại.';

  @override
  String get cust2ErrRateLimit =>
      'Bạn thao tác quá nhanh. Vui lòng đợi một chút rồi thử lại.';

  @override
  String get cust2ErrMaintenance =>
      'Hệ thống đang bảo trì. Vui lòng thử lại sau.';

  @override
  String get cust2ErrSessionExpired =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get cust2ErrForbidden => 'Bạn không có quyền thực hiện thao tác này.';

  @override
  String get cust2ErrNotFound => 'Không tìm thấy nội dung bạn yêu cầu.';

  @override
  String get cust2ErrValidation =>
      'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.';

  @override
  String get cust2ErrServer => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get cust2ErrConflict =>
      'Không thể thực hiện thao tác ở trạng thái hiện tại.';

  @override
  String get cust2ErrTotpRequired =>
      'Tài khoản bật xác thực 2 lớp. Vui lòng nhập mã từ ứng dụng Authenticator.';

  @override
  String get cust2ErrTotpInvalid =>
      'Mã xác thực 2 lớp không đúng hoặc đã hết hạn.';

  @override
  String get cust2ErrLoginInvalid => 'Email hoặc mật khẩu không đúng.';

  @override
  String get cust2ErrOtpLoginInvalid =>
      'Mã OTP không đúng/đã hết hạn, hoặc số điện thoại chưa được xác minh.';

  @override
  String cust2BookingsLoadFailed(String reason) {
    return 'Không tải được đơn.\n$reason';
  }

  @override
  String get cust2LoginModeEmail => 'Email';

  @override
  String get cust2LoginModePhone => 'Số điện thoại';

  @override
  String get cust2PhoneLabel => 'Số điện thoại';

  @override
  String get cust2PhoneInvalid => 'Số điện thoại không hợp lệ.';

  @override
  String get cust2SendCode => 'Gửi mã OTP';

  @override
  String get cust2ResendCode => 'Gửi lại mã';

  @override
  String get cust2OtpLabel => 'Mã OTP';

  @override
  String get cust2OtpFormat => 'Mã OTP gồm 4–8 chữ số.';

  @override
  String cust2OtpSent(String phone) {
    return 'Đã gửi mã tới $phone.';
  }

  @override
  String get cust2TotpLabel => 'Mã xác thực 2 lớp';

  @override
  String get cust2StatusEnRoute => 'Đang di chuyển';

  @override
  String get cust2StatusArrived => 'Đã đến nơi';

  @override
  String get cust2StatusCheckedIn => 'Đã check-in';

  @override
  String get cust2StatusActive => 'Đang thực hiện';

  @override
  String get cust2StatusAwaitingConfirmation => 'Chờ bạn xác nhận';

  @override
  String get cust2StatusAwaitingPayment => 'Chờ thanh toán';

  @override
  String get cust2StatusAwaitingCashConfirm => 'Chờ xác nhận tiền mặt';

  @override
  String get cust2StatusClosed => 'Đã đóng';

  @override
  String get cust2StatusInDispute => 'Đang khiếu nại';

  @override
  String get cust2DetailScheduled => 'Lịch hẹn';

  @override
  String get cust2DetailAddress => 'Địa chỉ';

  @override
  String get cust2DetailNotes => 'Ghi chú';

  @override
  String get cust2DetailPayment => 'Thanh toán';

  @override
  String get cust2DetailCode => 'Mã xác nhận';

  @override
  String get cust2DetailProvider => 'Cộng tác viên';

  @override
  String get cust2DetailTimeline => 'Tiến trình';

  @override
  String get cust2PayCash => 'Tiền mặt';

  @override
  String get cust2TlCreated => 'Đặt đơn';

  @override
  String get cust2TlScheduled => 'Lịch hẹn';

  @override
  String get cust2TlClaimed => 'CTV nhận việc';

  @override
  String get cust2TlStarted => 'Bắt đầu làm';

  @override
  String get cust2TlFinished => 'CTV báo hoàn tất';

  @override
  String get cust2TlCompleted => 'Hoàn thành';

  @override
  String get cust2TlCustomerConfirmed => 'Bạn đã xác nhận';

  @override
  String get cust2TlCashReceived => 'Đã nhận tiền mặt';

  @override
  String get cust2TlSettled => 'Đã quyết toán';

  @override
  String get cust2ReviewCta => 'Đánh giá dịch vụ';

  @override
  String get cust2ReviewComment => 'Nhận xét (không bắt buộc)';

  @override
  String get cust2ReviewSubmit => 'Gửi đánh giá';

  @override
  String get cust2ReviewThanks => 'Cảm ơn bạn đã đánh giá!';

  @override
  String get cust2ReviewDone => 'Bạn đã đánh giá đơn này.';

  @override
  String get cust2RatingRequired => 'Vui lòng chọn số sao.';

  @override
  String cust2RatingStar(String n) {
    return '$n sao';
  }

  @override
  String get cust2InviteYourCode => 'Mã mời của bạn';

  @override
  String get cust2InviteBody => 'Chia sẻ mã này để bạn bè đăng ký Kyco.';

  @override
  String get cust2InviteCopy => 'Sao chép';

  @override
  String get cust2InviteCopied => 'Đã sao chép mã mời';

  @override
  String get cust2InvitePending => 'Đang chờ';

  @override
  String get cust2InviteSignedUp => 'Đã đăng ký';

  @override
  String get cust2HelpEmpty => 'Chưa có câu hỏi thường gặp.';

  @override
  String get cust2DocUnavailable => 'Nội dung này chưa có trên ứng dụng.';

  @override
  String get cust2Addresses => 'Địa chỉ đã lưu';

  @override
  String get cust2AddressAdd => 'Thêm địa chỉ';

  @override
  String get cust2AddressEdit => 'Sửa địa chỉ';

  @override
  String get cust2AddressLabel => 'Tên gợi nhớ (VD: Nhà, Công ty)';

  @override
  String get cust2AddressLine => 'Số nhà, tên đường';

  @override
  String get cust2AddressWard => 'Phường / Xã';

  @override
  String get cust2AddressDistrict => 'Quận / Huyện';

  @override
  String get cust2AddressCity => 'Tỉnh / Thành phố';

  @override
  String get cust2AddressDefault => 'Đặt làm địa chỉ mặc định';

  @override
  String get cust2AddressDefaultBadge => 'Mặc định';

  @override
  String get cust2AddressDelete => 'Xoá';

  @override
  String get cust2AddressDeleteConfirm => 'Xoá địa chỉ này?';

  @override
  String get cust2AddressEmpty => 'Bạn chưa lưu địa chỉ nào.';

  @override
  String get cust2Save => 'Lưu';

  @override
  String get cust2Cancel => 'Huỷ';

  @override
  String get cust2Required => 'Bắt buộc';

  @override
  String get cust2Saved => 'Đã lưu';

  @override
  String cust2LoadFailed(String reason) {
    return 'Không tải được dữ liệu.\n$reason';
  }

  @override
  String prov2StepUpOtpTo(String phone) {
    return 'Mã OTP sẽ được gửi tới số điện thoại đã xác minh của tài khoản: $phone';
  }

  @override
  String get prov2StepUpNoVerifiedPhone =>
      'Tài khoản chưa có số điện thoại đã xác minh. Vui lòng xác minh số điện thoại trong mục Tài khoản rồi thử lại.';

  @override
  String get prov2StepUpPhoneLoadFailed =>
      'Không tải được thông tin tài khoản, vui lòng thử lại.';

  @override
  String get prov2TaskerNationalId => 'Số CCCD (không bắt buộc)';

  @override
  String prov2TaskerPartialUpload(String kinds) {
    return 'Chưa tải lên được: $kinds. Vui lòng chụp lại và gửi lại.';
  }

  @override
  String get prov2TaskerSubmitFailed =>
      'Không gửi được hồ sơ, vui lòng thử lại.';

  @override
  String get prov2TaskerOtpInvalid =>
      'Mã OTP không đúng hoặc đã hết hạn. Vui lòng kiểm tra lại.';

  @override
  String get prov2LiveShareTitle => 'Chia sẻ vị trí trực tiếp';

  @override
  String get prov2LiveShareOff =>
      'Bật để khách thấy vị trí của bạn trên đường tới. Chỉ gửi khi màn hình này đang mở.';

  @override
  String prov2LiveShareOn(String time) {
    return 'Đang chia sẻ vị trí · cập nhật lúc $time';
  }

  @override
  String get prov2LiveShareStarting => 'Đang lấy vị trí…';

  @override
  String get prov2LiveShareNotEnRoute =>
      'Chỉ chia sẻ được khi đang di chuyển tới nhà khách (trước khi check-in).';

  @override
  String get prov2LiveShareStopped => 'Đã dừng chia sẻ vị trí.';

  @override
  String get prov2ResubmitTitle => 'Khách chưa đồng ý hoàn thành';

  @override
  String get prov2ResubmitBody =>
      'Khách đã phản hồi về công việc. Kiểm tra lại (bổ sung ảnh nếu cần) rồi gửi lại xác nhận hoàn thành.';

  @override
  String prov2ResubmitNote(String note) {
    return 'Phản hồi của khách: $note';
  }

  @override
  String get prov2ResubmitAction => 'Gửi lại xác nhận hoàn thành';

  @override
  String get prov2ResubmitDone => 'Đã gửi lại — khách sẽ được nhắc xác nhận.';

  @override
  String get prov2ComplaintNeedsText => 'Vui lòng nhập nội dung khiếu nại.';
}
