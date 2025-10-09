class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String profileImage;
  final UserType userType;
  final double rating;
  final int completedJobs;
  final int totalEarnings;
  final List<UserBadge> badges;
  final bool isVerified;
  final DateTime joinDate;
  final UserLocation? currentLocation;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImage,
    required this.userType,
    this.rating = 0.0,
    this.completedJobs = 0,
    this.totalEarnings = 0,
    this.badges = const [],
    this.isVerified = false,
    required this.joinDate,
    this.currentLocation,
  });
}

enum UserType {
  customer,
  worker,
  both,
}

class UserBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeType type;
  final DateTime? earnedDate;

  UserBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    this.earnedDate,
  });
}

enum BadgeType {
  reliability,
  speed,
  quality,
  helpfulness,
  emergency,
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String address;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}
