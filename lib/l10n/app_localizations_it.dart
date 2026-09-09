// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'RideBridge';

  @override
  String get appSubtitle => 'Il tuo interfono intelligente';

  @override
  String get loginButton => 'ACCEDI CON GOOGLE';

  @override
  String loginError(String error) {
    return 'Errore durante il login: $error';
  }

  @override
  String get logoutTooltip => 'Esci';

  @override
  String welcomeMessage(String name) {
    return 'Benvenuto, $name';
  }

  @override
  String get myGroups => 'I MIEI GRUPPI';

  @override
  String get createGroup => 'CREA GRUPPO';

  @override
  String get joinGroup => 'ENTRA NEL GRUPPO';

  @override
  String get profile => 'IL MIO PROFILO';

  @override
  String get groupConfiguration => 'Configurazione Gruppo';

  @override
  String get navParameters => 'Parametri Navigazione';

  @override
  String get turnAngle => 'Angolo Svolta (gradi)';

  @override
  String get waypointDistance => 'Distanza Waypoint (metri)';

  @override
  String get convoyThresholds => 'Soglie Carovana';

  @override
  String get maxGroupDistance => 'Distanza Max Gruppo (metri)';

  @override
  String get maxSweeperDistance => 'Distanza Max Scopa (metri)';

  @override
  String get offRouteThreshold => 'Soglia Fuori Percorso (metri)';

  @override
  String get saveConfiguration => 'SALVA CONFIGURAZIONE';

  @override
  String get configSaved => 'Configurazione salvata';

  @override
  String errorPrefix(String error) {
    return 'Errore: $error';
  }

  @override
  String get requiredField => 'Campo obbligatorio';

  @override
  String get invalidNumber => 'Inserisci un numero valido';

  @override
  String get exitGroup => 'Esci dal Gruppo';

  @override
  String get exitGroupConfirm =>
      'Sei sicuro di voler uscire? Non potrai più comunicare con il team.';

  @override
  String get cancel => 'ANNULLA';

  @override
  String get confirm => 'CONFERMA';

  @override
  String get exit => 'ESCI';

  @override
  String get deleteGroup => 'ELIMINA GRUPPO';

  @override
  String get deleteGroupConfirm =>
      'Questa azione disattiverà il gruppo per tutti i partecipanti. Sei sicuro?';

  @override
  String get delete => 'ELIMINA';

  @override
  String get accessCode => 'CODICE DI ACCESSO';

  @override
  String get share => 'CONDIVIDI';

  @override
  String get copy => 'COPIA';

  @override
  String get yourRole => 'IL TUO RUOLO';

  @override
  String get participants => 'PARTECIPANTI';

  @override
  String get loading => 'Caricamento...';

  @override
  String get codeCopied => 'Codice copiato negli appunti';

  @override
  String get memberDetail => 'Dettaglio Membro';

  @override
  String get memberNotFound => 'Membro non trovato';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String microphoneStatus(String status) {
    return 'Microfono: $status';
  }

  @override
  String audioStatus(String status) {
    return 'Audio: $status';
  }

  @override
  String get emergencyActive => 'EMERGENZA ATTIVA';

  @override
  String get leaderActions => 'AZIONI LEADER';

  @override
  String get makeSweeper => 'Nomina Scopa';

  @override
  String get removeSweeper => 'Rimuovi Scopa';

  @override
  String get disableMic => 'Disabilita Microfono';

  @override
  String get enableMic => 'Abilita Microfono';

  @override
  String get disableAudio => 'Disabilita Audio';

  @override
  String get enableAudio => 'Abilita Audio';

  @override
  String get promoteToLeader => 'Promuovi a Leader';

  @override
  String get transferLeadership => 'Trasferisci Leadership';

  @override
  String transferLeadershipConfirm(String name) {
    return 'Vuoi davvero nominare $name nuovo Leader? Perderai i poteri di comando.';
  }

  @override
  String get enabled => 'Abilitato';

  @override
  String get disabled => 'Disabilitato';

  @override
  String get startAdventure => 'Inizia una nuova avventura';

  @override
  String get chooseGroupName =>
      'Scegli un nome per il tuo gruppo di motociclisti.';

  @override
  String get groupName => 'Nome del Gruppo';

  @override
  String get groupNameHint => 'es. I Lupi della Strada';

  @override
  String get groupNameEmpty => 'Il nome del gruppo non può essere vuoto';

  @override
  String get groupCreated => 'Gruppo creato con successo';

  @override
  String get shareWithFriends => 'Condividi questo codice con i tuoi amici:';

  @override
  String get ok => 'OK';

  @override
  String get joinTeam => 'Unisciti al Team';

  @override
  String get enterCodeInstructions =>
      'Inserisci il codice di 6 caratteri ricevuto dal tuo leader.';

  @override
  String get groupCode => 'Codice Gruppo';

  @override
  String get groupCodeHint => 'es. RIDE24';

  @override
  String get enterCodeError => 'Inserisci il codice del gruppo';

  @override
  String get joinSuccess => 'Entrato nel gruppo con successo';

  @override
  String get myProfile => 'Il Mio Profilo';

  @override
  String get profileUpdated => 'Profilo aggiornato con successo';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Scegli il tuo nome da rider';

  @override
  String get nicknameError => 'Inserisci un nickname';

  @override
  String get yourMotorcycle => 'La tua Moto';

  @override
  String get motorcycleHint => 'es. Ducati Monster, BMW GS...';

  @override
  String get motorcycleError => 'Inserisci il modello della tua moto';

  @override
  String get saveChanges => 'SALVA MODIFICHE';

  @override
  String get joinLive => 'PARTECIPA';

  @override
  String joinLiveError(String error) {
    return 'Errore durante l\'accesso alla live: $error';
  }

  @override
  String get noGroupsJoined => 'Non fai parte di alcun gruppo';

  @override
  String get backToHome => 'Torna alla Home';

  @override
  String get participantsLive => 'PARTECIPANTI LIVE';

  @override
  String get scopa => 'SCOPA';

  @override
  String get leader => 'LEADER';

  @override
  String get sos => 'SOS';

  @override
  String get speaking => 'STA PARLANDO';

  @override
  String get sosActive => '🚨 SOS ATTIVO';

  @override
  String get assistanceRequested => 'RICHIESTA ASSISTENZA';

  @override
  String get none => 'Nessuno';

  @override
  String get noParticipants => 'Nessun partecipante';

  @override
  String get appInfo => 'Informazioni App';

  @override
  String get developer => 'Sviluppatore';

  @override
  String get version => 'Versione';

  @override
  String get aboutText =>
      'RideBridge è nata dalla passione per le due ruote e dalla voglia di rendere ogni viaggio in gruppo più sicuro e connesso. Grazie per far parte della nostra community!';

  @override
  String get credits => 'Creato con ❤️ per i motociclisti';

  @override
  String get aheadOfLeader =>
      'Attenzione: sei avanti al leader, si è pregati di rientrare in formazione.';

  @override
  String get behindSweeper =>
      'Attenzione: sei dietro la scopa, si è pregati di rientrare in formazione.';

  @override
  String get offRoute =>
      'Sei fuori percorso. Vuoi avviare la navigazione verso il leader?';

  @override
  String turnAlert(int distance, String direction) {
    return 'Tra $distance metri, svolta a $direction.';
  }

  @override
  String get rejoinLeader => 'Naviga verso il Leader';
}
