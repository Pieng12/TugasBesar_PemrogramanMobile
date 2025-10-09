import 'location_model.dart';

class SOSRequest {
  final String id;
  final String requesterId;
  final String title;
  final String description;
  final Location location;
  final DateTime createdAt;
  final SOSStatus status;
  final String? helperId;
  final DateTime? completedAt;
  final int rewardAmount;

  SOSRequest({
    required this.id,
    required this.requesterId,
    required this.title,
    required this.description,
    required this.location,
    required this.createdAt,
    this.status = SOSStatus.active,
    this.helperId,
    this.completedAt,
    this.rewardAmount = 10000,
  });
}

enum SOSStatus {
  active,
  inProgress,
  completed,
  cancelled,
}

class SOSHelper {
  final String id;
  final String sosId;
  final String helperId;
  final DateTime respondedAt;
  final double distance;
  final HelperStatus status;

  SOSHelper({
    required this.id,
    required this.sosId,
    required this.helperId,
    required this.respondedAt,
    required this.distance,
    this.status = HelperStatus.responding,
  });
}

enum HelperStatus {
  responding,
  onTheWay,
  arrived,
  completed,
}
