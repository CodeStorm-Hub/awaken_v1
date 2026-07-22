import 'package:injectable/injectable.dart';

import '../entities/squad.dart';
import '../repositories/squad_repository.dart';

@injectable
class JoinSquad {
  JoinSquad(this._repository);

  final SquadRepository _repository;

  Future<Squad> call(String inviteCode) => _repository.joinSquad(inviteCode);
}
