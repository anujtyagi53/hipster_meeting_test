abstract class Failure {
  final String message;
  final dynamic errorResponse;

  const Failure({required this.message, this.errorResponse});

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.errorResponse});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection. Please check your network.'});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({super.message = 'Request timed out. Please try again.'});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Something went wrong. Please try again.'});
}
