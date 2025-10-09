import 'location_model.dart';

class JobModel {
  final String id;
  final String customerId;
  final String title;
  final String description;
  final JobCategory category;
  final double price;
  final Location location;
  final DateTime createdAt;
  final DateTime? scheduledTime;
  final JobStatus status;
  final String? assignedWorkerId;
  final List<String> applicantIds;
  final List<String> imageUrls;
  final Map<String, dynamic>? additionalInfo;

  JobModel({
    required this.id,
    required this.customerId,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.location,
    required this.createdAt,
    this.scheduledTime,
    this.status = JobStatus.pending,
    this.assignedWorkerId,
    this.applicantIds = const [],
    this.imageUrls = const [],
    this.additionalInfo,
  });
}

enum JobCategory {
  cleaning,
  maintenance,
  delivery,
  tutoring,
  photography,
  cooking,
  gardening,
  petCare,
  other,
}

enum JobStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  disputed,
}

class JobApplication {
  final String id;
  final String jobId;
  final String workerId;
  final String message;
  final double proposedPrice;
  final DateTime appliedAt;
  final ApplicationStatus status;

  JobApplication({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.message,
    required this.proposedPrice,
    required this.appliedAt,
    this.status = ApplicationStatus.pending,
  });
}

enum ApplicationStatus {
  pending,
  accepted,
  rejected,
}
