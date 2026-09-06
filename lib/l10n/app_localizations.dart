import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'Kyco'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get signup;

  /// No description provided for @logout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get emailInvalid;

  /// No description provided for @password.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get password;

  /// No description provided for @passwordMin8.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu 8 ký tự'**
  String get passwordMin8;

  /// No description provided for @showPassword.
  ///
  /// In vi, this message translates to:
  /// **'Hiện mật khẩu'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn mật khẩu'**
  String get hidePassword;

  /// No description provided for @fullName.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên'**
  String get fullName;

  /// No description provided for @createAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get createAccount;

  /// No description provided for @noAccountSignup.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký'**
  String get noAccountSignup;

  /// No description provided for @haveAccountLogin.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? Đăng nhập'**
  String get haveAccountLogin;

  /// No description provided for @browseWithoutLogin.
  ///
  /// In vi, this message translates to:
  /// **'Xem dịch vụ (không cần đăng nhập)'**
  String get browseWithoutLogin;

  /// No description provided for @genericError.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra. Vui lòng thử lại.'**
  String get genericError;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @helloGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào, {name} 👋'**
  String helloGreeting(String name);

  /// No description provided for @homeTagline.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ vệ sinh nhà cửa'**
  String get homeTagline;

  /// No description provided for @noServicesYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dịch vụ nào — sắp ra mắt.'**
  String get noServicesYet;

  /// No description provided for @homeLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được trang chủ.\n{error}'**
  String homeLoadError(String error);

  /// No description provided for @myBookings.
  ///
  /// In vi, this message translates to:
  /// **'Đơn của tôi'**
  String get myBookings;

  /// No description provided for @bookingsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được đơn.\n{error}'**
  String bookingsLoadError(String error);

  /// No description provided for @noBookingsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đơn nào.'**
  String get noBookingsYet;

  /// No description provided for @bookingNumber.
  ///
  /// In vi, this message translates to:
  /// **'Đơn #{id}'**
  String bookingNumber(Object id);

  /// No description provided for @bookingDetailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết đơn'**
  String get bookingDetailTitle;

  /// No description provided for @selectBookingPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Chọn một đơn để xem chi tiết'**
  String get selectBookingPlaceholder;

  /// No description provided for @bookingNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy đơn #{id}'**
  String bookingNotFound(Object id);

  /// No description provided for @statusLabel.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get statusLabel;

  /// No description provided for @totalLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tiền'**
  String get totalLabel;

  /// No description provided for @createdLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày tạo'**
  String get createdLabel;

  /// No description provided for @serviceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get serviceLabel;

  /// No description provided for @statusPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ xác nhận'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác nhận'**
  String get statusConfirmed;

  /// No description provided for @statusCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get statusCompleted;

  /// No description provided for @statusSettled.
  ///
  /// In vi, this message translates to:
  /// **'Đã thanh toán'**
  String get statusSettled;

  /// No description provided for @statusCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get statusCancelled;

  /// No description provided for @statusBadDebt.
  ///
  /// In vi, this message translates to:
  /// **'Nợ xấu'**
  String get statusBadDebt;

  /// No description provided for @navHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get navHome;

  /// No description provided for @navBookings.
  ///
  /// In vi, this message translates to:
  /// **'Đơn của tôi'**
  String get navBookings;

  /// No description provided for @navAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get navAccount;

  /// No description provided for @accountTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get accountTitle;

  /// No description provided for @myAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản của tôi'**
  String get myAccount;

  /// No description provided for @appearance.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In vi, this message translates to:
  /// **'Theo hệ thống'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @langSystem.
  ///
  /// In vi, this message translates to:
  /// **'Theo hệ thống'**
  String get langSystem;

  /// No description provided for @langVi.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get langVi;

  /// No description provided for @langEn.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @signInPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để xem đơn và tài khoản của bạn'**
  String get signInPrompt;

  /// No description provided for @pageNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy trang: {uri}'**
  String pageNotFound(Object uri);

  /// No description provided for @navServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get navServices;

  /// No description provided for @navMessages.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get navMessages;

  /// No description provided for @bookNow.
  ///
  /// In vi, this message translates to:
  /// **'Đặt ngay'**
  String get bookNow;

  /// No description provided for @bookNowKicker.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch nhanh'**
  String get bookNowKicker;

  /// No description provided for @servicesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get servicesTitle;

  /// No description provided for @searchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm dịch vụ…'**
  String get searchHint;

  /// No description provided for @allCategories.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get allCategories;

  /// No description provided for @viewDetails.
  ///
  /// In vi, this message translates to:
  /// **'Xem chi tiết'**
  String get viewDetails;

  /// No description provided for @viewAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get viewAll;

  /// No description provided for @fromPrice.
  ///
  /// In vi, this message translates to:
  /// **'từ {price}'**
  String fromPrice(String price);

  /// No description provided for @minutesShort.
  ///
  /// In vi, this message translates to:
  /// **'{n} phút'**
  String minutesShort(int n);

  /// No description provided for @noResults.
  ///
  /// In vi, this message translates to:
  /// **'Không có kết quả'**
  String get noResults;

  /// No description provided for @popularCategories.
  ///
  /// In vi, this message translates to:
  /// **'Danh mục phổ biến'**
  String get popularCategories;

  /// No description provided for @howItWorks.
  ///
  /// In vi, this message translates to:
  /// **'Cách hoạt động'**
  String get howItWorks;

  /// No description provided for @whyKyco.
  ///
  /// In vi, this message translates to:
  /// **'Vì sao chọn Kyco'**
  String get whyKyco;

  /// No description provided for @exploreServices.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá dịch vụ'**
  String get exploreServices;

  /// No description provided for @relatedServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ liên quan'**
  String get relatedServices;

  /// No description provided for @reviewsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get reviewsTitle;

  /// No description provided for @reviewCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} đánh giá'**
  String reviewCount(int n);

  /// No description provided for @providersAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Đối tác sẵn sàng'**
  String get providersAvailable;

  /// No description provided for @checkoutTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt dịch vụ'**
  String get checkoutTitle;

  /// No description provided for @dateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get dateLabel;

  /// No description provided for @timeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giờ'**
  String get timeLabel;

  /// No description provided for @wardLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phường xã'**
  String get wardLabel;

  /// No description provided for @neighborhoodLabel.
  ///
  /// In vi, this message translates to:
  /// **'Khu phố'**
  String get neighborhoodLabel;

  /// No description provided for @addressLineLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get addressLineLabel;

  /// No description provided for @notesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get notesLabel;

  /// No description provided for @subtotalLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tạm tính'**
  String get subtotalLabel;

  /// No description provided for @confirmBooking.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đặt lịch'**
  String get confirmBooking;

  /// No description provided for @signInToConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để xác nhận'**
  String get signInToConfirm;

  /// No description provided for @guestCheckoutNotice.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể điền đầy đủ — chỉ cần đăng nhập khi xác nhận.'**
  String get guestCheckoutNotice;

  /// No description provided for @draftRestored.
  ///
  /// In vi, this message translates to:
  /// **'Đã khôi phục thông tin'**
  String get draftRestored;

  /// No description provided for @deferredPaymentNotice.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán sau khi hoàn thành — tiền mặt.'**
  String get deferredPaymentNotice;

  /// No description provided for @bookingCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt lịch #{id}'**
  String bookingCreated(Object id);

  /// No description provided for @step1Category.
  ///
  /// In vi, this message translates to:
  /// **'1. Chọn danh mục'**
  String get step1Category;

  /// No description provided for @step2Service.
  ///
  /// In vi, this message translates to:
  /// **'2. Chọn dịch vụ'**
  String get step2Service;

  /// No description provided for @locationsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực phục vụ'**
  String get locationsTitle;

  /// No description provided for @cityServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ tại {city}'**
  String cityServices(String city);

  /// No description provided for @providerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ đối tác'**
  String get providerTitle;

  /// No description provided for @verifiedBadge.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh'**
  String get verifiedBadge;

  /// No description provided for @jobsCompleted.
  ///
  /// In vi, this message translates to:
  /// **'{n} công việc'**
  String jobsCompleted(int n);

  /// No description provided for @memberSince.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên từ {date}'**
  String memberSince(String date);

  /// No description provided for @subscriptionsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gói định kỳ'**
  String get subscriptionsTitle;

  /// No description provided for @perMonth.
  ///
  /// In vi, this message translates to:
  /// **'{price}/tháng'**
  String perMonth(String price);

  /// No description provided for @notificationsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu đã đọc'**
  String get markAllRead;

  /// No description provided for @messagesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get messagesTitle;

  /// No description provided for @noMessages.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nhắn'**
  String get noMessages;

  /// No description provided for @signInToView.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để xem'**
  String get signInToView;

  /// No description provided for @inviteFriends.
  ///
  /// In vi, this message translates to:
  /// **'Mời bạn bè'**
  String get inviteFriends;

  /// No description provided for @becomePartner.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành đối tác'**
  String get becomePartner;

  /// No description provided for @contactUs.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get contactUs;

  /// No description provided for @aboutKyco.
  ///
  /// In vi, this message translates to:
  /// **'Về Kyco'**
  String get aboutKyco;

  /// No description provided for @faqs.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi thường gặp'**
  String get faqs;

  /// No description provided for @notSignedIn.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đăng nhập'**
  String get notSignedIn;

  /// No description provided for @loadMore.
  ///
  /// In vi, this message translates to:
  /// **'Tải thêm'**
  String get loadMore;

  /// No description provided for @noReviewsYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá'**
  String get noReviewsYet;

  /// No description provided for @noDescription.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có mô tả'**
  String get noDescription;

  /// No description provided for @serviceNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy dịch vụ'**
  String get serviceNotFound;

  /// No description provided for @partnerNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy đối tác'**
  String get partnerNotFound;

  /// No description provided for @noNotifications.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thông báo'**
  String get noNotifications;

  /// No description provided for @wardsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} khu vực'**
  String wardsCount(Object count);

  /// No description provided for @completeRequiredFields.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng điền đủ thông tin bắt buộc'**
  String get completeRequiredFields;

  /// No description provided for @confirmationCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã xác nhận'**
  String get confirmationCode;

  /// No description provided for @mySubscriptions.
  ///
  /// In vi, this message translates to:
  /// **'Gói của tôi'**
  String get mySubscriptions;

  /// No description provided for @plansTitle.
  ///
  /// In vi, this message translates to:
  /// **'Các gói'**
  String get plansTitle;

  /// No description provided for @monthsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} tháng'**
  String monthsCount(Object count);

  /// No description provided for @noActiveSubscriptions.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có gói đang hoạt động'**
  String get noActiveSubscriptions;

  /// No description provided for @sessionsProgress.
  ///
  /// In vi, this message translates to:
  /// **'Buổi {done}/{total}'**
  String sessionsProgress(Object done, Object total);

  /// No description provided for @nextChargeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ tính kế: {date}'**
  String nextChargeLabel(Object date);

  /// No description provided for @manageOnWeb.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hoặc đổi gói trên kyco.vn'**
  String get manageOnWeb;

  /// No description provided for @provWorkspace.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực đối tác'**
  String get provWorkspace;

  /// No description provided for @provComingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Sắp ra mắt'**
  String get provComingSoon;

  /// No description provided for @provTabHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get provTabHome;

  /// No description provided for @provTabJobs.
  ///
  /// In vi, this message translates to:
  /// **'Công việc'**
  String get provTabJobs;

  /// No description provided for @provTabWallet.
  ///
  /// In vi, this message translates to:
  /// **'Ví'**
  String get provTabWallet;

  /// No description provided for @provTabAvailability.
  ///
  /// In vi, this message translates to:
  /// **'Lịch rảnh'**
  String get provTabAvailability;

  /// No description provided for @provTabMore.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get provTabMore;

  /// No description provided for @provHomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng điều khiển'**
  String get provHomeTitle;

  /// No description provided for @provJobsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Công việc'**
  String get provJobsTitle;

  /// No description provided for @provJobsAssigned.
  ///
  /// In vi, this message translates to:
  /// **'Được giao'**
  String get provJobsAssigned;

  /// No description provided for @provJobsAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Khả dụng'**
  String get provJobsAvailable;

  /// No description provided for @provWalletTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ví của tôi'**
  String get provWalletTitle;

  /// No description provided for @provAvailabilityTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch rảnh'**
  String get provAvailabilityTitle;

  /// No description provided for @provMoreTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get provMoreTitle;

  /// No description provided for @provBonusesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng'**
  String get provBonusesTitle;

  /// No description provided for @provGoalsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu'**
  String get provGoalsTitle;

  /// No description provided for @provLeaderboardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng xếp hạng'**
  String get provLeaderboardTitle;

  /// No description provided for @provFinesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phí phạt'**
  String get provFinesTitle;

  /// No description provided for @provAppealTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại'**
  String get provAppealTitle;

  /// No description provided for @provCancellationsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hủy đơn'**
  String get provCancellationsTitle;

  /// No description provided for @provReferralsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
  String get provReferralsTitle;

  /// No description provided for @provSupportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get provSupportTitle;

  /// No description provided for @provVipTitle.
  ///
  /// In vi, this message translates to:
  /// **'VIP'**
  String get provVipTitle;

  /// No description provided for @provSwitchToCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển sang khách hàng'**
  String get provSwitchToCustomer;

  /// No description provided for @provSignInRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng đăng nhập để tiếp tục.'**
  String get provSignInRequired;

  /// No description provided for @provAvailLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải được lịch làm việc. Máy chủ có thể đang bảo trì.'**
  String get provAvailLoadError;

  /// No description provided for @provAvailWeeklyHeading.
  ///
  /// In vi, this message translates to:
  /// **'Lịch lặp hằng tuần'**
  String get provAvailWeeklyHeading;

  /// No description provided for @provAvailWeeklySub.
  ///
  /// In vi, this message translates to:
  /// **'Khung giờ bạn nhận đơn mỗi tuần. Chạm một ngày để chỉnh.'**
  String get provAvailWeeklySub;

  /// No description provided for @provAvailOverridesHeading.
  ///
  /// In vi, this message translates to:
  /// **'Điều chỉnh theo ngày'**
  String get provAvailOverridesHeading;

  /// No description provided for @provAvailOverridesSub.
  ///
  /// In vi, this message translates to:
  /// **'Thay lịch cho một ngày cụ thể (ngày lễ, nghỉ phép…).'**
  String get provAvailOverridesSub;

  /// No description provided for @provAvailAddOverride.
  ///
  /// In vi, this message translates to:
  /// **'Thêm điều chỉnh'**
  String get provAvailAddOverride;

  /// No description provided for @provAvailFreeHoursTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tổng giờ rảnh mỗi tuần'**
  String get provAvailFreeHoursTitle;

  /// No description provided for @provAvailNoSlots.
  ///
  /// In vi, this message translates to:
  /// **'Không nhận đơn'**
  String get provAvailNoSlots;

  /// No description provided for @provAvailUnavailableFull.
  ///
  /// In vi, this message translates to:
  /// **'Nghỉ cả ngày'**
  String get provAvailUnavailableFull;

  /// No description provided for @provAvailEditDay.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh lịch ngày'**
  String get provAvailEditDay;

  /// No description provided for @provAvailAddSlot.
  ///
  /// In vi, this message translates to:
  /// **'Thêm khung giờ'**
  String get provAvailAddSlot;

  /// No description provided for @provAvailStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get provAvailStart;

  /// No description provided for @provAvailEnd.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get provAvailEnd;

  /// No description provided for @provAvailSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get provAvailSave;

  /// No description provided for @provAvailCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get provAvailCancel;

  /// No description provided for @provAvailSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu lịch làm việc.'**
  String get provAvailSaved;

  /// No description provided for @provAvailSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại. Vui lòng thử lại.'**
  String get provAvailSaveFailed;

  /// No description provided for @provAvailPickDate.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày'**
  String get provAvailPickDate;

  /// No description provided for @provAvailConflictTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trùng với đơn đã nhận'**
  String get provAvailConflictTitle;

  /// No description provided for @provAvailSaveAnyway.
  ///
  /// In vi, this message translates to:
  /// **'Vẫn lưu'**
  String get provAvailSaveAnyway;

  /// No description provided for @provAvailEmptyOverrides.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có điều chỉnh nào.'**
  String get provAvailEmptyOverrides;

  /// No description provided for @provAvailHoursUnit.
  ///
  /// In vi, this message translates to:
  /// **'giờ'**
  String get provAvailHoursUnit;

  /// No description provided for @provAvailSlotOrderError.
  ///
  /// In vi, this message translates to:
  /// **'Giờ kết thúc phải sau giờ bắt đầu.'**
  String get provAvailSlotOrderError;

  /// No description provided for @provAvailConflictBody.
  ///
  /// In vi, this message translates to:
  /// **'Các đơn đã nhận sẽ không còn nằm trong lịch rảnh: {ids}. Vẫn lưu?'**
  String provAvailConflictBody(String ids);

  /// No description provided for @provAvailWeekdayShort0.
  ///
  /// In vi, this message translates to:
  /// **'CN'**
  String get provAvailWeekdayShort0;

  /// No description provided for @provAvailWeekdayShort1.
  ///
  /// In vi, this message translates to:
  /// **'T2'**
  String get provAvailWeekdayShort1;

  /// No description provided for @provAvailWeekdayShort2.
  ///
  /// In vi, this message translates to:
  /// **'T3'**
  String get provAvailWeekdayShort2;

  /// No description provided for @provAvailWeekdayShort3.
  ///
  /// In vi, this message translates to:
  /// **'T4'**
  String get provAvailWeekdayShort3;

  /// No description provided for @provAvailWeekdayShort4.
  ///
  /// In vi, this message translates to:
  /// **'T5'**
  String get provAvailWeekdayShort4;

  /// No description provided for @provAvailWeekdayShort5.
  ///
  /// In vi, this message translates to:
  /// **'T6'**
  String get provAvailWeekdayShort5;

  /// No description provided for @provAvailWeekdayShort6.
  ///
  /// In vi, this message translates to:
  /// **'T7'**
  String get provAvailWeekdayShort6;

  /// No description provided for @provAvailWeekdayLong0.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhật'**
  String get provAvailWeekdayLong0;

  /// No description provided for @provAvailWeekdayLong1.
  ///
  /// In vi, this message translates to:
  /// **'Thứ hai'**
  String get provAvailWeekdayLong1;

  /// No description provided for @provAvailWeekdayLong2.
  ///
  /// In vi, this message translates to:
  /// **'Thứ ba'**
  String get provAvailWeekdayLong2;

  /// No description provided for @provAvailWeekdayLong3.
  ///
  /// In vi, this message translates to:
  /// **'Thứ tư'**
  String get provAvailWeekdayLong3;

  /// No description provided for @provAvailWeekdayLong4.
  ///
  /// In vi, this message translates to:
  /// **'Thứ năm'**
  String get provAvailWeekdayLong4;

  /// No description provided for @provAvailWeekdayLong5.
  ///
  /// In vi, this message translates to:
  /// **'Thứ sáu'**
  String get provAvailWeekdayLong5;

  /// No description provided for @provAvailWeekdayLong6.
  ///
  /// In vi, this message translates to:
  /// **'Thứ bảy'**
  String get provAvailWeekdayLong6;

  /// No description provided for @provAvailHours.
  ///
  /// In vi, this message translates to:
  /// **'{m, plural, =0{{h} giờ} other{{h} giờ {m}}}'**
  String provAvailHours(int h, int m);

  /// No description provided for @provJobStatusPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ xác nhận'**
  String get provJobStatusPending;

  /// No description provided for @provJobStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang làm'**
  String get provJobStatusActive;

  /// No description provided for @provJobStatusClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng'**
  String get provJobStatusClosed;

  /// No description provided for @provJobNetHint.
  ///
  /// In vi, this message translates to:
  /// **'≈ 80% về bạn'**
  String get provJobNetHint;

  /// No description provided for @provJobsAssignedEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có công việc nào'**
  String get provJobsAssignedEmpty;

  /// No description provided for @provPoolEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Hiện chưa có đơn nào để nhận'**
  String get provPoolEmpty;

  /// No description provided for @provJobsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được công việc'**
  String get provJobsLoadError;

  /// No description provided for @provPoolAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Đơn có thể nhận'**
  String get provPoolAvailable;

  /// No description provided for @provPoolAssigned.
  ///
  /// In vi, this message translates to:
  /// **'Đơn của bạn'**
  String get provPoolAssigned;

  /// No description provided for @provClaimAction.
  ///
  /// In vi, this message translates to:
  /// **'Nhận đơn'**
  String get provClaimAction;

  /// No description provided for @provClaimGateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa thể nhận đơn'**
  String get provClaimGateTitle;

  /// No description provided for @provClaimGateBody.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản của bạn đang bị tạm hạn chế nhận đơn.'**
  String get provClaimGateBody;

  /// No description provided for @provClaimSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận đơn'**
  String get provClaimSuccess;

  /// No description provided for @provClaimError.
  ///
  /// In vi, this message translates to:
  /// **'Không nhận được đơn, vui lòng thử lại'**
  String get provClaimError;

  /// No description provided for @provHomeGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào, {name}'**
  String provHomeGreeting(String name);

  /// No description provided for @provHomeGreetingPlain.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào'**
  String get provHomeGreetingPlain;

  /// No description provided for @provHomeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý công việc, theo dõi thu nhập, và tận dụng giờ cao điểm.'**
  String get provHomeSubtitle;

  /// No description provided for @provHomeKpi30d.
  ///
  /// In vi, this message translates to:
  /// **'KPI 30 ngày qua'**
  String get provHomeKpi30d;

  /// No description provided for @provKpiAcceptanceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhận job'**
  String get provKpiAcceptanceLabel;

  /// No description provided for @provKpiCompletionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get provKpiCompletionLabel;

  /// No description provided for @provKpiRatingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get provKpiRatingLabel;

  /// No description provided for @provKpiPunctualityLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đúng giờ'**
  String get provKpiPunctualityLabel;

  /// No description provided for @provHomeEarningsMonth.
  ///
  /// In vi, this message translates to:
  /// **'THU NHẬP THÁNG'**
  String get provHomeEarningsMonth;

  /// No description provided for @provHomeBalance.
  ///
  /// In vi, this message translates to:
  /// **'Số dư ví'**
  String get provHomeBalance;

  /// No description provided for @provHomeLifetime.
  ///
  /// In vi, this message translates to:
  /// **'Luỹ kế'**
  String get provHomeLifetime;

  /// No description provided for @provHomeStatActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang làm'**
  String get provHomeStatActive;

  /// No description provided for @provHomeStatTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng'**
  String get provHomeStatTotal;

  /// No description provided for @provHomeToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get provHomeToday;

  /// No description provided for @provHomeTodayEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có lịch hôm nay. Tận hưởng ngày nghỉ ☕.'**
  String get provHomeTodayEmpty;

  /// No description provided for @provHomeUpcoming.
  ///
  /// In vi, this message translates to:
  /// **'Sắp tới'**
  String get provHomeUpcoming;

  /// No description provided for @provHomeUpcomingEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lịch sắp tới.'**
  String get provHomeUpcomingEmpty;

  /// No description provided for @provHomeSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả →'**
  String get provHomeSeeAll;

  /// No description provided for @provStatusPending.
  ///
  /// In vi, this message translates to:
  /// **'đang chờ'**
  String get provStatusPending;

  /// No description provided for @provStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'đang làm'**
  String get provStatusActive;

  /// No description provided for @provStatusClosed.
  ///
  /// In vi, this message translates to:
  /// **'đã đóng'**
  String get provStatusClosed;

  /// No description provided for @provWalletExportTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xuất CSV tháng này'**
  String get provWalletExportTooltip;

  /// No description provided for @provWalletTxns.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch'**
  String get provWalletTxns;

  /// No description provided for @provWalletWithdrawHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử rút tiền'**
  String get provWalletWithdrawHistory;

  /// No description provided for @provWalletPayoutHint.
  ///
  /// In vi, this message translates to:
  /// **'Tiền được giữ và giải ngân theo lịch của Kyco.'**
  String get provWalletPayoutHint;

  /// No description provided for @provWalletAvailableBalance.
  ///
  /// In vi, this message translates to:
  /// **'SỐ DƯ KHẢ DỤNG'**
  String get provWalletAvailableBalance;

  /// No description provided for @provWalletBalanceSchedule.
  ///
  /// In vi, this message translates to:
  /// **'Giải ngân sau khi khách xác nhận, chuyển về tài khoản ngân hàng đã đăng ký.'**
  String get provWalletBalanceSchedule;

  /// No description provided for @provWalletTileTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng thu nhập'**
  String get provWalletTileTotal;

  /// No description provided for @provWalletTileMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng này'**
  String get provWalletTileMonth;

  /// No description provided for @provWalletTileJobs.
  ///
  /// In vi, this message translates to:
  /// **'Số công việc'**
  String get provWalletTileJobs;

  /// No description provided for @provWalletTileFees.
  ///
  /// In vi, this message translates to:
  /// **'Phí đã trừ'**
  String get provWalletTileFees;

  /// No description provided for @provWalletWithdrawTitle.
  ///
  /// In vi, this message translates to:
  /// **'Rút tiền về ngân hàng'**
  String get provWalletWithdrawTitle;

  /// No description provided for @provWalletWithdrawBody.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu rút tiền cần xác minh bảo mật để bảo vệ tài khoản.'**
  String get provWalletWithdrawBody;

  /// No description provided for @provWalletWithdrawMin.
  ///
  /// In vi, this message translates to:
  /// **'Cần tối thiểu {min} để rút tiền.'**
  String provWalletWithdrawMin(String min);

  /// No description provided for @provWalletWithdrawAction.
  ///
  /// In vi, this message translates to:
  /// **'Rút tiền'**
  String get provWalletWithdrawAction;

  /// No description provided for @provWalletBalanceAfter.
  ///
  /// In vi, this message translates to:
  /// **'Số dư {amount}'**
  String provWalletBalanceAfter(String amount);

  /// No description provided for @provWalletReasonEarning.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập công việc'**
  String get provWalletReasonEarning;

  /// No description provided for @provWalletReasonTip.
  ///
  /// In vi, this message translates to:
  /// **'Tiền tip'**
  String get provWalletReasonTip;

  /// No description provided for @provWalletReasonBonus.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng'**
  String get provWalletReasonBonus;

  /// No description provided for @provWalletReasonPayout.
  ///
  /// In vi, this message translates to:
  /// **'Rút tiền'**
  String get provWalletReasonPayout;

  /// No description provided for @provWalletReasonCommission.
  ///
  /// In vi, this message translates to:
  /// **'Hoa hồng'**
  String get provWalletReasonCommission;

  /// No description provided for @provWalletReasonClawback.
  ///
  /// In vi, this message translates to:
  /// **'Thu hồi'**
  String get provWalletReasonClawback;

  /// No description provided for @provWalletReasonAdjustment.
  ///
  /// In vi, this message translates to:
  /// **'Điều chỉnh'**
  String get provWalletReasonAdjustment;

  /// No description provided for @provWalletReasonDefault.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch'**
  String get provWalletReasonDefault;

  /// No description provided for @provWalletPayoutReleased.
  ///
  /// In vi, this message translates to:
  /// **'Đã giải ngân'**
  String get provWalletPayoutReleased;

  /// No description provided for @provWalletPayoutWithdrawn.
  ///
  /// In vi, this message translates to:
  /// **'Đã rút'**
  String get provWalletPayoutWithdrawn;

  /// No description provided for @provWalletPayoutReversed.
  ///
  /// In vi, this message translates to:
  /// **'Đã hoàn'**
  String get provWalletPayoutReversed;

  /// No description provided for @provWalletPayoutHeld.
  ///
  /// In vi, this message translates to:
  /// **'Đang giữ'**
  String get provWalletPayoutHeld;

  /// No description provided for @provWalletWithdrawMinError.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền tối thiểu là {min}.'**
  String provWalletWithdrawMinError(String min);

  /// No description provided for @provWalletWithdrawMaxError.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền tối đa mỗi lần là {max}.'**
  String provWalletWithdrawMaxError(String max);

  /// No description provided for @provWalletSheetBalance.
  ///
  /// In vi, this message translates to:
  /// **'Số dư khả dụng: {amount}'**
  String provWalletSheetBalance(String amount);

  /// No description provided for @provWalletAmountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền (₫)'**
  String get provWalletAmountLabel;

  /// No description provided for @provWalletAmountHint.
  ///
  /// In vi, this message translates to:
  /// **'Từ {min} đến {max} · số nguyên đồng. Kyco kiểm tra và trừ số dư trên máy chủ.'**
  String provWalletAmountHint(String min, String max);

  /// No description provided for @provWalletContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get provWalletContinue;

  /// No description provided for @provWalletMaintenance.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng rút tiền sắp ra mắt.'**
  String get provWalletMaintenance;

  /// No description provided for @provWalletWithdrawSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu rút {amount} về {bank} ••••{tail}. Kyco chuyển trong 1-2 ngày làm việc.'**
  String provWalletWithdrawSubmitted(String amount, String bank, String tail);

  /// No description provided for @provWalletWithdrawSubmittedNoBank.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghi nhận yêu cầu rút {amount}. Kyco chuyển trong 1-2 ngày làm việc.'**
  String provWalletWithdrawSubmittedNoBank(String amount);

  /// No description provided for @provWalletWithdrawPending.
  ///
  /// In vi, this message translates to:
  /// **'Một yêu cầu rút tiền đang được xử lý. Vui lòng thử lại sau giây lát.'**
  String get provWalletWithdrawPending;

  /// No description provided for @provWalletWithdrawStepUp.
  ///
  /// In vi, this message translates to:
  /// **'Cần xác minh bảo mật để rút tiền. Vui lòng thử lại.'**
  String get provWalletWithdrawStepUp;

  /// No description provided for @provWalletStepUpTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh bảo mật'**
  String get provWalletStepUpTitle;

  /// No description provided for @provWalletStepUpPassword.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mật khẩu để xác nhận yêu cầu rút tiền.'**
  String get provWalletStepUpPassword;

  /// No description provided for @provWalletStepUpPhonePrompt.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số điện thoại đã đăng ký để nhận mã OTP xác nhận rút tiền.'**
  String get provWalletStepUpPhonePrompt;

  /// No description provided for @provWalletStepUpOtpPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã OTP vừa gửi tới điện thoại để xác nhận yêu cầu rút tiền.'**
  String get provWalletStepUpOtpPrompt;

  /// No description provided for @provWalletConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get provWalletConfirm;

  /// No description provided for @provWalletResendSending.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi lại…'**
  String get provWalletResendSending;

  /// No description provided for @provWalletResend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại mã'**
  String get provWalletResend;

  /// No description provided for @provWalletExportMaintenance.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng xuất CSV sắp ra mắt.'**
  String get provWalletExportMaintenance;

  /// No description provided for @provOtpInvalidPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại không hợp lệ.'**
  String get provOtpInvalidPhone;

  /// No description provided for @provOtpRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau.'**
  String get provOtpRateLimited;

  /// No description provided for @provOtpSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được mã OTP. Vui lòng thử lại.'**
  String get provOtpSendFailed;

  /// No description provided for @provOtpSentTo.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi mã OTP tới {phone}.'**
  String provOtpSentTo(String phone);

  /// No description provided for @provPhoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get provPhoneLabel;

  /// No description provided for @provSendOtp.
  ///
  /// In vi, this message translates to:
  /// **'Gửi mã OTP'**
  String get provSendOtp;

  /// No description provided for @provOtpLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã OTP'**
  String get provOtpLabel;

  /// No description provided for @provJdNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy công việc'**
  String get provJdNotFound;

  /// No description provided for @provJdTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết công việc'**
  String get provJdTitle;

  /// No description provided for @provJdFeatureEnabling.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang được bật, vui lòng thử lại sau ít phút.'**
  String get provJdFeatureEnabling;

  /// No description provided for @provJdGpsOff.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng bật Dịch vụ vị trí (GPS) để check-in.'**
  String get provJdGpsOff;

  /// No description provided for @provJdGpsPermNeeded.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng cần quyền vị trí để check-in tại địa điểm khách.'**
  String get provJdGpsPermNeeded;

  /// No description provided for @provJdGpsPermOff.
  ///
  /// In vi, this message translates to:
  /// **'Quyền vị trí đã bị tắt. Hãy cấp lại trong Cài đặt.'**
  String get provJdGpsPermOff;

  /// No description provided for @provJdGpsFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được vị trí, vui lòng thử lại.'**
  String get provJdGpsFailed;

  /// No description provided for @provJdCamPermNeeded.
  ///
  /// In vi, this message translates to:
  /// **'Ứng dụng cần quyền camera để chụp ảnh công việc.'**
  String get provJdCamPermNeeded;

  /// No description provided for @provJdPhotoUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh lên, vui lòng thử lại.'**
  String get provJdPhotoUploadFailed;

  /// No description provided for @provJdDeclineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối công việc'**
  String get provJdDeclineTitle;

  /// No description provided for @provJdDeclineWarning.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối sau khi đã nhận có thể bị tính phí phạt và ảnh hưởng điểm uy tín. Kyco sẽ hiển thị mức phí (nếu có) sau khi xác nhận.'**
  String get provJdDeclineWarning;

  /// No description provided for @provJdReasonOptional.
  ///
  /// In vi, this message translates to:
  /// **'Lý do (không bắt buộc)'**
  String get provJdReasonOptional;

  /// No description provided for @provJdDecline.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get provJdDecline;

  /// No description provided for @provJdDeclined.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối công việc'**
  String get provJdDeclined;

  /// No description provided for @provJdCancelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ công việc'**
  String get provJdCancelTitle;

  /// No description provided for @provJdCancelWarning.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ đơn đã nhận có thể phát sinh phí phạt theo chính sách. Mức phí do Kyco tính và hiển thị sau khi xác nhận.'**
  String get provJdCancelWarning;

  /// No description provided for @provJdCancelReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do huỷ'**
  String get provJdCancelReason;

  /// No description provided for @provJdCancelJob.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ đơn'**
  String get provJdCancelJob;

  /// No description provided for @provJdCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ công việc'**
  String get provJdCancelled;

  /// No description provided for @provJdEnRouteSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã bắt đầu di chuyển đến khách'**
  String get provJdEnRouteSnack;

  /// No description provided for @provJdCheckedOutSnack.
  ///
  /// In vi, this message translates to:
  /// **'Đã check-out. Đơn được chuyển sang chờ khách xác nhận & thanh toán.'**
  String get provJdCheckedOutSnack;

  /// No description provided for @provJdPhotoUploaded.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải ảnh lên'**
  String get provJdPhotoUploaded;

  /// No description provided for @provJdFaceSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi xác minh khuôn mặt'**
  String get provJdFaceSubmitted;

  /// No description provided for @provJdMarkedComplete.
  ///
  /// In vi, this message translates to:
  /// **'Đã báo hoàn thành công việc'**
  String get provJdMarkedComplete;

  /// No description provided for @provJdCashConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đã nhận tiền mặt'**
  String get provJdCashConfirmTitle;

  /// No description provided for @provJdCashConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Kyco sẽ thu hoa hồng 20% cho đơn tiền mặt này. Xác nhận bạn đã nhận đủ tiền từ khách?'**
  String get provJdCashConfirmBody;

  /// No description provided for @provJdCashReceived.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận tiền'**
  String get provJdCashReceived;

  /// No description provided for @provJdComplaintTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi khiếu nại'**
  String get provJdComplaintTitle;

  /// No description provided for @provJdComplaintBody.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả sự cố với đơn này. Đội hỗ trợ Kyco sẽ xem xét.'**
  String get provJdComplaintBody;

  /// No description provided for @provJdComplaintHint.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung khiếu nại'**
  String get provJdComplaintHint;

  /// No description provided for @provJdSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get provJdSend;

  /// No description provided for @provJdComplaintSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi khiếu nại'**
  String get provJdComplaintSent;

  /// No description provided for @provJdSosBody.
  ///
  /// In vi, this message translates to:
  /// **'Gửi cảnh báo khẩn cấp tới Kyco cho công việc này? Đội an toàn sẽ liên hệ ngay.'**
  String get provJdSosBody;

  /// No description provided for @provJdSosConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Gửi SOS'**
  String get provJdSosConfirm;

  /// No description provided for @provJdSosSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi SOS. Đội an toàn Kyco sẽ liên hệ ngay.'**
  String get provJdSosSent;

  /// No description provided for @provJdCheckedIn.
  ///
  /// In vi, this message translates to:
  /// **'Đã check-in'**
  String get provJdCheckedIn;

  /// No description provided for @provJdWithinGeofence.
  ///
  /// In vi, this message translates to:
  /// **'trong phạm vi địa điểm'**
  String get provJdWithinGeofence;

  /// No description provided for @provJdMetersAway.
  ///
  /// In vi, this message translates to:
  /// **'cách ~{m}m'**
  String provJdMetersAway(Object m);

  /// No description provided for @provJdMinLate.
  ///
  /// In vi, this message translates to:
  /// **'trễ {n} phút'**
  String provJdMinLate(Object n);

  /// No description provided for @provJdLateFineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phí trễ giờ'**
  String get provJdLateFineTitle;

  /// No description provided for @provJdLateFineBody.
  ///
  /// In vi, this message translates to:
  /// **'Kyco ghi nhận phí trễ giờ: {amount}. Số tiền do hệ thống tính.'**
  String provJdLateFineBody(String amount);

  /// No description provided for @provJdFineTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phí phạt'**
  String get provJdFineTitle;

  /// No description provided for @provJdFineBody.
  ///
  /// In vi, this message translates to:
  /// **'Kyco áp dụng phí phạt: {amount}. Số tiền do hệ thống tính, không thể thay đổi.'**
  String provJdFineBody(String amount);

  /// No description provided for @provJdCashRecorded.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghi nhận tiền mặt'**
  String get provJdCashRecorded;

  /// No description provided for @provJdCashRecordedBody.
  ///
  /// In vi, this message translates to:
  /// **'Kyco đã tính hoa hồng 20% cho đơn này. Số liệu dưới đây do hệ thống tính:'**
  String get provJdCashRecordedBody;

  /// No description provided for @provJdSeeWallet.
  ///
  /// In vi, this message translates to:
  /// **'Xem ví để biết chi tiết.'**
  String get provJdSeeWallet;

  /// No description provided for @provJdClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get provJdClose;

  /// No description provided for @provJdDialogCancel.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get provJdDialogCancel;

  /// No description provided for @provJdNeedMore.
  ///
  /// In vi, this message translates to:
  /// **'còn thiếu {missing}'**
  String provJdNeedMore(Object missing);

  /// No description provided for @provJdCompleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành công việc'**
  String get provJdCompleteTitle;

  /// No description provided for @provJdCompleteGateBody.
  ///
  /// In vi, this message translates to:
  /// **'Cần đủ ảnh trước/giữa/sau ca mới được báo hoàn thành:'**
  String get provJdCompleteGateBody;

  /// No description provided for @provJdBefore.
  ///
  /// In vi, this message translates to:
  /// **'Trước ca'**
  String get provJdBefore;

  /// No description provided for @provJdMid.
  ///
  /// In vi, this message translates to:
  /// **'Giữa ca'**
  String get provJdMid;

  /// No description provided for @provJdAfter.
  ///
  /// In vi, this message translates to:
  /// **'Sau ca'**
  String get provJdAfter;

  /// No description provided for @provJdMarkComplete.
  ///
  /// In vi, this message translates to:
  /// **'Báo hoàn thành'**
  String get provJdMarkComplete;

  /// No description provided for @provJdReportProblem.
  ///
  /// In vi, this message translates to:
  /// **'Gửi khiếu nại về đơn này'**
  String get provJdReportProblem;

  /// No description provided for @provJdPhasePending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ bạn xác nhận'**
  String get provJdPhasePending;

  /// No description provided for @provJdPhaseEnRoute.
  ///
  /// In vi, this message translates to:
  /// **'Chuẩn bị di chuyển'**
  String get provJdPhaseEnRoute;

  /// No description provided for @provJdPhaseOnSite.
  ///
  /// In vi, this message translates to:
  /// **'Đang làm việc tại địa điểm'**
  String get provJdPhaseOnSite;

  /// No description provided for @provJdPhaseWrapUp.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất & báo xong'**
  String get provJdPhaseWrapUp;

  /// No description provided for @provJdPhaseAwaitingCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Chờ khách xác nhận (tự động sau 2h)'**
  String get provJdPhaseAwaitingCustomer;

  /// No description provided for @provJdPhaseAwaitingCash.
  ///
  /// In vi, this message translates to:
  /// **'Chờ xác nhận tiền mặt'**
  String get provJdPhaseAwaitingCash;

  /// No description provided for @provJdPhaseAwaitingPayment.
  ///
  /// In vi, this message translates to:
  /// **'Khách đang thanh toán'**
  String get provJdPhaseAwaitingPayment;

  /// No description provided for @provJdPhaseSettled.
  ///
  /// In vi, this message translates to:
  /// **'Đã tất toán'**
  String get provJdPhaseSettled;

  /// No description provided for @provJdPhaseClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng'**
  String get provJdPhaseClosed;

  /// No description provided for @provJdPhaseCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get provJdPhaseCancelled;

  /// No description provided for @provJdPhaseUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái công việc'**
  String get provJdPhaseUnknown;

  /// No description provided for @provJdOrderInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin đơn'**
  String get provJdOrderInfo;

  /// No description provided for @provJdCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Khách hàng'**
  String get provJdCustomer;

  /// No description provided for @provJdTime.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian'**
  String get provJdTime;

  /// No description provided for @provJdDuration.
  ///
  /// In vi, this message translates to:
  /// **'Thời lượng'**
  String get provJdDuration;

  /// No description provided for @provJdAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get provJdAddress;

  /// No description provided for @provJdPayment.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get provJdPayment;

  /// No description provided for @provJdYourEarnings.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập của bạn'**
  String get provJdYourEarnings;

  /// No description provided for @provJdAmountsComputed.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền do Kyco tính và hiển thị — ứng dụng không tự tính.'**
  String get provJdAmountsComputed;

  /// No description provided for @provJdPayCash.
  ///
  /// In vi, this message translates to:
  /// **'Tiền mặt'**
  String get provJdPayCash;

  /// No description provided for @provJdPayBankTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản'**
  String get provJdPayBankTransfer;

  /// No description provided for @provJdConfirmAccept.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận & nhận việc'**
  String get provJdConfirmAccept;

  /// No description provided for @provJdStartTracking.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu di chuyển (dùng GPS)'**
  String get provJdStartTracking;

  /// No description provided for @provJdCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Check-in tại địa điểm (GPS)'**
  String get provJdCheckIn;

  /// No description provided for @provJdBeforePhotoGate.
  ///
  /// In vi, this message translates to:
  /// **'Cần ≥ {need} ảnh \"trước ca\" mới được check-out (hiện {have}/{need}). Chụp ở khung ảnh bên dưới.'**
  String provJdBeforePhotoGate(Object need, Object have);

  /// No description provided for @provJdFaceVerify.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh khuôn mặt'**
  String get provJdFaceVerify;

  /// No description provided for @provJdCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Check-out (GPS)'**
  String get provJdCheckOut;

  /// No description provided for @provJdCashReceivedAction.
  ///
  /// In vi, this message translates to:
  /// **'✅ Đã nhận tiền mặt từ khách'**
  String get provJdCashReceivedAction;

  /// No description provided for @provJdCashCommissionNote.
  ///
  /// In vi, this message translates to:
  /// **'Kyco sẽ thu hoa hồng 20% cho đơn tiền mặt này (số tiền do hệ thống tính).'**
  String get provJdCashCommissionNote;

  /// No description provided for @provJdAwaitingCustomerInfo.
  ///
  /// In vi, this message translates to:
  /// **'⏳ Chờ khách xác nhận hoàn thành (tự động sau 2h).'**
  String get provJdAwaitingCustomerInfo;

  /// No description provided for @provJdAwaitingPaymentInfo.
  ///
  /// In vi, this message translates to:
  /// **'⏳ Khách đang thanh toán — Kyco sẽ chuyển 80% khi xác nhận.'**
  String get provJdAwaitingPaymentInfo;

  /// No description provided for @provJdClosedInfo.
  ///
  /// In vi, this message translates to:
  /// **'🔒 Công việc đã đóng. Không còn hành động nào.'**
  String get provJdClosedInfo;

  /// No description provided for @provJdCancelledInfo.
  ///
  /// In vi, this message translates to:
  /// **'Công việc đã huỷ.'**
  String get provJdCancelledInfo;

  /// No description provided for @provJdNoActions.
  ///
  /// In vi, this message translates to:
  /// **'Không có hành động khả dụng.'**
  String get provJdNoActions;

  /// No description provided for @provJdLifecycle.
  ///
  /// In vi, this message translates to:
  /// **'Vòng đời công việc'**
  String get provJdLifecycle;

  /// No description provided for @provJdPhotosRequired.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh cần để hoàn thành ({total}/{req})'**
  String provJdPhotosRequired(Object total, Object req);

  /// No description provided for @provJdSettledThanks.
  ///
  /// In vi, this message translates to:
  /// **'✅ Kyco đã thanh toán cho bạn 80% giá trị đơn hàng, cảm ơn bạn đã đồng hành!'**
  String get provJdSettledThanks;

  /// No description provided for @provJdJobPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh công việc (camera)'**
  String get provJdJobPhotos;

  /// No description provided for @provJdCapture.
  ///
  /// In vi, this message translates to:
  /// **'Chụp'**
  String get provJdCapture;

  /// No description provided for @provJdSafety.
  ///
  /// In vi, this message translates to:
  /// **'An toàn'**
  String get provJdSafety;

  /// No description provided for @provJdSendSos.
  ///
  /// In vi, this message translates to:
  /// **'Gửi SOS khẩn cấp'**
  String get provJdSendSos;

  /// No description provided for @provJdShareLocation.
  ///
  /// In vi, this message translates to:
  /// **'📍 Chia sẻ vị trí với khách'**
  String get provJdShareLocation;

  /// No description provided for @provJdShareLiveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ vị trí trực tiếp — sắp ra mắt'**
  String get provJdShareLiveTitle;

  /// No description provided for @provJdShareLiveBody.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang được phát triển. Khách chưa thể xem vị trí của bạn.'**
  String get provJdShareLiveBody;

  /// No description provided for @provJdChatTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trò chuyện với khách'**
  String get provJdChatTitle;

  /// No description provided for @provJdChatEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nhắn nào.'**
  String get provJdChatEmpty;

  /// No description provided for @provJdChatHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tin nhắn…'**
  String get provJdChatHint;

  /// No description provided for @provJdCommission20.
  ///
  /// In vi, this message translates to:
  /// **'Hoa hồng (20%)'**
  String get provJdCommission20;

  /// No description provided for @provJdWalletBalance.
  ///
  /// In vi, this message translates to:
  /// **'Số dư ví'**
  String get provJdWalletBalance;

  /// No description provided for @provJdOrderTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng đơn'**
  String get provJdOrderTotal;

  /// No description provided for @provJdFine.
  ///
  /// In vi, this message translates to:
  /// **'Phí phạt'**
  String get provJdFine;

  /// No description provided for @provBonusesWeekTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng tuần này'**
  String get provBonusesWeekTitle;

  /// No description provided for @provBonusesMonthTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng tháng này'**
  String get provBonusesMonthTitle;

  /// No description provided for @provBonusesHistoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử thưởng'**
  String get provBonusesHistoryTitle;

  /// No description provided for @provBonusesHistoryEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khoản thưởng nào được chi.'**
  String get provBonusesHistoryEmpty;

  /// No description provided for @provBonusesNone.
  ///
  /// In vi, this message translates to:
  /// **'Không có thưởng khả dụng.'**
  String get provBonusesNone;

  /// No description provided for @provBonusEarned.
  ///
  /// In vi, this message translates to:
  /// **'Đã đạt'**
  String get provBonusEarned;

  /// No description provided for @provBonusMax.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa'**
  String get provBonusMax;

  /// No description provided for @provBonusNotEarned.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đạt'**
  String get provBonusNotEarned;

  /// No description provided for @provBonusKindWeeklyJobs.
  ///
  /// In vi, this message translates to:
  /// **'🏆 Thưởng tuần (số đơn)'**
  String get provBonusKindWeeklyJobs;

  /// No description provided for @provBonusKindMonthlyRevenue.
  ///
  /// In vi, this message translates to:
  /// **'🏅 Thưởng tháng (doanh thu)'**
  String get provBonusKindMonthlyRevenue;

  /// No description provided for @provBonusKindPunctuality.
  ///
  /// In vi, this message translates to:
  /// **'📅 Thưởng chuyên cần'**
  String get provBonusKindPunctuality;

  /// No description provided for @provBonusKindRating.
  ///
  /// In vi, this message translates to:
  /// **'⭐ Thưởng rating cao'**
  String get provBonusKindRating;

  /// No description provided for @provBonusKindReferral.
  ///
  /// In vi, this message translates to:
  /// **'👥 Thưởng giới thiệu'**
  String get provBonusKindReferral;

  /// No description provided for @provGoalsThisWeek.
  ///
  /// In vi, this message translates to:
  /// **'Tuần này'**
  String get provGoalsThisWeek;

  /// No description provided for @provGoalsThisMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng này'**
  String get provGoalsThisMonth;

  /// No description provided for @provGoalJobs.
  ///
  /// In vi, this message translates to:
  /// **'Số đơn'**
  String get provGoalJobs;

  /// No description provided for @provGoalIncome.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập'**
  String get provGoalIncome;

  /// No description provided for @provGoalSet.
  ///
  /// In vi, this message translates to:
  /// **'Đặt mục tiêu'**
  String get provGoalSet;

  /// No description provided for @provGoalEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa mục tiêu'**
  String get provGoalEdit;

  /// No description provided for @provGoalSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu mục tiêu'**
  String get provGoalSaved;

  /// No description provided for @provGoalTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu'**
  String get provGoalTitle;

  /// No description provided for @provGoalTargetJobs.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu số đơn'**
  String get provGoalTargetJobs;

  /// No description provided for @provGoalTargetIncome.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu thu nhập (₫)'**
  String get provGoalTargetIncome;

  /// No description provided for @provGoalSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get provGoalSave;

  /// No description provided for @provGoalCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get provGoalCancel;

  /// No description provided for @provLbYourRank.
  ///
  /// In vi, this message translates to:
  /// **'Hạng của bạn: #{n}'**
  String provLbYourRank(Object n);

  /// No description provided for @provLbEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu xếp hạng.'**
  String get provLbEmpty;

  /// No description provided for @provLbWeek.
  ///
  /// In vi, this message translates to:
  /// **'Tuần'**
  String get provLbWeek;

  /// No description provided for @provLbMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get provLbMonth;

  /// No description provided for @provLbNationwide.
  ///
  /// In vi, this message translates to:
  /// **'Toàn quốc'**
  String get provLbNationwide;

  /// No description provided for @provLbYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get provLbYou;

  /// No description provided for @provLbJobs.
  ///
  /// In vi, this message translates to:
  /// **'{n} đơn'**
  String provLbJobs(Object n);

  /// No description provided for @provVipPerkPriorityTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ưu tiên nhận đơn'**
  String get provVipPerkPriorityTitle;

  /// No description provided for @provVipPerkPriorityBody.
  ///
  /// In vi, this message translates to:
  /// **'Được ưu tiên phân bổ các đơn giá trị cao trước các CTV khác.'**
  String get provVipPerkPriorityBody;

  /// No description provided for @provVipPerkAreaTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở rộng khu vực'**
  String get provVipPerkAreaTitle;

  /// No description provided for @provVipPerkAreaBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhận đơn ở nhiều quận/khu vực hơn để tối đa thu nhập.'**
  String get provVipPerkAreaBody;

  /// No description provided for @provVipPerkSupportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ VIP riêng'**
  String get provVipPerkSupportTitle;

  /// No description provided for @provVipPerkSupportBody.
  ///
  /// In vi, this message translates to:
  /// **'Đường dây hỗ trợ riêng 1900-VIP-XX, phản hồi nhanh 24/7.'**
  String get provVipPerkSupportBody;

  /// No description provided for @provVipPerkBadgeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huy hiệu VIP'**
  String get provVipPerkBadgeTitle;

  /// No description provided for @provVipPerkBadgeBody.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị huy hiệu Bạch kim với khách hàng để tăng độ tin cậy.'**
  String get provVipPerkBadgeBody;

  /// No description provided for @provVipPerkGiftTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quà & ưu đãi'**
  String get provVipPerkGiftTitle;

  /// No description provided for @provVipPerkGiftBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhận quà tri ân và các ưu đãi độc quyền dành cho CTV VIP.'**
  String get provVipPerkGiftBody;

  /// No description provided for @provVipPerkBonusTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thưởng cao hơn'**
  String get provVipPerkBonusTitle;

  /// No description provided for @provVipPerkBonusBody.
  ///
  /// In vi, this message translates to:
  /// **'Hệ số thưởng cao hơn cho cùng một mức thành tích.'**
  String get provVipPerkBonusBody;

  /// No description provided for @provVipWelcome.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng CTV VIP 💎'**
  String get provVipWelcome;

  /// No description provided for @provVipPerksTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặc quyền VIP'**
  String get provVipPerksTitle;

  /// No description provided for @provVipPerksSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Những quyền lợi dành cho CTV hạng Bạch kim.'**
  String get provVipPerksSubtitle;

  /// No description provided for @provVipReqJobs.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành ≥ 800 đơn'**
  String get provVipReqJobs;

  /// No description provided for @provVipReqRating.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đánh giá ≥ 4.85'**
  String get provVipReqRating;

  /// No description provided for @provVipReqCompletion.
  ///
  /// In vi, this message translates to:
  /// **'Duy trì tỉ lệ hoàn thành cao'**
  String get provVipReqCompletion;

  /// No description provided for @provVipReqComplaints.
  ///
  /// In vi, this message translates to:
  /// **'Không có khiếu nại nghiêm trọng'**
  String get provVipReqComplaints;

  /// No description provided for @provVipUnlockTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở khoá đặc quyền VIP'**
  String get provVipUnlockTitle;

  /// No description provided for @provVipUpsellBody.
  ///
  /// In vi, this message translates to:
  /// **'Đạt hạng Bạch kim để nhận toàn bộ quyền lợi VIP. Hạng hiện tại: {tier}.'**
  String provVipUpsellBody(String tier);

  /// No description provided for @provVipReqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Điều kiện lên hạng'**
  String get provVipReqTitle;

  /// No description provided for @provVipBackDashboard.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ CTV'**
  String get provVipBackDashboard;

  /// No description provided for @provVipTierPlatinum.
  ///
  /// In vi, this message translates to:
  /// **'Bạch kim'**
  String get provVipTierPlatinum;

  /// No description provided for @provVipTierGold.
  ///
  /// In vi, this message translates to:
  /// **'Vàng'**
  String get provVipTierGold;

  /// No description provided for @provVipTierSilver.
  ///
  /// In vi, this message translates to:
  /// **'Bạc'**
  String get provVipTierSilver;

  /// No description provided for @provVipTierBronze.
  ///
  /// In vi, this message translates to:
  /// **'Đồng'**
  String get provVipTierBronze;

  /// No description provided for @provFinesPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ'**
  String get provFinesPending;

  /// No description provided for @provFinesDeducted.
  ///
  /// In vi, this message translates to:
  /// **'Đã trừ'**
  String get provFinesDeducted;

  /// No description provided for @provFinesRefunded.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn lại'**
  String get provFinesRefunded;

  /// No description provided for @provFinesHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử phạt'**
  String get provFinesHistory;

  /// No description provided for @provFineAppealAction.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại'**
  String get provFineAppealAction;

  /// No description provided for @provAppealNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy khoản phạt'**
  String get provAppealNotFound;

  /// No description provided for @provAppealYours.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại của bạn'**
  String get provAppealYours;

  /// No description provided for @provAppealStatusLabel.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái: '**
  String get provAppealStatusLabel;

  /// No description provided for @provAppealSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi khiếu nại'**
  String get provAppealSent;

  /// No description provided for @provAppealAlready.
  ///
  /// In vi, this message translates to:
  /// **'Khoản phạt này đã được khiếu nại.'**
  String get provAppealAlready;

  /// No description provided for @provAppealMinChars.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung khiếu nại phải có ít nhất {n} ký tự.'**
  String provAppealMinChars(Object n);

  /// No description provided for @provAppealReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khiếu nại'**
  String get provAppealReasonLabel;

  /// No description provided for @provAppealPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả vì sao bạn cho rằng khoản phạt này chưa hợp lý…'**
  String get provAppealPlaceholder;

  /// No description provided for @provAppealCounter.
  ///
  /// In vi, this message translates to:
  /// **'{n}/{max} ký tự'**
  String provAppealCounter(Object n, Object max);

  /// No description provided for @provAppealSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi khiếu nại'**
  String get provAppealSubmit;

  /// No description provided for @provAppealReviewNote.
  ///
  /// In vi, this message translates to:
  /// **'Đội ngũ Kyco sẽ xem xét khiếu nại của bạn trong thời gian sớm nhất.'**
  String get provAppealReviewNote;

  /// No description provided for @provCancels30d.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ trong 30 ngày'**
  String get provCancels30d;

  /// No description provided for @provCancelsPenaltyPoints.
  ///
  /// In vi, this message translates to:
  /// **'Điểm phạt'**
  String get provCancelsPenaltyPoints;

  /// No description provided for @provCancelsSuspend30Title.
  ///
  /// In vi, this message translates to:
  /// **'Sắp bị tạm khoá 30 ngày'**
  String get provCancelsSuspend30Title;

  /// No description provided for @provCancelsSuspend30Body.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã huỷ {count} lần trong 30 ngày. Đạt {limit} lần sẽ bị tạm khoá 30 ngày.'**
  String provCancelsSuspend30Body(Object count, Object limit);

  /// No description provided for @provCancelsSuspend7Title.
  ///
  /// In vi, this message translates to:
  /// **'Sắp bị tạm khoá 7 ngày'**
  String get provCancelsSuspend7Title;

  /// No description provided for @provCancelsSuspend7Body.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã huỷ {count} lần trong 30 ngày. Đạt {limit} lần sẽ bị tạm khoá 7 ngày.'**
  String provCancelsSuspend7Body(Object count, Object limit);

  /// No description provided for @provCancelsHistory.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử huỷ'**
  String get provCancelsHistory;

  /// No description provided for @provOrderNoNumber.
  ///
  /// In vi, this message translates to:
  /// **'Đơn #—'**
  String get provOrderNoNumber;

  /// No description provided for @provCancelsPoints.
  ///
  /// In vi, this message translates to:
  /// **'+{n} điểm'**
  String provCancelsPoints(Object n);

  /// No description provided for @provReferralsNoCode.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có mã giới thiệu'**
  String get provReferralsNoCode;

  /// No description provided for @provReferralsActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoạt động'**
  String get provReferralsActive;

  /// No description provided for @provReferralsCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get provReferralsCompleted;

  /// No description provided for @provReferralsEarned.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận (≈)'**
  String get provReferralsEarned;

  /// No description provided for @provReferralsApproxNote.
  ///
  /// In vi, this message translates to:
  /// **'* Số tiền đã nhận chỉ mang tính ước tính.'**
  String get provReferralsApproxNote;

  /// No description provided for @provReferralsList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách giới thiệu'**
  String get provReferralsList;

  /// No description provided for @provReferralsShareSubject.
  ///
  /// In vi, this message translates to:
  /// **'Tham gia Kyco với mã của tôi'**
  String get provReferralsShareSubject;

  /// No description provided for @provReferralsYourCode.
  ///
  /// In vi, this message translates to:
  /// **'MÃ GIỚI THIỆU CỦA BẠN'**
  String get provReferralsYourCode;

  /// No description provided for @provReferralsShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get provReferralsShare;

  /// No description provided for @provReferralsColPartner.
  ///
  /// In vi, this message translates to:
  /// **'Đối tác'**
  String get provReferralsColPartner;

  /// No description provided for @provReferralsColArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực'**
  String get provReferralsColArea;

  /// No description provided for @provReferralsColTarget.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ tiêu'**
  String get provReferralsColTarget;

  /// No description provided for @provSupportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ 24/7 — nhắn Zalo, email, hoặc gửi yêu cầu bên dưới.'**
  String get provSupportSubtitle;

  /// No description provided for @provSupportZaloHint.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi trong vài phút'**
  String get provSupportZaloHint;

  /// No description provided for @provSupportEmailHint.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi trong 24 giờ'**
  String get provSupportEmailHint;

  /// No description provided for @provSupportCatWallet.
  ///
  /// In vi, this message translates to:
  /// **'Ví & thanh toán'**
  String get provSupportCatWallet;

  /// No description provided for @provSupportCatTech.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ thuật / ứng dụng'**
  String get provSupportCatTech;

  /// No description provided for @provSupportCatTechShort.
  ///
  /// In vi, this message translates to:
  /// **'Kỹ thuật'**
  String get provSupportCatTechShort;

  /// No description provided for @provSupportCatPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách'**
  String get provSupportCatPolicy;

  /// No description provided for @provSupportCatOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get provSupportCatOther;

  /// No description provided for @provSupportPrioNormal.
  ///
  /// In vi, this message translates to:
  /// **'Bình thường'**
  String get provSupportPrioNormal;

  /// No description provided for @provSupportPrioHigh.
  ///
  /// In vi, this message translates to:
  /// **'Cao'**
  String get provSupportPrioHigh;

  /// No description provided for @provSupportPrioUrgent.
  ///
  /// In vi, this message translates to:
  /// **'Khẩn cấp'**
  String get provSupportPrioUrgent;

  /// No description provided for @provSupportFormTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu hỗ trợ'**
  String get provSupportFormTitle;

  /// No description provided for @provSupportCategoryField.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm'**
  String get provSupportCategoryField;

  /// No description provided for @provSupportPriorityField.
  ///
  /// In vi, this message translates to:
  /// **'Ưu tiên'**
  String get provSupportPriorityField;

  /// No description provided for @provSupportSubjectLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề'**
  String get provSupportSubjectLabel;

  /// No description provided for @provSupportSubjectHint.
  ///
  /// In vi, this message translates to:
  /// **'Tóm tắt ngắn gọn vấn đề'**
  String get provSupportSubjectHint;

  /// No description provided for @provSupportSubjectMin.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu 5 ký tự'**
  String get provSupportSubjectMin;

  /// No description provided for @provSupportBodyLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung'**
  String get provSupportBodyLabel;

  /// No description provided for @provSupportBodyHint.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả chi tiết (tuỳ chọn)'**
  String get provSupportBodyHint;

  /// No description provided for @provSupportSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu'**
  String get provSupportSubmit;

  /// No description provided for @provSupportSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu hỗ trợ.'**
  String get provSupportSent;

  /// No description provided for @provSupportSendError.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được yêu cầu. Vui lòng thử lại.'**
  String get provSupportSendError;

  /// No description provided for @provSupportMyTickets.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu của tôi'**
  String get provSupportMyTickets;

  /// No description provided for @provSupportNoTickets.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu hỗ trợ nào.'**
  String get provSupportNoTickets;

  /// No description provided for @provSupportTicketNumber.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu #{id}'**
  String provSupportTicketNumber(Object id);

  /// No description provided for @provSupportStatusOpen.
  ///
  /// In vi, this message translates to:
  /// **'Đang mở'**
  String get provSupportStatusOpen;

  /// No description provided for @provSupportStatusInProgress.
  ///
  /// In vi, this message translates to:
  /// **'Đang xử lý'**
  String get provSupportStatusInProgress;

  /// No description provided for @provSupportStatusResolved.
  ///
  /// In vi, this message translates to:
  /// **'Đã xử lý'**
  String get provSupportStatusResolved;

  /// No description provided for @provTaskerCityHcm.
  ///
  /// In vi, this message translates to:
  /// **'TP. Hồ Chí Minh'**
  String get provTaskerCityHcm;

  /// No description provided for @provTaskerCityHn.
  ///
  /// In vi, this message translates to:
  /// **'Hà Nội (sắp khai trương)'**
  String get provTaskerCityHn;

  /// No description provided for @provTaskerCityDn.
  ///
  /// In vi, this message translates to:
  /// **'Đà Nẵng (sắp khai trương)'**
  String get provTaskerCityDn;

  /// No description provided for @provTaskerKycFront.
  ///
  /// In vi, this message translates to:
  /// **'CCCD mặt trước'**
  String get provTaskerKycFront;

  /// No description provided for @provTaskerKycBack.
  ///
  /// In vi, this message translates to:
  /// **'CCCD mặt sau'**
  String get provTaskerKycBack;

  /// No description provided for @provTaskerKycSelfie.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh chân dung'**
  String get provTaskerKycSelfie;

  /// No description provided for @provTaskerOtpFormat.
  ///
  /// In vi, this message translates to:
  /// **'Mã OTP gồm 6–8 chữ số.'**
  String get provTaskerOtpFormat;

  /// No description provided for @provTaskerCameraDenied.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được camera. Vui lòng cấp quyền camera trong Cài đặt.'**
  String get provTaskerCameraDenied;

  /// No description provided for @provTaskerNameDistrictRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập họ tên và quận/huyện.'**
  String get provTaskerNameDistrictRequired;

  /// No description provided for @provTaskerNeed3Photos.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chụp đủ 3 ảnh giấy tờ.'**
  String get provTaskerNeed3Photos;

  /// No description provided for @provTaskerPhotoReadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được ảnh. Vui lòng chụp lại.'**
  String get provTaskerPhotoReadFailed;

  /// No description provided for @provTaskerVerifyPhoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh số điện thoại'**
  String get provTaskerVerifyPhoneTitle;

  /// No description provided for @provTaskerSending.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi…'**
  String get provTaskerSending;

  /// No description provided for @provTaskerEnterOtpTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã OTP'**
  String get provTaskerEnterOtpTitle;

  /// No description provided for @provTaskerOtpSentTo.
  ///
  /// In vi, this message translates to:
  /// **'Mã đã gửi tới {phone}'**
  String provTaskerOtpSentTo(String phone);

  /// No description provided for @provTaskerChangePhone.
  ///
  /// In vi, this message translates to:
  /// **'Đổi số điện thoại'**
  String get provTaskerChangePhone;

  /// No description provided for @provTaskerContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get provTaskerContinue;

  /// No description provided for @provTaskerProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin & giấy tờ'**
  String get provTaskerProfileTitle;

  /// No description provided for @provTaskerFullName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get provTaskerFullName;

  /// No description provided for @provTaskerCity.
  ///
  /// In vi, this message translates to:
  /// **'Thành phố'**
  String get provTaskerCity;

  /// No description provided for @provTaskerDistrict.
  ///
  /// In vi, this message translates to:
  /// **'Quận / Huyện'**
  String get provTaskerDistrict;

  /// No description provided for @provTaskerDistrictHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Quận 1'**
  String get provTaskerDistrictHint;

  /// No description provided for @provTaskerReferral.
  ///
  /// In vi, this message translates to:
  /// **'Mã giới thiệu (tuỳ chọn)'**
  String get provTaskerReferral;

  /// No description provided for @provTaskerCaptureDocsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh giấy tờ'**
  String get provTaskerCaptureDocsTitle;

  /// No description provided for @provTaskerSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi hồ sơ'**
  String get provTaskerSubmit;

  /// No description provided for @provTaskerStepPhone.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh SĐT'**
  String get provTaskerStepPhone;

  /// No description provided for @provTaskerStepProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ & KYC'**
  String get provTaskerStepProfile;

  /// No description provided for @provTaskerStepReview.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt hồ sơ'**
  String get provTaskerStepReview;

  /// No description provided for @provTaskerDoneTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi hồ sơ'**
  String get provTaskerDoneTitle;

  /// No description provided for @provTaskerDoneBody.
  ///
  /// In vi, this message translates to:
  /// **'Kyco đã nhận giấy tờ của bạn và sẽ liên hệ để hoàn tất đăng ký.'**
  String get provTaskerDoneBody;

  /// No description provided for @provTaskerBackHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get provTaskerBackHome;

  /// No description provided for @provTaskerNotLiveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sắp ra mắt trên ứng dụng'**
  String get provTaskerNotLiveTitle;

  /// No description provided for @provTaskerNotLiveBody.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký cộng tác viên chưa mở trên ứng dụng, nên hồ sơ chưa được gửi đi. Vui lòng hoàn tất đăng ký tại kyco.vn hoặc email tasker@kyco.vn.'**
  String get provTaskerNotLiveBody;

  /// No description provided for @provTaskerRetake.
  ///
  /// In vi, this message translates to:
  /// **'Chụp lại'**
  String get provTaskerRetake;

  /// No description provided for @provTaskerCapturePhoto.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh'**
  String get provTaskerCapturePhoto;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
