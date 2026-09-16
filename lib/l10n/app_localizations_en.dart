// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginDescription =>
      'Sign in to continue managing your cheese factory.';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get loginButton => 'Sign In';

  @override
  String get loginDivider => 'or continue with';

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get signUpLink => 'Sign up';

  @override
  String get invalidEmailError => 'Please enter a valid email';

  @override
  String get invalidPasswordError => 'Minimum 6 characters required';

  @override
  String get genericAuthError => 'Authentication error';

  @override
  String get forgotPasswordInstructions =>
      'Don\'t worry, enter your email and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordGenericError => 'Error sending email';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String get checkEmailDescription =>
      'We\'ve sent you a link so you can create a new password safely.';

  @override
  String get rememberedPassword => 'Remembered your password?';

  @override
  String get sendResetLinkButton => 'Send link';

  @override
  String get splashLoadingMessage => 'Preparing your creamery...';

  @override
  String get logoutTooltip => 'Log out';

  @override
  String get navHome => 'Home';

  @override
  String get orgDataItem => 'Organization data';

  @override
  String get orgUsersItem => 'Users';

  @override
  String get orgName => 'My cheese factory';

  @override
  String get adminRole => 'Administrator';

  @override
  String get menuSectionOperations => 'Operations';

  @override
  String get menuSectionDirectory => 'Directory';

  @override
  String get menuSectionFinances => 'Finances';

  @override
  String get menuSectionSettings => 'Settings';

  @override
  String get navToday => 'Today';

  @override
  String get kpiLitersReceived => 'liters received';

  @override
  String get kpiReceptions => 'receptions';

  @override
  String get kpiPendingBalance => 'pending balance';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get quickNewReception => 'New reception';

  @override
  String get quickNewSale => 'New sale';

  @override
  String get quickProducers => 'Producers';

  @override
  String get quickSettlements => 'Settlements';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get noActivity => 'No activity yet';

  @override
  String get noActivityHint => 'The day\'s operations appear here';

  @override
  String get kpiLitersValue => '0 L';

  @override
  String get kpiReceptionsValue => '0';

  @override
  String get kpiBalanceValue => '\$0';

  @override
  String get moduleReception => 'Milk reception';

  @override
  String get moduleProduction => 'Production';

  @override
  String get modulePurchases => 'Purchases';

  @override
  String get moduleOrders => 'Orders';

  @override
  String get moduleSales => 'Sales';

  @override
  String get moduleProducers => 'Producers';

  @override
  String get moduleCollectors => 'Collectors and routes';

  @override
  String get moduleProducts => 'Products';

  @override
  String get moduleSupplies => 'Supplies and inventory';

  @override
  String get moduleSuppliers => 'Suppliers';

  @override
  String get moduleClients => 'Clients';

  @override
  String get moduleTools => 'Tools and equipment';

  @override
  String get moduleSettlements => 'Settlements';

  @override
  String get moduleAdvances => 'Advances';

  @override
  String get moduleProducerPayments => 'Producer payments';

  @override
  String get moduleExpenses => 'Expenses';

  @override
  String get moduleComingSoon => 'Coming soon';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get onboardingSlide1Title => 'Track your production';

  @override
  String get onboardingSlide1Description =>
      'Control milk reception and cheese production in one place.';

  @override
  String get onboardingSlide2Title => 'Manage your producers';

  @override
  String get onboardingSlide2Description =>
      'Track prices, advances and settlements for each producer without paperwork.';

  @override
  String get onboardingSlide3Title => 'Payments made simple';

  @override
  String get onboardingSlide3Description =>
      'Generate settlements and keep sales, expenses and inventory under control.';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeDescription =>
      'Manage your cheese factory simply: control production, inventory, suppliers, and payments from one place.';

  @override
  String get welcomeSignIn => 'Sign In';

  @override
  String get welcomeSignUp => 'Sign Up';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerDescription =>
      'Sign up and start managing your cheese factory easily and safely.';

  @override
  String get orgNamePlaceholder => 'Your cheese factory name';

  @override
  String get invalidOrgNameError => 'Enter your cheese factory name';

  @override
  String get fullNamePlaceholder => 'Full name';

  @override
  String get registerEmailPlaceholder => 'Email';

  @override
  String get registerPasswordPlaceholder => 'Password';

  @override
  String get confirmPasswordPlaceholder => 'Confirm password';

  @override
  String get invalidFullNameError => 'Enter your full name';

  @override
  String get passwordsDoNotMatchError => 'Passwords do not match';

  @override
  String get termsPrefix => 'I accept the ';

  @override
  String get termsLink => 'Terms and Conditions';

  @override
  String get termsConnector => ' and the ';

  @override
  String get privacyLink => 'Privacy Policy.';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get registerDivider => 'or sign up with';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String get passwordReqTitle => 'Password must have:';

  @override
  String get passwordReqMinLength => 'At least 8 characters';

  @override
  String get passwordReqUppercase => 'One uppercase letter';

  @override
  String get passwordReqLowercase => 'One lowercase letter';

  @override
  String get passwordReqDigit => 'One number';

  @override
  String get resetTitle => 'Create a new password';

  @override
  String get resetDescription => 'Enter your new password to continue.';

  @override
  String get newPasswordPlaceholder => 'New password';

  @override
  String get updatePasswordButton => 'Update password';

  @override
  String get passwordUpdatedSuccess => 'Password updated. Sign in.';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get devResetLink => 'Try reset (dev)';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get logoutConfirmTitle => 'Log out?';

  @override
  String get logoutConfirmMessage =>
      'You are about to sign out of your account. Do you want to continue?';

  @override
  String get logoutConfirmAction => 'Log out';

  @override
  String appVersion(String version) {
    return 'v$version';
  }
}
