import 'package:injectable/injectable.dart';

import '../entities/squad_presence_member.dart';
import '../repositories/squad_repository.dart';

@injectable
class WatchSquadPresence {
  WatchSquadPresence(this._repository);

  final SquadRepository _repository;

  Stream<List<SquadPresenceMember>> call(String squadId) => _repository.watchPresence(squadId);
}
