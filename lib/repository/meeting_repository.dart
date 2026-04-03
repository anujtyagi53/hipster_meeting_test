import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:hipster_meeting_test/models/base/generic_response.dart';
import 'package:hipster_meeting_test/models/meeting_data_model.dart';
import 'package:hipster_meeting_test/network/api_client.dart';
import 'package:hipster_meeting_test/network/api_endpoints.dart';
import 'package:hipster_meeting_test/network/errors/failures.dart';
import 'package:hipster_meeting_test/utils/app_logger.dart';

class MeetingRepository {
  final ApiClient _apiClient = Get.find<ApiClient>();

  /// Creates a new meeting and returns agent's join token
  Future<Either<Failure, MeetingDataModel>> createMeeting() async {
    try {
      // Send as both query params and JSON body for API compatibility
      final response = await _apiClient.postRequest(
        ApiEndpoints.meetingsApi,
        data: {'type': 'agent'},
        queryParameters: {'type': 'agent'},
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      return Left(ServerFailure(message: _extractErrorMessage(e), errorResponse: e.response?.data));
    } catch (e) {
      AppLogger.error('createMeeting error', tag: 'REPO', error: e);
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Gets client attendee token for an existing meeting
  Future<Either<Failure, MeetingDataModel>> getClientToken(String meetingId) async {
    try {
      final response = await _apiClient.postRequest(
        ApiEndpoints.meetingsApi,
        data: {'type': 'client', 'meeting_id': meetingId},
        queryParameters: {'type': 'client', 'meeting_id': meetingId},
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e),
        errorResponse: e.response?.data,
      ));
    } catch (e) {
      AppLogger.error('getClientToken error', tag: 'REPO', error: e);
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Gets agent attendee token for an existing meeting (rejoin)
  Future<Either<Failure, MeetingDataModel>> getAgentToken(String meetingId) async {
    try {
      final response = await _apiClient.postRequest(
        ApiEndpoints.meetingsApi,
        data: {'type': 'agent', 'meeting_id': meetingId},
        queryParameters: {'type': 'agent', 'meeting_id': meetingId},
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      return Left(ServerFailure(
        message: _extractErrorMessage(e),
        errorResponse: e.response?.data,
      ));
    } catch (e) {
      AppLogger.error('getAgentToken error', tag: 'REPO', error: e);
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  Either<Failure, MeetingDataModel> _handleResponse(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final parsed = GenericResponse<MeetingDataModel>.fromJson(
        data,
        (d) => MeetingDataModel.fromJson(d),
      );

      if (parsed.isSuccess && parsed.data != null) {
        return Right(parsed.data!);
      }

      // Server returned error status — extract user-friendly message
      final serverMsg = parsed.message ?? '';
      return Left(ServerFailure(
        message: _parseServerError(serverMsg, response.statusCode),
        errorResponse: data,
      ));
    }
    return Left(ServerFailure(message: 'Unexpected response from server.'));
  }

  String _parseServerError(String serverMsg, int? statusCode) {
    if (serverMsg.contains('NotFoundException') || serverMsg.contains('not found')) {
      return 'Meeting not found or has expired. Please create a new meeting.';
    }
    if (serverMsg.contains('LimitExceededException')) {
      return 'Meeting capacity reached. Please try again later.';
    }
    if (serverMsg.contains('UnauthorizedException') || serverMsg.contains('Forbidden')) {
      return 'You are not authorized to join this meeting.';
    }
    if (serverMsg.contains('ServiceUnavailableException')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    if (serverMsg.isNotEmpty && serverMsg.length < 100) {
      return serverMsg;
    }

    // Fallback based on status code
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
      case 403:
        return 'You are not authorized to perform this action.';
      case 404:
        return 'Meeting not found. Please check the Meeting ID.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    final serverMsg = (data is Map) ? data['message'] as String? : null;

    if (serverMsg != null) {
      return _parseServerError(serverMsg, e.response?.statusCode);
    }

    // Handle connection errors
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your network.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your network.';
      default:
        return _parseServerError('', e.response?.statusCode);
    }
  }
}
