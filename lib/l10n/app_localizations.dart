import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get loginTitle;

  /// No description provided for @loginDescription.
  ///
  /// In es, this message translates to:
  /// **'Ingresa a tu cuenta para continuar gestionando tu quesera.'**
  String get loginDescription;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get loginButton;

  /// No description provided for @loginDivider.
  ///
  /// In es, this message translates to:
  /// **'o continuar con'**
  String get loginDivider;

  /// No description provided for @noAccountPrompt.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes una cuenta?'**
  String get noAccountPrompt;

  /// No description provided for @signUpLink.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get signUpLink;

  /// No description provided for @invalidEmailError.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo con formato válido'**
  String get invalidEmailError;

  /// No description provided for @invalidPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres requeridos'**
  String get invalidPasswordError;

  /// No description provided for @genericAuthError.
  ///
  /// In es, this message translates to:
  /// **'Error de autenticación'**
  String get genericAuthError;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In es, this message translates to:
  /// **'No te preocupes, ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.'**
  String get forgotPasswordInstructions;

  /// No description provided for @forgotPasswordGenericError.
  ///
  /// In es, this message translates to:
  /// **'Error al enviar correo'**
  String get forgotPasswordGenericError;

  /// No description provided for @checkEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo'**
  String get checkEmailTitle;

  /// No description provided for @checkEmailDescription.
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un enlace para que puedas crear una nueva contraseña de forma segura.'**
  String get checkEmailDescription;

  /// No description provided for @rememberedPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Recordaste tu contraseña?'**
  String get rememberedPassword;

  /// No description provided for @sendResetLinkButton.
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get sendResetLinkButton;

  /// No description provided for @logoutTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logoutTooltip;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @orgDataItem.
  ///
  /// In es, this message translates to:
  /// **'Datos de la organización'**
  String get orgDataItem;

  /// No description provided for @orgUsersItem.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get orgUsersItem;

  /// No description provided for @orgName.
  ///
  /// In es, this message translates to:
  /// **'Mi quesera'**
  String get orgName;

  /// No description provided for @adminRole.
  ///
  /// In es, this message translates to:
  /// **'Administrador'**
  String get adminRole;

  /// No description provided for @menuSectionOperations.
  ///
  /// In es, this message translates to:
  /// **'Operaciones'**
  String get menuSectionOperations;

  /// No description provided for @menuSectionDirectory.
  ///
  /// In es, this message translates to:
  /// **'Directorio'**
  String get menuSectionDirectory;

  /// No description provided for @menuSectionFinances.
  ///
  /// In es, this message translates to:
  /// **'Finanzas'**
  String get menuSectionFinances;

  /// No description provided for @menuSectionSettings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get menuSectionSettings;

  /// No description provided for @navToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get navToday;

  /// No description provided for @kpiLitersReceived.
  ///
  /// In es, this message translates to:
  /// **'litros recibidos'**
  String get kpiLitersReceived;

  /// No description provided for @kpiReceptions.
  ///
  /// In es, this message translates to:
  /// **'recepciones'**
  String get kpiReceptions;

  /// No description provided for @kpiPendingBalance.
  ///
  /// In es, this message translates to:
  /// **'saldo pendiente'**
  String get kpiPendingBalance;

  /// No description provided for @quickActions.
  ///
  /// In es, this message translates to:
  /// **'Accesos rápidos'**
  String get quickActions;

  /// No description provided for @quickNewReception.
  ///
  /// In es, this message translates to:
  /// **'Nueva recepción'**
  String get quickNewReception;

  /// No description provided for @quickNewSale.
  ///
  /// In es, this message translates to:
  /// **'Nueva venta'**
  String get quickNewSale;

  /// No description provided for @quickProducers.
  ///
  /// In es, this message translates to:
  /// **'Productores'**
  String get quickProducers;

  /// No description provided for @quickSettlements.
  ///
  /// In es, this message translates to:
  /// **'Liquidaciones'**
  String get quickSettlements;

  /// No description provided for @recentActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad reciente'**
  String get recentActivity;

  /// No description provided for @noActivity.
  ///
  /// In es, this message translates to:
  /// **'Sin actividad todavía'**
  String get noActivity;

  /// No description provided for @noActivityHint.
  ///
  /// In es, this message translates to:
  /// **'Las operaciones del día aparecen acá'**
  String get noActivityHint;

  /// No description provided for @kpiLitersValue.
  ///
  /// In es, this message translates to:
  /// **'0 L'**
  String get kpiLitersValue;

  /// No description provided for @kpiReceptionsValue.
  ///
  /// In es, this message translates to:
  /// **'0'**
  String get kpiReceptionsValue;

  /// No description provided for @kpiBalanceValue.
  ///
  /// In es, this message translates to:
  /// **'\$0'**
  String get kpiBalanceValue;

  /// No description provided for @moduleReception.
  ///
  /// In es, this message translates to:
  /// **'Recepción de leche'**
  String get moduleReception;

  /// No description provided for @moduleProduction.
  ///
  /// In es, this message translates to:
  /// **'Producción'**
  String get moduleProduction;

  /// No description provided for @modulePurchases.
  ///
  /// In es, this message translates to:
  /// **'Compras'**
  String get modulePurchases;

  /// No description provided for @moduleOrders.
  ///
  /// In es, this message translates to:
  /// **'Pedidos'**
  String get moduleOrders;

  /// No description provided for @moduleSales.
  ///
  /// In es, this message translates to:
  /// **'Ventas'**
  String get moduleSales;

  /// No description provided for @moduleProducers.
  ///
  /// In es, this message translates to:
  /// **'Productores'**
  String get moduleProducers;

  /// No description provided for @moduleCollectors.
  ///
  /// In es, this message translates to:
  /// **'Recolectores y rutas'**
  String get moduleCollectors;

  /// No description provided for @moduleProducts.
  ///
  /// In es, this message translates to:
  /// **'Productos'**
  String get moduleProducts;

  /// No description provided for @moduleSupplies.
  ///
  /// In es, this message translates to:
  /// **'Insumos e inventario'**
  String get moduleSupplies;

  /// No description provided for @moduleSuppliers.
  ///
  /// In es, this message translates to:
  /// **'Proveedores'**
  String get moduleSuppliers;

  /// No description provided for @moduleClients.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get moduleClients;

  /// No description provided for @moduleTools.
  ///
  /// In es, this message translates to:
  /// **'Utensilios y equipos'**
  String get moduleTools;

  /// No description provided for @moduleSettlements.
  ///
  /// In es, this message translates to:
  /// **'Liquidaciones'**
  String get moduleSettlements;

  /// No description provided for @moduleAdvances.
  ///
  /// In es, this message translates to:
  /// **'Adelantos'**
  String get moduleAdvances;

  /// No description provided for @moduleProducerPayments.
  ///
  /// In es, this message translates to:
  /// **'Pagos a productores'**
  String get moduleProducerPayments;

  /// No description provided for @moduleExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get moduleExpenses;

  /// No description provided for @moduleComingSoon.
  ///
  /// In es, this message translates to:
  /// **'Próximamente'**
  String get moduleComingSoon;

  /// No description provided for @onboardingSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get onboardingStart;

  /// No description provided for @onboardingSlide1Title.
  ///
  /// In es, this message translates to:
  /// **'Registra tu producción'**
  String get onboardingSlide1Title;

  /// No description provided for @onboardingSlide1Description.
  ///
  /// In es, this message translates to:
  /// **'Controla la recepción de leche y la producción de tus quesos en un solo lugar.'**
  String get onboardingSlide1Description;

  /// No description provided for @onboardingSlide2Title.
  ///
  /// In es, this message translates to:
  /// **'Gestiona tus productores'**
  String get onboardingSlide2Title;

  /// No description provided for @onboardingSlide2Description.
  ///
  /// In es, this message translates to:
  /// **'Lleva precios, adelantos y liquidaciones de cada productor sin papeleo.'**
  String get onboardingSlide2Description;

  /// No description provided for @onboardingSlide3Title.
  ///
  /// In es, this message translates to:
  /// **'Pagos sin complicaciones'**
  String get onboardingSlide3Title;

  /// No description provided for @onboardingSlide3Description.
  ///
  /// In es, this message translates to:
  /// **'Genera liquidaciones y mantén el control de ventas, gastos e inventario.'**
  String get onboardingSlide3Description;

  /// No description provided for @welcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In es, this message translates to:
  /// **'Gestiona tu quesera de forma simple: controla producción, inventario, proveedores y pagos desde un solo lugar.'**
  String get welcomeDescription;

  /// No description provided for @welcomeSignIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get welcomeSignIn;

  /// No description provided for @welcomeSignUp.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get welcomeSignUp;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerTitle;

  /// No description provided for @registerDescription.
  ///
  /// In es, this message translates to:
  /// **'Regístrate y comienza a gestionar tu quesera de forma fácil y segura.'**
  String get registerDescription;

  /// No description provided for @orgNamePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Nombre de tu quesera'**
  String get orgNamePlaceholder;

  /// No description provided for @invalidOrgNameError.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el nombre de tu quesera'**
  String get invalidOrgNameError;

  /// No description provided for @fullNamePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get fullNamePlaceholder;

  /// No description provided for @registerEmailPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get registerEmailPlaceholder;

  /// No description provided for @registerPasswordPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get registerPasswordPlaceholder;

  /// No description provided for @confirmPasswordPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get confirmPasswordPlaceholder;

  /// No description provided for @invalidFullNameError.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nombre completo'**
  String get invalidFullNameError;

  /// No description provided for @passwordsDoNotMatchError.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get passwordsDoNotMatchError;

  /// No description provided for @termsPrefix.
  ///
  /// In es, this message translates to:
  /// **'Acepto los '**
  String get termsPrefix;

  /// No description provided for @termsLink.
  ///
  /// In es, this message translates to:
  /// **'Términos y Condiciones'**
  String get termsLink;

  /// No description provided for @termsConnector.
  ///
  /// In es, this message translates to:
  /// **' y la '**
  String get termsConnector;

  /// No description provided for @privacyLink.
  ///
  /// In es, this message translates to:
  /// **'Política de Privacidad.'**
  String get privacyLink;

  /// No description provided for @createAccountButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccountButton;

  /// No description provided for @registerDivider.
  ///
  /// In es, this message translates to:
  /// **'o regístrate con'**
  String get registerDivider;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes una cuenta?'**
  String get alreadyHaveAccount;

  /// No description provided for @signInLink.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signInLink;

  /// No description provided for @passwordReqTitle.
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener:'**
  String get passwordReqTitle;

  /// No description provided for @passwordReqMinLength.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get passwordReqMinLength;

  /// No description provided for @passwordReqUppercase.
  ///
  /// In es, this message translates to:
  /// **'Una letra mayúscula'**
  String get passwordReqUppercase;

  /// No description provided for @passwordReqLowercase.
  ///
  /// In es, this message translates to:
  /// **'Una letra minúscula'**
  String get passwordReqLowercase;

  /// No description provided for @passwordReqDigit.
  ///
  /// In es, this message translates to:
  /// **'Un número'**
  String get passwordReqDigit;

  /// No description provided for @resetTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea una nueva contraseña'**
  String get resetTitle;

  /// No description provided for @resetDescription.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nueva contraseña para continuar.'**
  String get resetDescription;

  /// No description provided for @newPasswordPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get newPasswordPlaceholder;

  /// No description provided for @updatePasswordButton.
  ///
  /// In es, this message translates to:
  /// **'Actualizar contraseña'**
  String get updatePasswordButton;

  /// No description provided for @passwordUpdatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Contraseña actualizada. Inicia sesión.'**
  String get passwordUpdatedSuccess;

  /// No description provided for @backToLogin.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio de sesión'**
  String get backToLogin;

  /// No description provided for @devResetLink.
  ///
  /// In es, this message translates to:
  /// **'Probar restablecer (dev)'**
  String get devResetLink;

  /// No description provided for @cancelAction.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelAction;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Vas a salir de tu cuenta. ¿Querés continuar?'**
  String get logoutConfirmMessage;

  /// No description provided for @logoutConfirmAction.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logoutConfirmAction;

  /// No description provided for @appVersion.
  ///
  /// In es, this message translates to:
  /// **'v{version}'**
  String appVersion(String version);

  /// No description provided for @newUserButton.
  ///
  /// In es, this message translates to:
  /// **'Nuevo usuario'**
  String get newUserButton;

  /// No description provided for @roleOperator.
  ///
  /// In es, this message translates to:
  /// **'Operario'**
  String get roleOperator;

  /// No description provided for @roleCollector.
  ///
  /// In es, this message translates to:
  /// **'Recolector'**
  String get roleCollector;

  /// No description provided for @roleProducer.
  ///
  /// In es, this message translates to:
  /// **'Productor'**
  String get roleProducer;

  /// No description provided for @searchUsersHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o correo'**
  String get searchUsersHint;

  /// No description provided for @roleFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get roleFilterAll;

  /// No description provided for @noSearchResultsTitle.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get noSearchResultsTitle;

  /// No description provided for @noSearchResultsHint.
  ///
  /// In es, this message translates to:
  /// **'Probá con otro nombre, correo o filtro.'**
  String get noSearchResultsHint;

  /// No description provided for @memberStatusActive.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get memberStatusActive;

  /// No description provided for @memberStatusSuspended.
  ///
  /// In es, this message translates to:
  /// **'Suspendido'**
  String get memberStatusSuspended;

  /// No description provided for @memberActionsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Opciones del usuario'**
  String get memberActionsTooltip;

  /// No description provided for @suspendUserAction.
  ///
  /// In es, this message translates to:
  /// **'Suspender usuario'**
  String get suspendUserAction;

  /// No description provided for @reactivateUserAction.
  ///
  /// In es, this message translates to:
  /// **'Reactivar usuario'**
  String get reactivateUserAction;

  /// No description provided for @resetPasswordAction.
  ///
  /// In es, this message translates to:
  /// **'Restablecer contraseña'**
  String get resetPasswordAction;

  /// No description provided for @emptyUsersTitle.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay usuarios'**
  String get emptyUsersTitle;

  /// No description provided for @emptyUsersHint.
  ///
  /// In es, this message translates to:
  /// **'Los usuarios que crees para tu quesera aparecerán acá.'**
  String get emptyUsersHint;

  /// No description provided for @membersCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{{count} miembro} other{{count} miembros}}'**
  String membersCount(int count);

  /// No description provided for @activeMembersCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{{count} activo} other{{count} activos}}'**
  String activeMembersCount(int count);

  /// No description provided for @newUserSheetHint.
  ///
  /// In es, this message translates to:
  /// **'El usuario ingresará con esta contraseña temporal — compartila con él.'**
  String get newUserSheetHint;

  /// No description provided for @tempPasswordPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Contraseña temporal'**
  String get tempPasswordPlaceholder;

  /// No description provided for @roleFieldLabel.
  ///
  /// In es, this message translates to:
  /// **'Rol en la organización'**
  String get roleFieldLabel;

  /// No description provided for @roleRequiredError.
  ///
  /// In es, this message translates to:
  /// **'Elegí un rol'**
  String get roleRequiredError;

  /// No description provided for @invalidMemberNameError.
  ///
  /// In es, this message translates to:
  /// **'Ingresá el nombre completo'**
  String get invalidMemberNameError;

  /// No description provided for @invalidTempPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres, una mayúscula, una minúscula y un número'**
  String get invalidTempPasswordError;

  /// No description provided for @createUserButton.
  ///
  /// In es, this message translates to:
  /// **'Crear usuario'**
  String get createUserButton;

  /// No description provided for @memberCreatedFeedback.
  ///
  /// In es, this message translates to:
  /// **'Usuario creado — compartile la contraseña temporal'**
  String get memberCreatedFeedback;

  /// No description provided for @suspendMemberTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Suspender a {name}?'**
  String suspendMemberTitle(String name);

  /// No description provided for @suspendMemberMessage.
  ///
  /// In es, this message translates to:
  /// **'Perderá el acceso a esta organización hasta que lo reactives.'**
  String get suspendMemberMessage;

  /// No description provided for @reactivateMemberTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Reactivar a {name}?'**
  String reactivateMemberTitle(String name);

  /// No description provided for @reactivateMemberMessage.
  ///
  /// In es, this message translates to:
  /// **'Recuperará el acceso a esta organización.'**
  String get reactivateMemberMessage;

  /// No description provided for @memberSuspendedFeedback.
  ///
  /// In es, this message translates to:
  /// **'Membresía suspendida'**
  String get memberSuspendedFeedback;

  /// No description provided for @memberReactivatedFeedback.
  ///
  /// In es, this message translates to:
  /// **'Membresía reactivada'**
  String get memberReactivatedFeedback;

  /// No description provided for @resetPasswordSheetHint.
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña temporal para {name} — ingresará con ella.'**
  String resetPasswordSheetHint(String name);

  /// No description provided for @passwordResetFeedback.
  ///
  /// In es, this message translates to:
  /// **'Contraseña restablecida — compartila con {name}'**
  String passwordResetFeedback(String name);
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
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
