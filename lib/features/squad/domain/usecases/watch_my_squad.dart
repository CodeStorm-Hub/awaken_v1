import 'package:injectable/injectable.dart';

import '../entities/squad.dart';
import '../repositories/squad_repository.dart';

@injectable
class WatchMySquad {
  WatchMySquad(this._repository);

  final SquadRepository _repository;

  Stream<Squad?> call() => _repository.watchMySquad();
}
