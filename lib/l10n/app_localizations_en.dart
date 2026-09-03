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
}
