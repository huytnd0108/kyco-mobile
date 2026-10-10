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
  String get providersAvailable => 'Taskers available';

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

  @override
  String get provWorkspace => 'Tasker workspace';

  @override
  String get provComingSoon => 'Coming soon';

  @override
  String get provTabHome => 'Home';

  @override
  String get provTabJobs => 'Jobs';

  @override
  String get provTabWallet => 'Wallet';

  @override
  String get provTabAvailability => 'Availability';

  @override
  String get provTabMore => 'More';

  @override
  String get provHomeTitle => 'Dashboard';

  @override
  String get provJobsTitle => 'Jobs';

  @override
  String get provJobsAssigned => 'Assigned';

  @override
  String get provJobsAvailable => 'Available';

  @override
  String get provWalletTitle => 'My wallet';

  @override
  String get provAvailabilityTitle => 'Availability';

  @override
  String get provMoreTitle => 'More';

  @override
  String get provBonusesTitle => 'Bonuses';

  @override
  String get provGoalsTitle => 'Goals';

  @override
  String get provLeaderboardTitle => 'Leaderboard';

  @override
  String get provFinesTitle => 'Fines';

  @override
  String get provAppealTitle => 'Appeal';

  @override
  String get provCancellationsTitle => 'Cancellations';

  @override
  String get provReferralsTitle => 'Referrals';

  @override
  String get provSupportTitle => 'Support';

  @override
  String get provVipTitle => 'VIP';

  @override
  String get provSwitchToCustomer => 'Switch to customer';

  @override
  String get provSignInRequired => 'Please sign in to continue.';

  @override
  String get provAvailLoadError =>
      'Couldn\'t load your schedule. The server may be unavailable.';

  @override
  String get provAvailWeeklyHeading => 'Weekly schedule';

  @override
  String get provAvailWeeklySub =>
      'Recurring hours you accept jobs. Tap a day to edit.';

  @override
  String get provAvailOverridesHeading => 'Date overrides';

  @override
  String get provAvailOverridesSub =>
      'Replace the schedule for a specific date (holiday, day off…).';

  @override
  String get provAvailAddOverride => 'Add override';

  @override
  String get provAvailFreeHoursTitle => 'Free hours per week';

  @override
  String get provAvailNoSlots => 'Not available';

  @override
  String get provAvailUnavailableFull => 'Off all day';

  @override
  String get provAvailEditDay => 'Edit day';

  @override
  String get provAvailAddSlot => 'Add time slot';

  @override
  String get provAvailStart => 'Start';

  @override
  String get provAvailEnd => 'End';

  @override
  String get provAvailSave => 'Save';

  @override
  String get provAvailCancel => 'Cancel';

  @override
  String get provAvailSaved => 'Schedule saved.';

  @override
  String get provAvailSaveFailed => 'Save failed. Please try again.';

  @override
  String get provAvailPickDate => 'Pick a date';

  @override
  String get provAvailConflictTitle => 'Conflicts with committed jobs';

  @override
  String get provAvailSaveAnyway => 'Save anyway';

  @override
  String get provAvailEmptyOverrides => 'No date overrides yet.';

  @override
  String get provAvailHoursUnit => 'h';

  @override
  String get provAvailSlotOrderError => 'End time must be after start time.';

  @override
  String provAvailConflictBody(String ids) {
    return 'These committed jobs would fall outside your free hours: $ids. Save anyway?';
  }

  @override
  String get provAvailWeekdayShort0 => 'Sun';

  @override
  String get provAvailWeekdayShort1 => 'Mon';

  @override
  String get provAvailWeekdayShort2 => 'Tue';

  @override
  String get provAvailWeekdayShort3 => 'Wed';

  @override
  String get provAvailWeekdayShort4 => 'Thu';

  @override
  String get provAvailWeekdayShort5 => 'Fri';

  @override
  String get provAvailWeekdayShort6 => 'Sat';

  @override
  String get provAvailWeekdayLong0 => 'Sunday';

  @override
  String get provAvailWeekdayLong1 => 'Monday';

  @override
  String get provAvailWeekdayLong2 => 'Tuesday';

  @override
  String get provAvailWeekdayLong3 => 'Wednesday';

  @override
  String get provAvailWeekdayLong4 => 'Thursday';

  @override
  String get provAvailWeekdayLong5 => 'Friday';

  @override
  String get provAvailWeekdayLong6 => 'Saturday';

  @override
  String provAvailHours(int h, int m) {
    String _temp0 = intl.Intl.pluralLogic(
      m,
      locale: localeName,
      other: '${h}h ${m}m',
      zero: '${h}h',
    );
    return '$_temp0';
  }

  @override
  String get provJobStatusPending => 'Pending confirmation';

  @override
  String get provJobStatusActive => 'In progress';

  @override
  String get provJobStatusClosed => 'Closed';

  @override
  String get provJobNetHint => '≈ 80% to you';

  @override
  String provJobNetEstimate(String amount) {
    return '≈ $amount to you';
  }

  @override
  String get provJobsAssignedEmpty => 'No jobs yet';

  @override
  String get provPoolEmpty => 'No jobs available to claim right now';

  @override
  String get provJobsLoadError => 'Couldn\'t load jobs';

  @override
  String get provPoolAvailable => 'Jobs to claim';

  @override
  String get provPoolAssigned => 'Your jobs';

  @override
  String get provClaimAction => 'Claim job';

  @override
  String get provClaimGateTitle => 'You can\'t claim jobs yet';

  @override
  String get provClaimGateBody =>
      'Your account is temporarily restricted from claiming jobs.';

  @override
  String get provClaimSuccess => 'Job claimed';

  @override
  String get provClaimError => 'Couldn\'t claim the job, please try again';

  @override
  String provHomeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get provHomeGreetingPlain => 'Hello';

  @override
  String get provHomeSubtitle =>
      'Manage jobs, track earnings, and make the most of peak hours.';

  @override
  String get provHomeKpi30d => 'KPIs · last 30 days';

  @override
  String get provKpiAcceptanceLabel => 'Acceptance';

  @override
  String get provKpiCompletionLabel => 'Completion';

  @override
  String get provKpiRatingLabel => 'Rating';

  @override
  String get provKpiPunctualityLabel => 'Punctuality';

  @override
  String get provHomeEarningsMonth => 'THIS MONTH\'S EARNINGS';

  @override
  String get provHomeBalance => 'Wallet balance';

  @override
  String get provHomeLifetime => 'Lifetime';

  @override
  String get provHomeStatActive => 'Active';

  @override
  String get provHomeStatTotal => 'Total';

  @override
  String get provHomeToday => 'Today';

  @override
  String get provHomeTodayEmpty =>
      'Nothing scheduled today. Enjoy the break ☕.';

  @override
  String get provHomeUpcoming => 'Upcoming';

  @override
  String get provHomeUpcomingEmpty => 'No upcoming jobs yet.';

  @override
  String get provHomeSeeAll => 'See all →';

  @override
  String get provStatusPending => 'pending';

  @override
  String get provStatusActive => 'active';

  @override
  String get provStatusClosed => 'closed';

  @override
  String get provWalletExportTooltip => 'Export this month (CSV)';

  @override
  String get provWalletTxns => 'Transactions';

  @override
  String get provWalletWithdrawHistory => 'Withdrawal history';

  @override
  String get provWalletPayoutHint =>
      'Funds are held and paid out on Kyco\'s schedule.';

  @override
  String get provWalletAvailableBalance => 'AVAILABLE BALANCE';

  @override
  String get provWalletBalanceSchedule =>
      'Paid out after customer confirmation, to your registered bank account.';

  @override
  String get provWalletTileTotal => 'Total earnings';

  @override
  String get provWalletTileMonth => 'This month';

  @override
  String get provWalletTileJobs => 'Jobs';

  @override
  String get provWalletTileFees => 'Fees deducted';

  @override
  String get provWalletWithdrawTitle => 'Withdraw to bank';

  @override
  String get provWalletWithdrawBody =>
      'Withdrawals require security verification to protect your account.';

  @override
  String provWalletWithdrawMin(String min) {
    return 'A minimum of $min is required to withdraw.';
  }

  @override
  String get provWalletWithdrawAction => 'Withdraw';

  @override
  String provWalletBalanceAfter(String amount) {
    return 'Balance $amount';
  }

  @override
  String get provWalletReasonEarning => 'Job earnings';

  @override
  String get provWalletReasonTip => 'Tip';

  @override
  String get provWalletReasonBonus => 'Bonus';

  @override
  String get provWalletReasonPayout => 'Withdrawal';

  @override
  String get provWalletReasonCommission => 'Commission';

  @override
  String get provWalletReasonClawback => 'Clawback';

  @override
  String get provWalletReasonAdjustment => 'Adjustment';

  @override
  String get provWalletReasonDefault => 'Transaction';

  @override
  String get provWalletPayoutReleased => 'Released';

  @override
  String get provWalletPayoutWithdrawn => 'Withdrawn';

  @override
  String get provWalletPayoutReversed => 'Reversed';

  @override
  String get provWalletPayoutHeld => 'Held';

  @override
  String provWalletWithdrawMinError(String min) {
    return 'The minimum amount is $min.';
  }

  @override
  String provWalletWithdrawMaxError(String max) {
    return 'The maximum per withdrawal is $max.';
  }

  @override
  String provWalletSheetBalance(String amount) {
    return 'Available balance: $amount';
  }

  @override
  String get provWalletAmountLabel => 'Amount (₫)';

  @override
  String provWalletAmountHint(String min, String max) {
    return 'From $min to $max · whole đồng. Kyco verifies and deducts on the server.';
  }

  @override
  String get provWalletContinue => 'Continue';

  @override
  String get provWalletMaintenance => 'Withdrawals are coming soon.';

  @override
  String provWalletWithdrawSubmitted(String amount, String bank, String tail) {
    return 'Withdrawal request for $amount to $bank ••••$tail sent. Kyco transfers within 1-2 business days.';
  }

  @override
  String provWalletWithdrawSubmittedNoBank(String amount) {
    return 'Withdrawal request for $amount recorded. Kyco transfers within 1-2 business days.';
  }

  @override
  String get provWalletWithdrawPending =>
      'A withdrawal is already being processed. Please try again shortly.';

  @override
  String get provWalletWithdrawStepUp =>
      'Security verification is required to withdraw. Please try again.';

  @override
  String get provWalletStepUpTitle => 'Security verification';

  @override
  String get provWalletStepUpPassword =>
      'Enter your password to confirm the withdrawal.';

  @override
  String get provWalletStepUpPhonePrompt =>
      'Enter your registered phone to receive an OTP confirming the withdrawal.';

  @override
  String get provWalletStepUpOtpPrompt =>
      'Enter the OTP just sent to your phone to confirm the withdrawal.';

  @override
  String get provWalletConfirm => 'Confirm';

  @override
  String get provWalletResendSending => 'Resending…';

  @override
  String get provWalletResend => 'Resend code';

  @override
  String get provWalletExportMaintenance => 'CSV export is coming soon.';

  @override
  String get provOtpInvalidPhone => 'Invalid phone number.';

  @override
  String get provOtpRateLimited =>
      'You\'ve requested too many times. Please try again later.';

  @override
  String get provOtpSendFailed => 'Couldn\'t send the OTP. Please try again.';

  @override
  String provOtpSentTo(String phone) {
    return 'OTP sent to $phone.';
  }

  @override
  String get provPhoneLabel => 'Phone number';

  @override
  String get provSendOtp => 'Send OTP';

  @override
  String get provOtpLabel => 'OTP code';

  @override
  String get changePhoneTitle => 'Change phone number';

  @override
  String get changePhonePrompt =>
      'Enter your new phone number. We\'ll send a verification code to it.';

  @override
  String get changePhoneNewLabel => 'New phone number';

  @override
  String get changePhoneCodePrompt =>
      'Enter the 6-digit code sent to your new number.';

  @override
  String get changePhoneSubmit => 'Confirm change';

  @override
  String get changePhoneSuccess => 'Your phone number has been updated.';

  @override
  String get changePhoneConflict => 'This phone number is already in use.';

  @override
  String get changePhoneInvalidCode => 'The verification code is invalid.';

  @override
  String get changePhoneCodeRequired => 'Enter the 6-digit verification code.';

  @override
  String get provJdNotFound => 'Job not found';

  @override
  String get provJdTitle => 'Job detail';

  @override
  String get provJdFeatureEnabling =>
      'This feature is being enabled — please try again shortly.';

  @override
  String get provJdGpsOff => 'Turn on Location services (GPS) to check in.';

  @override
  String get provJdGpsPermNeeded =>
      'Location permission is needed to check in on site.';

  @override
  String get provJdGpsPermOff =>
      'Location permission is off — re-enable it in Settings.';

  @override
  String get provJdGpsFailed => 'Could not get your location — try again.';

  @override
  String get provJdCamPermNeeded =>
      'Camera permission is needed to take job photos.';

  @override
  String get provJdPhotoUploadFailed => 'Photo upload failed — try again.';

  @override
  String get provJdDeclineTitle => 'Decline job';

  @override
  String get provJdDeclineWarning =>
      'Declining after accepting may incur a fine and affect your reliability score. Kyco shows the fine (if any) after you confirm.';

  @override
  String get provJdReasonOptional => 'Reason (optional)';

  @override
  String get provJdDecline => 'Decline';

  @override
  String get provJdDeclined => 'Job declined';

  @override
  String get provJdCancelTitle => 'Cancel job';

  @override
  String get provJdCancelWarning =>
      'Cancelling an accepted job may incur a policy fine. Kyco computes and shows the amount after you confirm.';

  @override
  String get provJdCancelReason => 'Cancellation reason';

  @override
  String get provJdCancelJob => 'Cancel job';

  @override
  String get provJdCancelled => 'Job cancelled';

  @override
  String get provJdEnRouteSnack => 'You are now en route';

  @override
  String get provJdCheckedOutSnack =>
      'Checked out. The booking moved to customer confirmation & payment.';

  @override
  String get provJdPhotoUploaded => 'Photo uploaded';

  @override
  String get provJdFaceSubmitted => 'Face verification submitted';

  @override
  String get provJdMarkedComplete => 'Job marked complete';

  @override
  String get provJdCashConfirmTitle => 'Confirm cash received';

  @override
  String get provJdCashConfirmBody =>
      'Kyco charges a 20% commission on this cash order. Confirm you received the full amount from the customer?';

  @override
  String get provJdCashReceived => 'Cash received';

  @override
  String get provJdComplaintTitle => 'File a complaint';

  @override
  String get provJdComplaintBody =>
      'Describe the problem with this job. Kyco support will review it.';

  @override
  String get provJdComplaintHint => 'What happened';

  @override
  String get provJdSend => 'Send';

  @override
  String get provJdComplaintSent => 'Complaint sent';

  @override
  String get provJdSosBody =>
      'Send an emergency alert to Kyco for this job? The safety team will contact you immediately.';

  @override
  String get provJdSosConfirm => 'Send SOS';

  @override
  String get provJdSosSent => 'SOS sent. Kyco safety will contact you now.';

  @override
  String get provJdCheckedIn => 'Checked in';

  @override
  String get provJdWithinGeofence => 'within site geofence';

  @override
  String provJdMetersAway(Object m) {
    return '~${m}m away';
  }

  @override
  String provJdMinLate(Object n) {
    return '$n min late';
  }

  @override
  String get provJdLateFineTitle => 'Late fine';

  @override
  String provJdLateFineBody(String amount) {
    return 'Kyco recorded a late fine: $amount. This amount is system-computed.';
  }

  @override
  String get provJdFineTitle => 'Fine applied';

  @override
  String provJdFineBody(String amount) {
    return 'Kyco applied a fine: $amount. This amount is system-computed and final.';
  }

  @override
  String get provJdCashRecorded => 'Cash recorded';

  @override
  String get provJdCashRecordedBody =>
      'Kyco charged the 20% commission on this order. The figures below are system-computed:';

  @override
  String get provJdSeeWallet => 'See your wallet for details.';

  @override
  String get provJdClose => 'Close';

  @override
  String get provJdDialogCancel => 'Cancel';

  @override
  String provJdNeedMore(Object missing) {
    return 'need $missing more';
  }

  @override
  String get provJdCompleteTitle => 'Complete job';

  @override
  String get provJdCompleteGateBody =>
      'Enough before/mid/after photos are required to complete:';

  @override
  String get provJdBefore => 'Before';

  @override
  String get provJdMid => 'Mid';

  @override
  String get provJdAfter => 'After';

  @override
  String get provJdMarkComplete => 'Mark complete';

  @override
  String get provJdReportProblem => 'Report a problem with this job';

  @override
  String get provJdPhasePending => 'Awaiting your confirmation';

  @override
  String get provJdPhaseEnRoute => 'Ready to head out';

  @override
  String get provJdPhaseOnSite => 'On site — in service';

  @override
  String get provJdPhaseWrapUp => 'Wrap up & mark complete';

  @override
  String get provJdPhaseAwaitingCustomer =>
      'Awaiting customer confirmation (auto in 2h)';

  @override
  String get provJdPhaseAwaitingCash => 'Awaiting cash confirmation';

  @override
  String get provJdPhaseAwaitingPayment => 'Customer is paying';

  @override
  String get provJdPhaseSettled => 'Settled';

  @override
  String get provJdPhaseClosed => 'Closed';

  @override
  String get provJdPhaseCancelled => 'Cancelled';

  @override
  String get provJdPhaseUnknown => 'Job status';

  @override
  String get provJdOrderInfo => 'Order info';

  @override
  String get provJdCustomer => 'Customer';

  @override
  String get provJdTime => 'Time';

  @override
  String get provJdDuration => 'Duration';

  @override
  String get provJdAddress => 'Address';

  @override
  String get provJdPayment => 'Payment';

  @override
  String get provJdYourEarnings => 'Your earnings';

  @override
  String get provJdAmountsComputed =>
      'Amounts are computed and shown by Kyco — the app never calculates them.';

  @override
  String get provJdPayCash => 'Cash';

  @override
  String get provJdPayBankTransfer => 'Bank transfer';

  @override
  String get provJdConfirmAccept => 'Confirm & accept';

  @override
  String get provJdStartTracking => 'Start heading out (GPS)';

  @override
  String get provJdCheckIn => 'Check in on site (GPS)';

  @override
  String provJdBeforePhotoGate(Object need, Object have) {
    return 'Need ≥ $need \"before\" photos to check out (have $have/$need). Capture in the photo box below.';
  }

  @override
  String get provJdFaceVerify => 'Face verify';

  @override
  String get provJdCheckOut => 'Check out (GPS)';

  @override
  String get provJdCashReceivedAction => '✅ Cash received from customer';

  @override
  String get provJdCashCommissionNote =>
      'Kyco charges a 20% commission on this cash order (system-computed).';

  @override
  String get provJdAwaitingCustomerInfo =>
      '⏳ Awaiting customer confirmation (auto-confirms in 2h).';

  @override
  String get provJdAwaitingPaymentInfo =>
      '⏳ Customer is paying — Kyco transfers 80% on confirmation.';

  @override
  String get provJdClosedInfo => '🔒 This job is closed. No further actions.';

  @override
  String get provJdCancelledInfo => 'This job was cancelled.';

  @override
  String get provJdNoActions => 'No actions available.';

  @override
  String get provJdLifecycle => 'Job lifecycle';

  @override
  String provJdPhotosRequired(Object total, Object req) {
    return 'Photos required to complete ($total/$req)';
  }

  @override
  String get provJdSettledThanks =>
      '✅ Kyco has paid you 80% of the booking total. Thank you for working with us!';

  @override
  String get provJdJobPhotos => 'Job photos (camera)';

  @override
  String get provJdCapture => 'Capture';

  @override
  String get provJdSafety => 'Safety';

  @override
  String get provJdSendSos => 'Send emergency SOS';

  @override
  String get provJdShareLocation => '📍 Share location with the customer';

  @override
  String get provJdShareLiveTitle => 'Share my live location — coming soon';

  @override
  String get provJdShareLiveBody =>
      'This feature is in development. The customer cannot see your location yet.';

  @override
  String get provJdChatTitle => 'Chat with the customer';

  @override
  String get provJdChatEmpty => 'No messages yet.';

  @override
  String get provJdChatHint => 'Type a message…';

  @override
  String get provJdCommission20 => 'Commission (20%)';

  @override
  String get provJdWalletBalance => 'Wallet balance';

  @override
  String get provJdOrderTotal => 'Order total';

  @override
  String get provJdFine => 'Fine';

  @override
  String get provBonusesWeekTitle => 'This week\'s bonuses';

  @override
  String get provBonusesMonthTitle => 'This month\'s bonuses';

  @override
  String get provBonusesHistoryTitle => 'Bonus history';

  @override
  String get provBonusesHistoryEmpty => 'No bonuses have been paid yet.';

  @override
  String get provBonusesNone => 'No bonuses available.';

  @override
  String get provBonusEarned => 'Earned';

  @override
  String get provBonusMax => 'Max';

  @override
  String get provBonusNotEarned => 'Not earned';

  @override
  String get provBonusKindWeeklyJobs => '🏆 Weekly bonus (jobs)';

  @override
  String get provBonusKindMonthlyRevenue => '🏅 Monthly bonus (revenue)';

  @override
  String get provBonusKindPunctuality => '📅 Punctuality bonus';

  @override
  String get provBonusKindRating => '⭐ High-rating bonus';

  @override
  String get provBonusKindReferral => '👥 Referral bonus';

  @override
  String get provGoalsThisWeek => 'This week';

  @override
  String get provGoalsThisMonth => 'This month';

  @override
  String get provGoalJobs => 'Jobs';

  @override
  String get provGoalIncome => 'Income';

  @override
  String get provGoalSet => 'Set goal';

  @override
  String get provGoalEdit => 'Edit goal';

  @override
  String get provGoalSaved => 'Goal saved';

  @override
  String get provGoalTitle => 'Goal';

  @override
  String get provGoalTargetJobs => 'Target jobs';

  @override
  String get provGoalTargetIncome => 'Target income (₫)';

  @override
  String get provGoalSave => 'Save';

  @override
  String get provGoalCancel => 'Cancel';

  @override
  String provLbYourRank(Object n) {
    return 'Your rank: #$n';
  }

  @override
  String get provLbEmpty => 'No leaderboard data yet.';

  @override
  String get provLbWeek => 'Week';

  @override
  String get provLbMonth => 'Month';

  @override
  String get provLbNationwide => 'Nationwide';

  @override
  String get provLbYou => 'You';

  @override
  String provLbJobs(Object n) {
    return '$n jobs';
  }

  @override
  String get provVipPerkPriorityTitle => 'Priority job assignment';

  @override
  String get provVipPerkPriorityBody =>
      'Get high-value jobs assigned to you before other partners.';

  @override
  String get provVipPerkAreaTitle => 'Expanded coverage';

  @override
  String get provVipPerkAreaBody =>
      'Take jobs across more districts to maximize earnings.';

  @override
  String get provVipPerkSupportTitle => 'Dedicated VIP support';

  @override
  String get provVipPerkSupportBody =>
      'A dedicated support line 1900-VIP-XX, fast 24/7 response.';

  @override
  String get provVipPerkBadgeTitle => 'VIP badge';

  @override
  String get provVipPerkBadgeBody =>
      'Show a Platinum badge to customers to boost trust.';

  @override
  String get provVipPerkGiftTitle => 'Gifts & perks';

  @override
  String get provVipPerkGiftBody =>
      'Receive thank-you gifts and exclusive VIP-only offers.';

  @override
  String get provVipPerkBonusTitle => 'Higher bonuses';

  @override
  String get provVipPerkBonusBody =>
      'A higher bonus multiplier for the same performance.';

  @override
  String get provVipWelcome => 'Welcome, VIP partner 💎';

  @override
  String get provVipPerksTitle => 'VIP perks';

  @override
  String get provVipPerksSubtitle => 'Benefits for Platinum-tier partners.';

  @override
  String get provVipReqJobs => 'Complete ≥ 800 jobs';

  @override
  String get provVipReqRating => 'Rating ≥ 4.85';

  @override
  String get provVipReqCompletion => 'Maintain a high completion rate';

  @override
  String get provVipReqComplaints => 'No serious complaints';

  @override
  String get provVipUnlockTitle => 'Unlock VIP';

  @override
  String provVipUpsellBody(String tier) {
    return 'Reach Platinum to unlock all VIP benefits. Current tier: $tier.';
  }

  @override
  String get provVipReqTitle => 'Requirements';

  @override
  String get provVipBackDashboard => 'Back to dashboard';

  @override
  String get provVipTierPlatinum => 'Platinum';

  @override
  String get provVipTierGold => 'Gold';

  @override
  String get provVipTierSilver => 'Silver';

  @override
  String get provVipTierBronze => 'Bronze';

  @override
  String get provFinesPending => 'Pending';

  @override
  String get provFinesDeducted => 'Deducted';

  @override
  String get provFinesRefunded => 'Refunded';

  @override
  String get provFinesHistory => 'Fine history';

  @override
  String get provFineAppealAction => 'Appeal';

  @override
  String get provAppealNotFound => 'Fine not found';

  @override
  String get provAppealYours => 'Your appeal';

  @override
  String get provAppealStatusLabel => 'Status: ';

  @override
  String get provAppealSent => 'Appeal submitted';

  @override
  String get provAppealAlready => 'This fine has already been appealed.';

  @override
  String provAppealMinChars(Object n) {
    return 'Your appeal must be at least $n characters.';
  }

  @override
  String get provAppealReasonLabel => 'Reason for appeal';

  @override
  String get provAppealPlaceholder =>
      'Explain why you think this fine is unfair…';

  @override
  String provAppealCounter(Object n, Object max) {
    return '$n/$max characters';
  }

  @override
  String get provAppealSubmit => 'Submit appeal';

  @override
  String get provAppealReviewNote =>
      'The Kyco team will review your appeal as soon as possible.';

  @override
  String get provCancels30d => 'Cancellations in 30 days';

  @override
  String get provCancelsPenaltyPoints => 'Penalty points';

  @override
  String get provCancelsSuspend30Title => 'Approaching a 30-day suspension';

  @override
  String provCancelsSuspend30Body(Object count, Object limit) {
    return 'You\'ve cancelled $count times in 30 days. Reaching $limit triggers a 30-day suspension.';
  }

  @override
  String get provCancelsSuspend7Title => 'Approaching a 7-day suspension';

  @override
  String provCancelsSuspend7Body(Object count, Object limit) {
    return 'You\'ve cancelled $count times in 30 days. Reaching $limit triggers a 7-day suspension.';
  }

  @override
  String get provCancelsHistory => 'Cancellation history';

  @override
  String get provOrderNoNumber => 'Booking #—';

  @override
  String provCancelsPoints(Object n) {
    return '+$n pts';
  }

  @override
  String get provReferralsNoCode => 'No referral code yet';

  @override
  String get provReferralsActive => 'Active';

  @override
  String get provReferralsCompleted => 'Completed';

  @override
  String get provReferralsEarned => 'Earned (≈)';

  @override
  String get provReferralsApproxNote => '* Earned amounts are estimates only.';

  @override
  String get provReferralsList => 'Referrals';

  @override
  String get provReferralsShareSubject => 'Join Kyco with my code';

  @override
  String get provReferralsYourCode => 'YOUR REFERRAL CODE';

  @override
  String get provReferralsShare => 'Share';

  @override
  String get provReferralsColPartner => 'Partner';

  @override
  String get provReferralsColArea => 'Area';

  @override
  String get provReferralsColTarget => 'Target';

  @override
  String get provSupportSubtitle =>
      'Support 24/7 — message us on Zalo, email, or submit a request below.';

  @override
  String get provSupportZaloHint => 'Replies within minutes';

  @override
  String get provSupportEmailHint => 'Replies within 24 hours';

  @override
  String get provSupportCatWallet => 'Wallet & payments';

  @override
  String get provSupportCatTech => 'Technical / app';

  @override
  String get provSupportCatTechShort => 'Technical';

  @override
  String get provSupportCatPolicy => 'Policy';

  @override
  String get provSupportCatOther => 'Other';

  @override
  String get provSupportPrioNormal => 'Normal';

  @override
  String get provSupportPrioHigh => 'High';

  @override
  String get provSupportPrioUrgent => 'Urgent';

  @override
  String get provSupportFormTitle => 'Submit a support request';

  @override
  String get provSupportCategoryField => 'Category';

  @override
  String get provSupportPriorityField => 'Priority';

  @override
  String get provSupportSubjectLabel => 'Subject';

  @override
  String get provSupportSubjectHint => 'Briefly summarize the issue';

  @override
  String get provSupportSubjectMin => 'At least 5 characters';

  @override
  String get provSupportBodyLabel => 'Details';

  @override
  String get provSupportBodyHint => 'Describe in detail (optional)';

  @override
  String get provSupportSubmit => 'Submit request';

  @override
  String get provSupportSent => 'Support request sent.';

  @override
  String get provSupportSendError =>
      'Couldn\'t send the request. Please try again.';

  @override
  String get provSupportMyTickets => 'My requests';

  @override
  String get provSupportNoTickets => 'No support requests yet.';

  @override
  String provSupportTicketNumber(Object id) {
    return 'Request #$id';
  }

  @override
  String get provSupportStatusOpen => 'Open';

  @override
  String get provSupportStatusInProgress => 'In progress';

  @override
  String get provSupportStatusResolved => 'Resolved';

  @override
  String get provTaskerCityHcm => 'Ho Chi Minh City';

  @override
  String get provTaskerCityHn => 'Hanoi (coming soon)';

  @override
  String get provTaskerCityDn => 'Da Nang (coming soon)';

  @override
  String get provTaskerKycFront => 'ID card front';

  @override
  String get provTaskerKycBack => 'ID card back';

  @override
  String get provTaskerKycSelfie => 'Selfie';

  @override
  String get provTaskerOtpFormat => 'The OTP must be 6–8 digits.';

  @override
  String get provTaskerCameraDenied =>
      'Couldn\'t open the camera. Please grant camera permission in Settings.';

  @override
  String get provTaskerNameDistrictRequired =>
      'Please enter your full name and district.';

  @override
  String get provTaskerNeed3Photos => 'Please capture all 3 document photos.';

  @override
  String get provTaskerPhotoReadFailed =>
      'Couldn\'t read the photo. Please retake it.';

  @override
  String get provTaskerVerifyPhoneTitle => 'Verify your phone';

  @override
  String get provTaskerSending => 'Sending…';

  @override
  String get provTaskerEnterOtpTitle => 'Enter the OTP';

  @override
  String provTaskerOtpSentTo(String phone) {
    return 'Code sent to $phone';
  }

  @override
  String get provTaskerChangePhone => 'Change phone';

  @override
  String get provTaskerContinue => 'Continue';

  @override
  String get provTaskerProfileTitle => 'Details & documents';

  @override
  String get provTaskerFullName => 'Full name';

  @override
  String get provTaskerCity => 'City';

  @override
  String get provTaskerDistrict => 'District';

  @override
  String get provTaskerDistrictHint => 'e.g. District 1';

  @override
  String get provTaskerReferral => 'Referral code (optional)';

  @override
  String get provTaskerCaptureDocsTitle => 'Capture your documents';

  @override
  String get provTaskerSubmit => 'Submit application';

  @override
  String get provTaskerStepPhone => 'Verify phone';

  @override
  String get provTaskerStepProfile => 'Profile & KYC';

  @override
  String get provTaskerStepReview => 'Review';

  @override
  String get provTaskerDoneTitle => 'Documents submitted';

  @override
  String get provTaskerDoneBody =>
      'We have received your documents and will contact you to finish signing up.';

  @override
  String get provTaskerBackHome => 'Home';

  @override
  String get provTaskerNotLiveTitle => 'Coming soon in the app';

  @override
  String get provTaskerNotLiveBody =>
      'Partner registration isn\'t live in the app yet, so your details were not submitted. Please finish signing up at kyco.vn or email tasker@kyco.vn.';

  @override
  String get provTaskerRetake => 'Retake';

  @override
  String get provTaskerCapturePhoto => 'Take photo';

  @override
  String get cust2ErrNetwork =>
      'No network connection. Please check your connection and try again.';

  @override
  String get cust2ErrRateLimit =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get cust2ErrMaintenance =>
      'The service is under maintenance. Please try again later.';

  @override
  String get cust2ErrSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get cust2ErrForbidden => 'You don\'t have permission to do this.';

  @override
  String get cust2ErrNotFound => 'We couldn\'t find what you were looking for.';

  @override
  String get cust2ErrValidation =>
      'Some information is invalid. Please check and try again.';

  @override
  String get cust2ErrServer =>
      'The server ran into a problem. Please try again later.';

  @override
  String get cust2ErrConflict => 'This action isn\'t possible right now.';

  @override
  String get cust2ErrTotpRequired =>
      'Two-factor authentication is on. Enter the code from your authenticator app.';

  @override
  String get cust2ErrTotpInvalid =>
      'The two-factor code is incorrect or expired.';

  @override
  String get cust2ErrLoginInvalid => 'Incorrect email or password.';

  @override
  String get cust2ErrOtpLoginInvalid =>
      'The code is wrong or expired, or the phone number isn\'t verified.';

  @override
  String cust2BookingsLoadFailed(String reason) {
    return 'Couldn\'t load bookings.\n$reason';
  }

  @override
  String get cust2LoginModeEmail => 'Email';

  @override
  String get cust2LoginModePhone => 'Phone';

  @override
  String get cust2PhoneLabel => 'Phone number';

  @override
  String get cust2PhoneInvalid => 'Invalid phone number.';

  @override
  String get cust2SendCode => 'Send code';

  @override
  String get cust2ResendCode => 'Resend code';

  @override
  String get cust2OtpLabel => 'Verification code';

  @override
  String get cust2OtpFormat => 'The code has 4–8 digits.';

  @override
  String cust2OtpSent(String phone) {
    return 'Code sent to $phone.';
  }

  @override
  String get cust2TotpLabel => 'Two-factor code';

  @override
  String get cust2StatusEnRoute => 'On the way';

  @override
  String get cust2StatusArrived => 'Arrived';

  @override
  String get cust2StatusCheckedIn => 'Checked in';

  @override
  String get cust2StatusActive => 'In progress';

  @override
  String get cust2StatusAwaitingConfirmation => 'Awaiting your confirmation';

  @override
  String get cust2StatusAwaitingPayment => 'Awaiting payment';

  @override
  String get cust2StatusAwaitingCashConfirm => 'Awaiting cash confirmation';

  @override
  String get cust2StatusClosed => 'Closed';

  @override
  String get cust2StatusInDispute => 'In dispute';

  @override
  String get cust2DetailScheduled => 'Scheduled';

  @override
  String get cust2DetailAddress => 'Address';

  @override
  String get cust2DetailNotes => 'Notes';

  @override
  String get cust2DetailPayment => 'Payment';

  @override
  String get cust2DetailCode => 'Confirmation code';

  @override
  String get cust2DetailProvider => 'Tasker';

  @override
  String get cust2DetailTimeline => 'Timeline';

  @override
  String get cust2PayCash => 'Cash';

  @override
  String get cust2TlCreated => 'Booked';

  @override
  String get cust2TlScheduled => 'Scheduled for';

  @override
  String get cust2TlClaimed => 'Tasker accepted';

  @override
  String get cust2TlStarted => 'Work started';

  @override
  String get cust2TlFinished => 'Tasker finished';

  @override
  String get cust2TlCompleted => 'Completed';

  @override
  String get cust2TlCustomerConfirmed => 'You confirmed';

  @override
  String get cust2TlCashReceived => 'Cash received';

  @override
  String get cust2TlSettled => 'Settled';

  @override
  String get cust2ReviewCta => 'Rate this service';

  @override
  String get cust2ReviewComment => 'Comment (optional)';

  @override
  String get cust2ReviewSubmit => 'Submit review';

  @override
  String get cust2ReviewThanks => 'Thanks for your review!';

  @override
  String get cust2ReviewDone => 'You\'ve reviewed this booking.';

  @override
  String get cust2RatingRequired => 'Please pick a rating.';

  @override
  String cust2RatingStar(String n) {
    return '$n stars';
  }

  @override
  String get cust2InviteYourCode => 'Your invite code';

  @override
  String get cust2InviteBody => 'Share this code so friends can join Kyco.';

  @override
  String get cust2InviteCopy => 'Copy';

  @override
  String get cust2InviteCopied => 'Invite code copied';

  @override
  String get cust2InvitePending => 'Pending';

  @override
  String get cust2InviteSignedUp => 'Signed up';

  @override
  String get cust2HelpEmpty => 'No FAQs yet.';

  @override
  String get cust2DocUnavailable =>
      'This content isn\'t available in the app yet.';

  @override
  String get cust2Addresses => 'Saved addresses';

  @override
  String get cust2AddressAdd => 'Add address';

  @override
  String get cust2AddressEdit => 'Edit address';

  @override
  String get cust2AddressLabel => 'Label (e.g. Home, Work)';

  @override
  String get cust2AddressLine => 'Street address';

  @override
  String get cust2AddressWard => 'Ward';

  @override
  String get cust2AddressDistrict => 'District';

  @override
  String get cust2AddressCity => 'City / Province';

  @override
  String get cust2AddressDefault => 'Set as default address';

  @override
  String get cust2AddressDefaultBadge => 'Default';

  @override
  String get cust2AddressDelete => 'Delete';

  @override
  String get cust2AddressDeleteConfirm => 'Delete this address?';

  @override
  String get cust2AddressEmpty => 'You have no saved addresses.';

  @override
  String get cust2Save => 'Save';

  @override
  String get cust2Cancel => 'Cancel';

  @override
  String get cust2Required => 'Required';

  @override
  String get cust2Saved => 'Saved';

  @override
  String cust2LoadFailed(String reason) {
    return 'Couldn\'t load this page.\n$reason';
  }

  @override
  String prov2StepUpOtpTo(String phone) {
    return 'The OTP will be sent to your account\'s verified phone: $phone';
  }

  @override
  String get prov2StepUpNoVerifiedPhone =>
      'Your account has no verified phone number. Verify it under Account, then try again.';

  @override
  String get prov2StepUpPhoneLoadFailed =>
      'Couldn\'t load your account details, please try again.';

  @override
  String get prov2TaskerNationalId => 'National ID number (optional)';

  @override
  String prov2TaskerPartialUpload(String kinds) {
    return 'Not uploaded: $kinds. Please retake and submit again.';
  }

  @override
  String get prov2TaskerSubmitFailed =>
      'Couldn\'t submit your application, please try again.';

  @override
  String get prov2TaskerOtpInvalid =>
      'The OTP is wrong or has expired. Please check it.';

  @override
  String get prov2LiveShareTitle => 'Share live location';

  @override
  String get prov2LiveShareOff =>
      'Turn on so the customer can see you on the way. Only sent while this screen is open.';

  @override
  String prov2LiveShareOn(String time) {
    return 'Sharing location · updated $time';
  }

  @override
  String get prov2LiveShareStarting => 'Getting your location…';

  @override
  String get prov2LiveShareNotEnRoute =>
      'You can only share while heading to the customer (before check-in).';

  @override
  String get prov2LiveShareStopped => 'Location sharing stopped.';

  @override
  String get prov2ResubmitTitle => 'Customer hasn\'t accepted completion';

  @override
  String get prov2ResubmitBody =>
      'The customer pushed back on the job. Review it (add photos if needed), then resubmit completion.';

  @override
  String prov2ResubmitNote(String note) {
    return 'Customer\'s note: $note';
  }

  @override
  String get prov2ResubmitAction => 'Resubmit completion';

  @override
  String get prov2ResubmitDone =>
      'Resubmitted — the customer will be reminded to confirm.';

  @override
  String get prov2ComplaintNeedsText =>
      'Please describe the complaint (at least 20 characters).';

  @override
  String provPoolDistanceKm(String km) {
    return '~$km km';
  }

  @override
  String get provPoolAddressAfterClaim =>
      'The exact address and customer notes appear after you claim the job.';
}
