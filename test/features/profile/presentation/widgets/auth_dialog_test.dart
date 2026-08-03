import 'package:awaken/core/di/injection.dart';
import 'package:awaken/core/usecase/usecase.dart';
import 'package:awaken/features/profile/domain/usecases/link_with_email.dart';
import 'package:awaken/features/profile/domain/usecases/link_with_google.dart';
import 'package:awaken/features/profile/domain/usecases/send_password_reset_email.dart';
import 'package:awaken/features/profile/domain/usecases/sign_in_with_google.dart';
import 'package:awaken/features/profile/domain/usecases/sign_in_with_password.dart';
import 'package:awaken/features/profile/presentation/widgets/auth_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLinkWithEmail implements LinkWithEmail {
  @override
  Future<void> call({
    required String email,
    required String password,
    String? displayName,
  }) async {}
}

class FakeLinkWithGoogle implements LinkWithGoogle {
  @override
  Future<void> call(NoParams params) async {}
}

class FakeSignInWithPassword implements SignInWithPassword {
  @override
  Future<void> call({
    required String email,
    required String password,
  }) async {}
}

class FakeSignInWithGoogle implements SignInWithGoogle {
  @override
  Future<void> call(NoParams params) async {}
}

class FakeSendPasswordResetEmail implements SendPasswordResetEmail {
  @override
  Future<void> call(String email) async {}
}

void main() {
  setUp(() {
    getIt.reset();
    getIt.registerSingleton<LinkWithEmail>(FakeLinkWithEmail());
    getIt.registerSingleton<LinkWithGoogle>(FakeLinkWithGoogle());
    getIt.registerSingleton<SignInWithPassword>(FakeSignInWithPassword());
    getIt.registerSingleton<SignInWithGoogle>(FakeSignInWithGoogle());
    getIt.registerSingleton<SendPasswordResetEmail>(FakeSendPasswordResetEmail());
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildApp(AuthDialogMode mode) {
    return MaterialApp(
      home: Scaffold(
        body: AuthDialog(mode: mode),
      ),
    );
  }

  testWidgets('renders Sign In mode with header, email/password fields, and tabs', (tester) async {
    await tester.pumpWidget(buildApp(AuthDialogMode.signIn));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsNWidgets(2)); // Tab & Primary Button
    expect(find.text('Save Progress'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('switches to Save Progress mode when tab is tapped', (tester) async {
    await tester.pumpWidget(buildApp(AuthDialogMode.signIn));

    await tester.tap(find.text('Save Progress'));
    await tester.pumpAndSettle();

    expect(find.text('Save Your Progress'), findsOneWidget);
    expect(find.text('Your Name'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
