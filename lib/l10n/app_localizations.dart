import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'RideBridge'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Il tuo interfono intelligente'**
  String get appSubtitle;

  /// No description provided for @loginButton.
  ///
  /// In it, this message translates to:
  /// **'ACCEDI CON GOOGLE'**
  String get loginButton;

  /// No description provided for @loginError.
  ///
  /// In it, this message translates to:
  /// **'Errore durante il login: {error}'**
  String loginError(String error);

  /// No description provided for @logoutTooltip.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get logoutTooltip;

  /// No description provided for @welcomeMessage.
  ///
  /// In it, this message translates to:
  /// **'Benvenuto, {name}'**
  String welcomeMessage(String name);

  /// No description provided for @myGroups.
  ///
  /// In it, this message translates to:
  /// **'I MIEI GRUPPI'**
  String get myGroups;

  /// No description provided for @createGroup.
  ///
  /// In it, this message translates to:
  /// **'CREA GRUPPO'**
  String get createGroup;

  /// No description provided for @joinGroup.
  ///
  /// In it, this message translates to:
  /// **'ENTRA NEL GRUPPO'**
  String get joinGroup;

  /// No description provided for @profile.
  ///
  /// In it, this message translates to:
  /// **'IL MIO PROFILO'**
  String get profile;

  /// No description provided for @groupConfiguration.
  ///
  /// In it, this message translates to:
  /// **'Configurazione Gruppo'**
  String get groupConfiguration;

  /// No description provided for @navParameters.
  ///
  /// In it, this message translates to:
  /// **'Parametri Navigazione'**
  String get navParameters;

  /// No description provided for @turnAngle.
  ///
  /// In it, this message translates to:
  /// **'Angolo Svolta (gradi)'**
  String get turnAngle;

  /// No description provided for @waypointDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza Waypoint (metri)'**
  String get waypointDistance;

  /// No description provided for @convoyThresholds.
  ///
  /// In it, this message translates to:
  /// **'Soglie Carovana'**
  String get convoyThresholds;

  /// No description provided for @maxGroupDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza Max Gruppo (metri)'**
  String get maxGroupDistance;

  /// No description provided for @maxSweeperDistance.
  ///
  /// In it, this message translates to:
  /// **'Distanza Max Scopa (metri)'**
  String get maxSweeperDistance;

  /// No description provided for @offRouteThreshold.
  ///
  /// In it, this message translates to:
  /// **'Soglia Fuori Percorso (metri)'**
  String get offRouteThreshold;

  /// No description provided for @saveConfiguration.
  ///
  /// In it, this message translates to:
  /// **'SALVA CONFIGURAZIONE'**
  String get saveConfiguration;

  /// No description provided for @configSaved.
  ///
  /// In it, this message translates to:
  /// **'Configurazione salvata'**
  String get configSaved;

  /// No description provided for @errorPrefix.
  ///
  /// In it, this message translates to:
  /// **'Errore: {error}'**
  String errorPrefix(String error);

  /// No description provided for @requiredField.
  ///
  /// In it, this message translates to:
  /// **'Campo obbligatorio'**
  String get requiredField;

  /// No description provided for @invalidNumber.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un numero valido'**
  String get invalidNumber;

  /// No description provided for @exitGroup.
  ///
  /// In it, this message translates to:
  /// **'Esci dal Gruppo'**
  String get exitGroup;

  /// No description provided for @exitGroupConfirm.
  ///
  /// In it, this message translates to:
  /// **'Sei sicuro di voler uscire? Non potrai più comunicare con il team.'**
  String get exitGroupConfirm;

  /// No description provided for @cancel.
  ///
  /// In it, this message translates to:
  /// **'ANNULLA'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In it, this message translates to:
  /// **'CONFERMA'**
  String get confirm;

  /// No description provided for @exit.
  ///
  /// In it, this message translates to:
  /// **'ESCI'**
  String get exit;

  /// No description provided for @deleteGroup.
  ///
  /// In it, this message translates to:
  /// **'ELIMINA GRUPPO'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In it, this message translates to:
  /// **'Questa azione disattiverà il gruppo per tutti i partecipanti. Sei sicuro?'**
  String get deleteGroupConfirm;

  /// No description provided for @delete.
  ///
  /// In it, this message translates to:
  /// **'ELIMINA'**
  String get delete;

  /// No description provided for @accessCode.
  ///
  /// In it, this message translates to:
  /// **'CODICE DI ACCESSO'**
  String get accessCode;

  /// No description provided for @share.
  ///
  /// In it, this message translates to:
  /// **'CONDIVIDI'**
  String get share;

  /// No description provided for @copy.
  ///
  /// In it, this message translates to:
  /// **'COPIA'**
  String get copy;

  /// No description provided for @yourRole.
  ///
  /// In it, this message translates to:
  /// **'IL TUO RUOLO'**
  String get yourRole;

  /// No description provided for @participants.
  ///
  /// In it, this message translates to:
  /// **'PARTECIPANTI'**
  String get participants;

  /// No description provided for @loading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento...'**
  String get loading;

  /// No description provided for @codeCopied.
  ///
  /// In it, this message translates to:
  /// **'Codice copiato negli appunti'**
  String get codeCopied;

  /// No description provided for @memberDetail.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio Membro'**
  String get memberDetail;

  /// No description provided for @memberNotFound.
  ///
  /// In it, this message translates to:
  /// **'Membro non trovato'**
  String get memberNotFound;

  /// No description provided for @online.
  ///
  /// In it, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In it, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @microphoneStatus.
  ///
  /// In it, this message translates to:
  /// **'Microfono: {status}'**
  String microphoneStatus(String status);

  /// No description provided for @audioStatus.
  ///
  /// In it, this message translates to:
  /// **'Audio: {status}'**
  String audioStatus(String status);

  /// No description provided for @emergencyActive.
  ///
  /// In it, this message translates to:
  /// **'EMERGENZA ATTIVA'**
  String get emergencyActive;

  /// No description provided for @leaderActions.
  ///
  /// In it, this message translates to:
  /// **'AZIONI LEADER'**
  String get leaderActions;

  /// No description provided for @makeSweeper.
  ///
  /// In it, this message translates to:
  /// **'Nomina Scopa'**
  String get makeSweeper;

  /// No description provided for @removeSweeper.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi Scopa'**
  String get removeSweeper;

  /// No description provided for @disableMic.
  ///
  /// In it, this message translates to:
  /// **'Disabilita Microfono'**
  String get disableMic;

  /// No description provided for @enableMic.
  ///
  /// In it, this message translates to:
  /// **'Abilita Microfono'**
  String get enableMic;

  /// No description provided for @disableAudio.
  ///
  /// In it, this message translates to:
  /// **'Disabilita Audio'**
  String get disableAudio;

  /// No description provided for @enableAudio.
  ///
  /// In it, this message translates to:
  /// **'Abilita Audio'**
  String get enableAudio;

  /// No description provided for @promoteToLeader.
  ///
  /// In it, this message translates to:
  /// **'Promuovi a Leader'**
  String get promoteToLeader;

  /// No description provided for @transferLeadership.
  ///
  /// In it, this message translates to:
  /// **'Trasferisci Leadership'**
  String get transferLeadership;

  /// No description provided for @transferLeadershipConfirm.
  ///
  /// In it, this message translates to:
  /// **'Vuoi davvero nominare {name} nuovo Leader? Perderai i poteri di comando.'**
  String transferLeadershipConfirm(String name);

  /// No description provided for @enabled.
  ///
  /// In it, this message translates to:
  /// **'Abilitato'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In it, this message translates to:
  /// **'Disabilitato'**
  String get disabled;

  /// No description provided for @startAdventure.
  ///
  /// In it, this message translates to:
  /// **'Inizia una nuova avventura'**
  String get startAdventure;

  /// No description provided for @chooseGroupName.
  ///
  /// In it, this message translates to:
  /// **'Scegli un nome per il tuo gruppo di motociclisti.'**
  String get chooseGroupName;

  /// No description provided for @groupName.
  ///
  /// In it, this message translates to:
  /// **'Nome del Gruppo'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In it, this message translates to:
  /// **'es. I Lupi della Strada'**
  String get groupNameHint;

  /// No description provided for @groupNameEmpty.
  ///
  /// In it, this message translates to:
  /// **'Il nome del gruppo non può essere vuoto'**
  String get groupNameEmpty;

  /// No description provided for @groupCreated.
  ///
  /// In it, this message translates to:
  /// **'Gruppo creato con successo'**
  String get groupCreated;

  /// No description provided for @shareWithFriends.
  ///
  /// In it, this message translates to:
  /// **'Condividi questo codice con i tuoi amici:'**
  String get shareWithFriends;

  /// No description provided for @ok.
  ///
  /// In it, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @joinTeam.
  ///
  /// In it, this message translates to:
  /// **'Unisciti al Team'**
  String get joinTeam;

  /// No description provided for @enterCodeInstructions.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il codice di 6 caratteri ricevuto dal tuo leader.'**
  String get enterCodeInstructions;

  /// No description provided for @groupCode.
  ///
  /// In it, this message translates to:
  /// **'Codice Gruppo'**
  String get groupCode;

  /// No description provided for @groupCodeHint.
  ///
  /// In it, this message translates to:
  /// **'es. RIDE24'**
  String get groupCodeHint;

  /// No description provided for @enterCodeError.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il codice del gruppo'**
  String get enterCodeError;

  /// No description provided for @joinSuccess.
  ///
  /// In it, this message translates to:
  /// **'Entrato nel gruppo con successo'**
  String get joinSuccess;

  /// No description provided for @myProfile.
  ///
  /// In it, this message translates to:
  /// **'Il Mio Profilo'**
  String get myProfile;

  /// No description provided for @profileUpdated.
  ///
  /// In it, this message translates to:
  /// **'Profilo aggiornato con successo'**
  String get profileUpdated;

  /// No description provided for @nickname.
  ///
  /// In it, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameHint.
  ///
  /// In it, this message translates to:
  /// **'Scegli il tuo nome da rider'**
  String get nicknameHint;

  /// No description provided for @nicknameError.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un nickname'**
  String get nicknameError;

  /// No description provided for @yourMotorcycle.
  ///
  /// In it, this message translates to:
  /// **'La tua Moto'**
  String get yourMotorcycle;

  /// No description provided for @motorcycleHint.
  ///
  /// In it, this message translates to:
  /// **'es. Ducati Monster, BMW GS...'**
  String get motorcycleHint;

  /// No description provided for @motorcycleError.
  ///
  /// In it, this message translates to:
  /// **'Inserisci il modello della tua moto'**
  String get motorcycleError;

  /// No description provided for @saveChanges.
  ///
  /// In it, this message translates to:
  /// **'SALVA MODIFICHE'**
  String get saveChanges;

  /// No description provided for @joinLive.
  ///
  /// In it, this message translates to:
  /// **'PARTECIPA'**
  String get joinLive;

  /// No description provided for @joinLiveError.
  ///
  /// In it, this message translates to:
  /// **'Errore durante l\'accesso alla live: {error}'**
  String joinLiveError(String error);

  /// No description provided for @noGroupsJoined.
  ///
  /// In it, this message translates to:
  /// **'Non fai parte di alcun gruppo'**
  String get noGroupsJoined;

  /// No description provided for @backToHome.
  ///
  /// In it, this message translates to:
  /// **'Torna alla Home'**
  String get backToHome;

  /// No description provided for @clearWaypointsTitle.
  ///
  /// In it, this message translates to:
  /// **'Nuova Sessione'**
  String get clearWaypointsTitle;

  /// No description provided for @clearWaypointsContent.
  ///
  /// In it, this message translates to:
  /// **'Sei il Leader. Vuoi cancellare lo storico delle svolte precedenti per iniziare una sessione pulita?'**
  String get clearWaypointsContent;

  /// No description provided for @clearWaypointsConfirm.
  ///
  /// In it, this message translates to:
  /// **'CANCELLA'**
  String get clearWaypointsConfirm;

  /// No description provided for @clearWaypointsKeep.
  ///
  /// In it, this message translates to:
  /// **'MANTIENI'**
  String get clearWaypointsKeep;

  /// No description provided for @participantsLive.
  ///
  /// In it, this message translates to:
  /// **'PARTECIPANTI LIVE'**
  String get participantsLive;

  /// No description provided for @scopa.
  ///
  /// In it, this message translates to:
  /// **'SCOPA'**
  String get scopa;

  /// No description provided for @leader.
  ///
  /// In it, this message translates to:
  /// **'LEADER'**
  String get leader;

  /// No description provided for @sos.
  ///
  /// In it, this message translates to:
  /// **'SOS'**
  String get sos;

  /// No description provided for @speaking.
  ///
  /// In it, this message translates to:
  /// **'STA PARLANDO'**
  String get speaking;

  /// No description provided for @sosActive.
  ///
  /// In it, this message translates to:
  /// **'🚨 SOS ATTIVO'**
  String get sosActive;

  /// No description provided for @assistanceRequested.
  ///
  /// In it, this message translates to:
  /// **'RICHIESTA ASSISTENZA'**
  String get assistanceRequested;

  /// No description provided for @none.
  ///
  /// In it, this message translates to:
  /// **'Nessuno'**
  String get none;

  /// No description provided for @noParticipants.
  ///
  /// In it, this message translates to:
  /// **'Nessun partecipante'**
  String get noParticipants;

  /// No description provided for @caravanStatus.
  ///
  /// In it, this message translates to:
  /// **'Stato Carovana'**
  String get caravanStatus;

  /// No description provided for @viewCaravanStatus.
  ///
  /// In it, this message translates to:
  /// **'STATO CAROVANA'**
  String get viewCaravanStatus;

  /// No description provided for @appInfo.
  ///
  /// In it, this message translates to:
  /// **'Informazioni App'**
  String get appInfo;

  /// No description provided for @developer.
  ///
  /// In it, this message translates to:
  /// **'Sviluppatore'**
  String get developer;

  /// No description provided for @version.
  ///
  /// In it, this message translates to:
  /// **'Versione'**
  String get version;

  /// No description provided for @aboutText.
  ///
  /// In it, this message translates to:
  /// **'RideBridge è nata dalla passione per le due ruote e dalla voglia di rendere ogni viaggio in gruppo più sicuro e connesso. Grazie per far parte della nostra community!'**
  String get aboutText;

  /// No description provided for @credits.
  ///
  /// In it, this message translates to:
  /// **'Creato con ❤️ per i motociclisti'**
  String get credits;

  /// No description provided for @aheadOfLeader.
  ///
  /// In it, this message translates to:
  /// **'Attenzione: sei avanti al leader, si è pregati di rientrare in formazione.'**
  String get aheadOfLeader;

  /// No description provided for @behindSweeper.
  ///
  /// In it, this message translates to:
  /// **'Attenzione: sei dietro la scopa, si è pregati di rientrare in formazione.'**
  String get behindSweeper;

  /// No description provided for @offRoute.
  ///
  /// In it, this message translates to:
  /// **'Sei fuori percorso. Vuoi avviare la navigazione verso il leader?'**
  String get offRoute;

  /// No description provided for @turnAlert.
  ///
  /// In it, this message translates to:
  /// **'Tra {distance} metri, svolta a {direction}.'**
  String turnAlert(int distance, String direction);

  /// No description provided for @rejoinLeader.
  ///
  /// In it, this message translates to:
  /// **'Naviga verso il Leader'**
  String get rejoinLeader;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
