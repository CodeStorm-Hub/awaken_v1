import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySun;

  /// No description provided for @weekdayFullMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get weekdayFullMonday;

  /// No description provided for @weekdayFullTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get weekdayFullTuesday;

  /// No description provided for @weekdayFullWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get weekdayFullWednesday;

  /// No description provided for @weekdayFullThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get weekdayFullThursday;

  /// No description provided for @weekdayFullFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get weekdayFullFriday;

  /// No description provided for @weekdayFullSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get weekdayFullSaturday;

  /// No description provided for @weekdayFullSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get weekdayFullSunday;

  /// No description provided for @weekdayAbbrMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayAbbrMon;

  /// No description provided for @weekdayAbbrTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayAbbrTue;

  /// No description provided for @weekdayAbbrWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayAbbrWed;

  /// No description provided for @weekdayAbbrThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayAbbrThu;

  /// No description provided for @weekdayAbbrFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayAbbrFri;

  /// No description provided for @weekdayAbbrSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayAbbrSat;

  /// No description provided for @weekdayAbbrSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayAbbrSun;

  /// No description provided for @alarmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get alarmsTitle;

  /// No description provided for @alarmsSubtitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get alarmsSubtitleEmpty;

  /// No description provided for @alarmsSubtitleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 alarm · tap to preview} other{{count} alarms · tap to preview}}'**
  String alarmsSubtitleCount(int count);

  /// No description provided for @alarmReliabilitySettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Alarm reliability settings'**
  String get alarmReliabilitySettingsTooltip;

  /// No description provided for @runSelfTestTooltip.
  ///
  /// In en, this message translates to:
  /// **'Run self-test'**
  String get runSelfTestTooltip;

  /// No description provided for @alarmScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule alarm: {error}'**
  String alarmScheduleFailed(Object error);

  /// No description provided for @alarmScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Alarm scheduled for {time}'**
  String alarmScheduledFor(String time);

  /// No description provided for @alarmUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update alarm: {error}'**
  String alarmUpdateFailed(Object error);

  /// No description provided for @deleteAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete alarm?'**
  String get deleteAlarmTitle;

  /// No description provided for @deleteAlarmBody.
  ///
  /// In en, this message translates to:
  /// **'This alarm will be cancelled and removed from your schedule.'**
  String get deleteAlarmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @alarmDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete alarm: {error}'**
  String alarmDeleteFailed(Object error);

  /// No description provided for @alarmDeleted.
  ///
  /// In en, this message translates to:
  /// **'Alarm deleted'**
  String get alarmDeleted;

  /// No description provided for @noAlarmsScheduled.
  ///
  /// In en, this message translates to:
  /// **'No alarms scheduled'**
  String get noAlarmsScheduled;

  /// No description provided for @noAlarmsScheduledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule one and earn tomorrow morning.'**
  String get noAlarmsScheduledSubtitle;

  /// No description provided for @addAlarmSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Add alarm'**
  String get addAlarmSemanticLabel;

  /// No description provided for @alarmOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get alarmOneTime;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @squats.
  ///
  /// In en, this message translates to:
  /// **'squats'**
  String get squats;

  /// No description provided for @pushUps.
  ///
  /// In en, this message translates to:
  /// **'push-ups'**
  String get pushUps;

  /// No description provided for @alarmCardSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{time}, {reps} {exercise}, {recurrence}, alarm {onOff}'**
  String alarmCardSemanticLabel(
    String time,
    int reps,
    String exercise,
    String recurrence,
    String onOff,
  );

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get off;

  /// No description provided for @repsExercise.
  ///
  /// In en, this message translates to:
  /// **'{reps} {exercise}'**
  String repsExercise(int reps, String exercise);

  /// No description provided for @deleteAlarmTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete alarm'**
  String get deleteAlarmTooltip;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @addAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Alarm'**
  String get addAlarmTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @squatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Squats'**
  String get squatsLabel;

  /// No description provided for @pushUpsLabel.
  ///
  /// In en, this message translates to:
  /// **'Push-ups'**
  String get pushUpsLabel;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @weekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// No description provided for @alarmOn.
  ///
  /// In en, this message translates to:
  /// **'Alarm on'**
  String get alarmOn;

  /// No description provided for @alarmOff.
  ///
  /// In en, this message translates to:
  /// **'Alarm off'**
  String get alarmOff;

  /// No description provided for @alarmTargetSummaryUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'Alarm set for {day} at {time} (in < 1 min)'**
  String alarmTargetSummaryUnderMinute(String day, String time);

  /// No description provided for @alarmTargetSummaryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Alarm set for {day} at {time} (in {minutes} mins)'**
  String alarmTargetSummaryMinutes(String day, String time, int minutes);

  /// No description provided for @alarmTargetSummaryHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'Alarm set for {day} at {time} (in {hours}h {minutes}m)'**
  String alarmTargetSummaryHoursMinutes(
    String day,
    String time,
    int hours,
    int minutes,
  );

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get tomorrow;

  /// No description provided for @timeToSquat.
  ///
  /// In en, this message translates to:
  /// **'Time to squat!'**
  String get timeToSquat;

  /// No description provided for @timeToPushUp.
  ///
  /// In en, this message translates to:
  /// **'Time to push up!'**
  String get timeToPushUp;

  /// No description provided for @repsToDismiss.
  ///
  /// In en, this message translates to:
  /// **'reps to dismiss'**
  String get repsToDismiss;

  /// No description provided for @wakeUpTaxApplied.
  ///
  /// In en, this message translates to:
  /// **'Wake-up tax applied (×{multiplier})'**
  String wakeUpTaxApplied(String multiplier);

  /// No description provided for @startWorkoutToDismiss.
  ///
  /// In en, this message translates to:
  /// **'Start workout to dismiss'**
  String get startWorkoutToDismiss;

  /// No description provided for @openingCamera.
  ///
  /// In en, this message translates to:
  /// **'Opening camera…'**
  String get openingCamera;

  /// No description provided for @alarmReliabilitySelfTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm reliability self-test'**
  String get alarmReliabilitySelfTestTitle;

  /// No description provided for @alarmReliabilitySelfTestBody.
  ///
  /// In en, this message translates to:
  /// **'This schedules a test alarm {seconds} seconds from now, with a 1-rep squat requirement. For a real test of OEM battery killers, start it, then lock your screen and, ideally, swipe Awaken away from the recent-apps list. The alarm should still fire.'**
  String alarmReliabilitySelfTestBody(int seconds);

  /// No description provided for @testRunning.
  ///
  /// In en, this message translates to:
  /// **'Test running…'**
  String get testRunning;

  /// No description provided for @runAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get runAgain;

  /// No description provided for @startTest.
  ///
  /// In en, this message translates to:
  /// **'Start test'**
  String get startTest;

  /// No description provided for @reliabilityTestNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started.'**
  String get reliabilityTestNotStarted;

  /// No description provided for @reliabilityTestWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for alarm…'**
  String get reliabilityTestWaiting;

  /// No description provided for @reliabilityTestPassed.
  ///
  /// In en, this message translates to:
  /// **'PASS — fired {seconds}s after the scheduled time.'**
  String reliabilityTestPassed(int seconds);

  /// No description provided for @reliabilityTestFailed.
  ///
  /// In en, this message translates to:
  /// **'FAIL — alarm did not fire within the expected window. Check battery-exemption settings and OEM autostart permissions.'**
  String get reliabilityTestFailed;

  /// No description provided for @alarmDismissed.
  ///
  /// In en, this message translates to:
  /// **'Alarm dismissed!'**
  String get alarmDismissed;

  /// No description provided for @alarmDismissedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nice work — that\'s how mornings are won.'**
  String get alarmDismissedSubtitle;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get dayStreak;

  /// No description provided for @nice.
  ///
  /// In en, this message translates to:
  /// **'Nice!'**
  String get nice;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
