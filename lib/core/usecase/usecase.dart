import 'package:equatable/equatable.dart';

/// Contract every Domain-layer use case implements. `Type` is the success
/// return type, `Params` the input. Presentation depends only on this
/// interface, never on repositories directly.
abstract interface class UseCase<ReturnType, Params> {
  Future<ReturnType> call(Params params);
}

/// Marker for use cases that take no parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
