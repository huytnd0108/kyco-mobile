// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kyco';

  @override
  String get login => 'Sign in';

  @override
  String get signup => 'Sign up';

  @override
  String get logout => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get emailInvalid => 'Invalid email address';

  @override
  String get password => 'Password';

  @override
  String get passwordMin8 => 'At least 8 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get fullName => 'Full name';

  @override
  String get createAccount => 'Create account';

  @override
  String get noAccountSignup => 'No account? Sign up';

  @override
  String get haveAccountLogin => 'Have an account? Sign in';

  @override
  String get browseWithoutLogin => 'Browse services (no sign-in needed)';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String helloGreeting(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get homeTagline => 'Home cleaning services';

  @override
  String get noServicesYet => 'No services yet — coming soon.';

  @override
  String homeLoadError(String error) {
    return 'Couldn\'t load the home page.\n$error';
  }

  @override
  String get myBookings => 'My bookings';

  @override
  String bookingsLoadError(String error) {
    return 'Couldn\'t load bookings.\n$error';
  }

  @override
  String get noBookingsYet => 'No bookings yet.';

  @override
  String bookingNumber(Object id) {
    return 'Booking #$id';
  }

  @override
  String get bookingDetailTitle => 'Booking details';

  @override
  String get selectBookingPlaceholder => 'Select a booking to see details';

  @override
  String bookingNotFound(Object id) {
    return 'Booking #$id not found';
  }

  @override
  String get statusLabel => 'Status';

  @override
  String get totalLabel => 'Total';

  @override
  String get createdLabel => 'Created';

  @override
  String get serviceLabel => 'Service';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusSettled => 'Settled';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusBadDebt => 'Bad debt';

  @override
  String get navHome => 'Home';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navAccount => 'Account';

  @override
  String get accountTitle => 'Account';

  @override
  String get myAccount => 'My account';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get langVi => 'Tiếng Việt';

  @override
  String get langEn => 'English';

  @override
  String get signInPrompt => 'Sign in to see your bookings and account';

  @override
  String pageNotFound(Object uri) {
    return 'Page not found: $uri';
  }

  @override
  String get navServices => 'Services';

  @override
  String get navMessages => 'Messages';

  @override
  String get bookNow => 'Book now';

  @override
  String get bookNowKicker => 'Fast booking';

  @override
  String get servicesTitle => 'Services';

  @override
  String get searchHint => 'Search services…';

  @override
  String get allCategories => 'All';

  @override
  String get viewDetails => 'View details';

  @override
  String get viewAll => 'View all';

  @override
  String fromPrice(String price) {
    return 'from $price';
  }

  @override
  String minutesShort(int n) {
    return '$n min';
  }

  @override
  String get noResults => 'No results';

  @override
  String get popularCategories => 'Popular categories';

  @override
  String get howItWorks => 'How it works';

  @override
  String get whyKyco => 'Why Kyco';

  @override
  String get exploreServices => 'Explore services';

  @override
  String get relatedServices => 'Related services';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String reviewCount(int n) {
    return '$n reviews';
  }

  @override
  String get providersAvailable => 'Providers available';

  @override
  String get checkoutTitle => 'Book service';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get wardLabel => 'Ward';

  @override
  String get neighborhoodLabel => 'Neighborhood';

  @override
  String get addressLineLabel => 'Street address';

  @override
  String get notesLabel => 'Notes';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String get confirmBooking => 'Confirm booking';

  @override
  String get signInToConfirm => 'Sign in to confirm';

  @override
  String get guestCheckoutNotice =>
      'You can fill everything now — sign in only to confirm.';

  @override
  String get draftRestored => 'Draft restored';

  @override
  String get deferredPaymentNotice => 'Pay after the service — cash.';

  @override
  String bookingCreated(Object id) {
    return 'Booking #$id confirmed';
  }

  @override
  String get step1Category => '1. Pick a category';

  @override
  String get step2Service => '2. Pick a service';

  @override
  String get locationsTitle => 'Service areas';

  @override
  String cityServices(String city) {
    return 'Services in $city';
  }

  @override
  String get providerTitle => 'Partner profile';

  @override
  String get verifiedBadge => 'Verified';

  @override
  String jobsCompleted(int n) {
    return '$n jobs';
  }

  @override
  String memberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String perMonth(String price) {
    return '$price/month';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get signInToView => 'Sign in to view';

  @override
  String get inviteFriends => 'Invite friends';

  @override
  String get becomePartner => 'Become a partner';

  @override
  String get contactUs => 'Contact';

  @override
  String get aboutKyco => 'About Kyco';

  @override
  String get faqs => 'FAQs';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get loadMore => 'Load more';

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String get noDescription => 'No description';

  @override
  String get serviceNotFound => 'Service not found';

  @override
  String get partnerNotFound => 'Partner not found';

  @override
  String get noNotifications => 'No notifications';

  @override
  String wardsCount(Object count) {
    return '$count wards';
  }

  @override
  String get completeRequiredFields => 'Please complete the required fields';

  @override
  String get confirmationCode => 'Confirmation code';

  @override
  String get mySubscriptions => 'My subscriptions';

  @override
  String get plansTitle => 'Plans';

  @override
  String monthsCount(Object count) {
    return '$count months';
  }

  @override
  String get noActiveSubscriptions => 'No active subscriptions';

  @override
  String sessionsProgress(Object done, Object total) {
    return 'Sessions $done/$total';
  }

  @override
  String nextChargeLabel(Object date) {
    return 'Next charge: $date';
  }

  @override
  String get manageOnWeb => 'Create or change a plan on kyco.vn';
}
