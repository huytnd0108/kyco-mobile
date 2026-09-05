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
