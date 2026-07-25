import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/watch_current_user.dart';
import '../pages/profile_page.dart';

/// The top-right profile avatar shown on Home/Alarms/Territory/Squad.
/// Wraps [ProfileAvatarButton] with live auth state so it shows the
/// signed-in user's real Google photo/initial instead of a hardcoded 'G'
/// regardless of whether anyone's actually linked an account.
class CurrentUserAvatarButton extends StatelessWidget {
  const CurrentUserAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: getIt<WatchCurrentUser>()(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isAnonymous = user?.isAnonymous ?? true;
        final label = user?.displayName ?? user?.email;
        final initial = isAnonymous ? 'G' : (label ?? 'A')[0].toUpperCase();
        return ProfileAvatarButton(
          initial: initial,
          avatarUrl: isAnonymous ? null : user?.avatarUrl,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
        );
      },
    );
  }
}
