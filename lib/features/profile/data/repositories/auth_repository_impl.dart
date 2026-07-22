import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  AppUser _toAppUser(supabase.User user) =>
      AppUser(id: user.id, isAnonymous: user.isAnonymous);

  @override
  AppUser? get currentUser {
    final user = _remote.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Stream<AppUser?> get userChanges =>
      _remote.userChanges.map((user) => user == null ? null : _toAppUser(user));

  @override
  Future<AppUser> ensureSession() async {
    final existing = _remote.currentUser;
    if (existing != null) return _toAppUser(existing);

    final user = await _remote.signInAnonymously();
    return _toAppUser(user);
  }

  @override
  Future<void> linkWithEmail({required String email, required String password}) =>
      _remote.linkWithEmail(email: email, password: password);

  @override
  Future<void> linkWithGoogle() => _remote.linkWithGoogle();

  @override
  Future<void> signOut() => _remote.signOut();

  @override
  Future<void> deleteAccount() async {
    await _remote.deleteAccount();
    await _remote.signOut();
  }
}
