import 'package:awaken/features/alarm/domain/entities/alarm_schedule.dart';
import 'package:awaken/features/alarm/presentation/bloc/alarm_cubit.dart';
import 'package:awaken/features/alarm/presentation/bloc/alarm_state.dart';
import 'package:awaken/features/alarm/presentation/pages/alarm_list_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeAlarmCubit extends MockCubit<AlarmState> implements AlarmCubit {}

void main() {
  late _FakeAlarmCubit cubit;

  setUp(() {
    cubit = _FakeAlarmCubit();
  });

  Widget wrap(Widget child) => MaterialApp(
        home: BlocProvider<AlarmCubit>.value(value: cubit, child: child),
      );

  testWidgets('shows empty state with no alarms', (tester) async {
    when(() => cubit.state).thenReturn(const AlarmState());

    await tester.pumpWidget(wrap(const AlarmListPage()));

    expect(find.text('No alarms scheduled'), findsOneWidget);
  });

  testWidgets('shows a scheduled alarm', (tester) async {
    final alarm = AlarmSchedule(
      id: 'test-id',
      scheduledTime: DateTime(2026, 1, 1, 7),
      exerciseMode: ExerciseMode.squat,
      requiredReps: 20,
    );
    when(() => cubit.state).thenReturn(AlarmState(alarms: [alarm]));

    await tester.pumpWidget(wrap(const AlarmListPage()));

    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('20 squats'), findsOneWidget);
    expect(find.text('One-time'), findsOneWidget);
  });
}
