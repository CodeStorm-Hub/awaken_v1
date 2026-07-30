import 'package:awaken/features/alarm/domain/usecases/watch_current_streak.dart';
import 'package:awaken/features/profile/domain/entities/app_user.dart';
import 'package:awaken/features/profile/domain/usecases/watch_current_user.dart';
import 'package:awaken/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:awaken/features/profile/presentation/bloc/profile_state.dart';
import 'package:awaken/features/territory/domain/usecases/watch_owned_area.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchCurrentStreak extends Mock implements WatchCurrentStreak {}

class _MockWatchOwnedArea extends Mock implements WatchOwnedArea {}

class _MockWatchCurrentUser extends Mock implements WatchCurrentUser {}

void main() {
  late _MockWatchCurrentStreak watchCurrentStreak;
  late _MockWatchOwnedArea watchOwnedArea;
  late _MockWatchCurrentUser watchCurrentUser;

  const user = AppUser(id: 'user-1', isAnonymous: false, displayName: 'You');

  setUp(() {
    watchCurrentStreak = _MockWatchCurrentStreak();
    watchOwnedArea = _MockWatchOwnedArea();
    watchCurrentUser = _MockWatchCurrentUser();
  });

  ProfileCubit buildCubit() =>
      ProfileCubit(watchCurrentStreak, watchOwnedArea, watchCurrentUser);

  blocTest<ProfileCubit, ProfileState>(
    'combines streak/area/user streams into one state, independently',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => Stream.value(5));
      when(() => watchOwnedArea()).thenAnswer((_) => Stream.value(123.4));
      when(() => watchCurrentUser()).thenAnswer((_) => Stream.value(user));
    },
    build: buildCubit,
    expect: () => [
      isA<ProfileState>().having((s) => s.streak, 'streak', 5),
      isA<ProfileState>().having((s) => s.ownedAreaSqm, 'ownedAreaSqm', 123.4),
      isA<ProfileState>().having((s) => s.user, 'user', user),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'a failed streak stream sets streakError without disturbing area/user',
    setUp: () {
      when(
        () => watchCurrentStreak(),
      ).thenAnswer((_) => Stream.error(Exception('boom')));
      when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
      when(() => watchCurrentUser()).thenAnswer((_) => const Stream.empty());
    },
    build: buildCubit,
    expect: () => [
      isA<ProfileState>()
          .having((s) => s.streakError, 'streakError', true)
          .having((s) => s.streak, 'streak', 0),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'a failed area stream sets ownedAreaError without disturbing streak/user',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchOwnedArea(),
      ).thenAnswer((_) => Stream.error(Exception('boom')));
      when(() => watchCurrentUser()).thenAnswer((_) => const Stream.empty());
    },
    build: buildCubit,
    expect: () => [
      isA<ProfileState>().having(
        (s) => s.ownedAreaError,
        'ownedAreaError',
        true,
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'a null user emission clears the current user',
    setUp: () {
      when(() => watchCurrentStreak()).thenAnswer((_) => const Stream.empty());
      when(() => watchOwnedArea()).thenAnswer((_) => const Stream.empty());
      when(
        () => watchCurrentUser(),
      ).thenAnswer((_) => Stream.fromIterable([user, null]));
    },
    build: buildCubit,
    expect: () => [
      isA<ProfileState>().having((s) => s.user, 'user', user),
      isA<ProfileState>().having((s) => s.user, 'user', isNull),
    ],
  );
}
