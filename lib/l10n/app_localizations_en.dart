// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RideBridge';

  @override
  String get appSubtitle => 'Your intelligent intercom';

  @override
  String get loginButton => 'SIGN IN WITH GOOGLE';

  @override
  String loginError(String error) {
    return 'Login error: $error';
  }

  @override
  String get logoutTooltip => 'Logout';

  @override
  String welcomeMessage(String name) {
    return 'Welcome, $name';
  }

  @override
  String get myGroups => 'MY GROUPS';

  @override
  String get createGroup => 'CREATE GROUP';

  @override
  String get joinGroup => 'JOIN GROUP';

  @override
  String get profile => 'MY PROFILE';

  @override
  String get groupConfiguration => 'Group Configuration';

  @override
  String get navParameters => 'Navigation Parameters';

  @override
  String get turnAngle => 'Turn Angle (degrees)';

  @override
  String get waypointDistance => 'Waypoint Distance (meters)';

  @override
  String get convoyThresholds => 'Convoy Thresholds';

  @override
  String get maxGroupDistance => 'Max Group Distance (meters)';

  @override
  String get maxSweeperDistance => 'Max Sweeper Distance (meters)';

  @override
  String get offRouteThreshold => 'Off Route Threshold (meters)';

  @override
  String get saveConfiguration => 'SAVE CONFIGURATION';

  @override
  String get configSaved => 'Configuration saved';

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get requiredField => 'Required field';

  @override
  String get invalidNumber => 'Enter a valid number';

  @override
  String get exitGroup => 'Exit Group';

  @override
  String get exitGroupConfirm =>
      'Are you sure you want to exit? You will no longer be able to communicate with the team.';

  @override
  String get cancel => 'CANCEL';

  @override
  String get confirm => 'CONFIRM';

  @override
  String get exit => 'EXIT';

  @override
  String get deleteGroup => 'DELETE GROUP';

  @override
  String get deleteGroupConfirm =>
      'This action will deactivate the group for all participants. Are you sure?';

  @override
  String get delete => 'DELETE';

  @override
  String get accessCode => 'ACCESS CODE';

  @override
  String get share => 'SHARE';

  @override
  String get copy => 'COPY';

  @override
  String get yourRole => 'YOUR ROLE';

  @override
  String get participants => 'PARTICIPANTS';

  @override
  String get loading => 'Loading...';

  @override
  String get codeCopied => 'Code copied to clipboard';

  @override
  String get memberDetail => 'Member Detail';

  @override
  String get memberNotFound => 'Member not found';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String microphoneStatus(String status) {
    return 'Microphone: $status';
  }

  @override
  String audioStatus(String status) {
    return 'Audio: $status';
  }

  @override
  String get emergencyActive => 'EMERGENCY ACTIVE';

  @override
  String get leaderActions => 'LEADER ACTIONS';

  @override
  String get makeSweeper => 'Make Sweeper';

  @override
  String get removeSweeper => 'Remove Sweeper';

  @override
  String get disableMic => 'Disable Microphone';

  @override
  String get enableMic => 'Enable Microphone';

  @override
  String get disableAudio => 'Disable Audio';

  @override
  String get enableAudio => 'Enable Audio';

  @override
  String get promoteToLeader => 'Promote to Leader';

  @override
  String get transferLeadership => 'Transfer Leadership';

  @override
  String transferLeadershipConfirm(String name) {
    return 'Do you really want to nominate $name as the new Leader? You will lose command powers.';
  }

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get startAdventure => 'Start a new adventure';

  @override
  String get chooseGroupName => 'Choose a name for your motorcycle group.';

  @override
  String get groupName => 'Group Name';

  @override
  String get groupNameHint => 'e.g. Road Wolves';

  @override
  String get groupNameEmpty => 'Group name cannot be empty';

  @override
  String get groupCreated => 'Group created successfully';

  @override
  String get shareWithFriends => 'Share this code with your friends:';

  @override
  String get ok => 'OK';

  @override
  String get joinTeam => 'Join the Team';

  @override
  String get enterCodeInstructions =>
      'Enter the 6-character code received from your leader.';

  @override
  String get groupCode => 'Group Code';

  @override
  String get groupCodeHint => 'e.g. RIDE24';

  @override
  String get enterCodeError => 'Enter the group code';

  @override
  String get joinSuccess => 'Joined group successfully';

  @override
  String get myProfile => 'My Profile';

  @override
  String get profileUpdated => 'Profile updated successfully';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Choose your rider name';

  @override
  String get nicknameError => 'Enter a nickname';

  @override
  String get yourMotorcycle => 'Your Motorcycle';

  @override
  String get motorcycleHint => 'e.g. Ducati Monster, BMW GS...';

  @override
  String get motorcycleError => 'Enter your motorcycle model';

  @override
  String get saveChanges => 'SAVE CHANGES';

  @override
  String get participantsLive => 'LIVE PARTICIPANTS';

  @override
  String get scopa => 'SWEEPER';

  @override
  String get leader => 'LEADER';

  @override
  String get sos => 'SOS';

  @override
  String get speaking => 'IS SPEAKING';

  @override
  String get sosActive => '🚨 SOS ACTIVE';

  @override
  String get assistanceRequested => 'ASSISTANCE REQUESTED';

  @override
  String get none => 'None';

  @override
  String get noParticipants => 'No participants';

  @override
  String get aheadOfLeader =>
      'Warning: you are ahead of the leader, please return to formation.';

  @override
  String get behindSweeper =>
      'Warning: you are behind the sweeper, please return to formation.';

  @override
  String get offRoute =>
      'You are off route. Do you want to start navigation towards the leader?';

  @override
  String turnAlert(int distance, String direction) {
    return 'In $distance meters, turn $direction.';
  }

  @override
  String get rejoinLeader => 'Navigate to Leader';
}
