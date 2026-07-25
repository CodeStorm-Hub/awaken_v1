import 'package:equatable/equatable.dart';

class Squad extends Equatable {
  const Squad({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;

  @override
  List<Object?> get props => [id, name, inviteCode, ownerId];
}
