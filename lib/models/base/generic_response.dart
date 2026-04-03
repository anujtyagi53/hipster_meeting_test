class GenericResponse<T> {
  final String? status;
  final String? message;
  final T? data;

  GenericResponse({this.status, this.message, this.data});

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';

  factory GenericResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return GenericResponse(
      status: json['status'],
      message: json['message'],
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }
}
