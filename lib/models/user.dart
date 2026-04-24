class User {
  final int id;
  final String fullName;
  final String email;
  final String phoneNumber;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] ?? json['id'],
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
    );
  }
}

