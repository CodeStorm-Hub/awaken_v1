// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get weekdayMon => 'M';

  @override
  String get weekdayTue => 'T';

  @override
  String get weekdayWed => 'W';

  @override
  String get weekdayThu => 'T';

  @override
  String get weekdayFri => 'F';

  @override
  String get weekdaySat => 'S';

  @override
  String get weekdaySun => 'S';

  @override
  String get weekdayFullMonday => 'Monday';

  @override
  String get weekdayFullTuesday => 'Tuesday';

  @override
  String get weekdayFullWednesday => 'Wednesday';

  @override
  String get weekdayFullThursday => 'Thursday';

  @override
  String get weekdayFullFriday => 'Friday';

  @override
  String get weekdayFullSaturday => 'Saturday';

  @override
  String get weekdayFullSunday => 'Sunday';

  @override
  String get weekdayAbbrMon => 'Mon';

  @override
  String get weekdayAbbrTue => 'Tue';

  @override
  String get weekdayAbbrWed => 'Wed';

  @override
  String get weekdayAbbrThu => 'Thu';

  @override
  String get weekdayAbbrFri => 'Fri';

  @override
  String get weekdayAbbrSat => 'Sat';

  @override
  String get weekdayAbbrSun => 'Sun';

  @override
  String get alarmsTitle => 'Alarms';

  @override
  String get alarmsSubtitleEmpty => 'Nothing scheduled';

  @override
  String alarmsSubtitleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alarms · tap to preview',
      one: '1 alarm · tap to preview',
    );
    return '$_temp0';
  }

  @override
  String get alarmReliabilitySettingsTooltip => 'Alarm reliability settings';

  @override
  String get runSelfTestTooltip => 'Run self-test';

  @override
  String alarmScheduleFailed(Object error) {
    return 'Could not schedule alarm: $error';
  }

  @override
  String alarmScheduledFor(String time) {
    return 'Alarm scheduled for $time';
  }

  @override
  String alarmUpdateFailed(Object error) {
    return 'Could not update alarm: $error';
  }

  @override
  String get deleteAlarmTitle => 'Delete alarm?';

  @override
  String get deleteAlarmBody =>
      'This alarm will be cancelled and removed from your schedule.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String alarmDeleteFailed(Object error) {
    return 'Could not delete alarm: $error';
  }

  @override
  String get alarmDeleted => 'Alarm deleted';

  @override
  String get noAlarmsScheduled => 'No alarms scheduled';

  @override
  String get noAlarmsScheduledSubtitle =>
      'Schedule one and earn tomorrow morning.';

  @override
  String get addAlarmSemanticLabel => 'Add alarm';

  @override
  String get alarmOneTime => 'One-time';

  @override
  String get everyDay => 'Every day';

  @override
  String get squats => 'squats';

  @override
  String get pushUps => 'push-ups';

  @override
  String alarmCardSemanticLabel(
    String time,
    int reps,
    String exercise,
    String recurrence,
    String onOff,
  ) {
    return '$time, $reps $exercise, $recurrence, alarm $onOff';
  }

  @override
  String get on => 'on';

  @override
  String get off => 'off';

  @override
  String repsExercise(int reps, String exercise) {
    return '$reps $exercise';
  }

  @override
  String get deleteAlarmTooltip => 'Delete alarm';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get addAlarmTitle => 'Add Alarm';

  @override
  String get save => 'Save';

  @override
  String get exercise => 'Exercise';

  @override
  String get squatsLabel => 'Squats';

  @override
  String get pushUpsLabel => 'Push-ups';

  @override
  String get reps => 'Reps';

  @override
  String get repeat => 'Repeat';

  @override
  String get never => 'Never';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekends => 'Weekends';

  @override
  String get alarmOn => 'Alarm on';

  @override
  String get alarmOff => 'Alarm off';

  @override
  String alarmTargetSummaryUnderMinute(String day, String time) {
    return 'Alarm set for $day at $time (in < 1 min)';
  }

  @override
  String alarmTargetSummaryMinutes(String day, String time, int minutes) {
    return 'Alarm set for $day at $time (in $minutes mins)';
  }

  @override
  String alarmTargetSummaryHoursMinutes(
    String day,
    String time,
    int hours,
    int minutes,
  ) {
    return 'Alarm set for $day at $time (in ${hours}h ${minutes}m)';
  }

  @override
  String get today => 'today';

  @override
  String get tomorrow => 'tomorrow';

  @override
  String get timeToSquat => 'Time to squat!';

  @override
  String get timeToPushUp => 'Time to push up!';

  @override
  String get repsToDismiss => 'reps to dismiss';

  @override
  String wakeUpTaxApplied(String multiplier) {
    return 'Wake-up tax applied (×$multiplier)';
  }

  @override
  String get startWorkoutToDismiss => 'Start workout to dismiss';

  @override
  String get openingCamera => 'Opening camera…';

  @override
  String get alarmReliabilitySelfTestTitle => 'Alarm reliability self-test';

  @override
  String alarmReliabilitySelfTestBody(int seconds) {
    return 'This schedules a test alarm $seconds seconds from now, with a 1-rep squat requirement. For a real test of OEM battery killers, start it, then lock your screen and, ideally, swipe Awaken away from the recent-apps list. The alarm should still fire.';
  }

  @override
  String get testRunning => 'Test running…';

  @override
  String get runAgain => 'Run again';

  @override
  String get startTest => 'Start test';

  @override
  String get reliabilityTestNotStarted => 'Not started.';

  @override
  String get reliabilityTestWaiting => 'Waiting for alarm…';

  @override
  String reliabilityTestPassed(int seconds) {
    return 'PASS — fired ${seconds}s after the scheduled time.';
  }

  @override
  String get reliabilityTestFailed =>
      'FAIL — alarm did not fire within the expected window. Check battery-exemption settings and OEM autostart permissions.';

  @override
  String get alarmDismissed => 'Alarm dismissed!';

  @override
  String get alarmDismissedSubtitle =>
      'Nice work — that\'s how mornings are won.';

  @override
  String get dayStreak => 'day streak';

  @override
  String get nice => 'Nice!';
}
