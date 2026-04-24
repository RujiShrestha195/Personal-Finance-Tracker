class Goal {
  final int? id;
  final int userId;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime targetDate;
  final String? description;
  final bool isReached;

  Goal({
    this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    this.description,
    required this.isReached,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      savedAmount: (json['saved_amount'] ?? 0).toDouble(),
      targetDate: DateTime.parse(json['target_date']),
      description: json['description'],
      isReached: json['is_reached'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'saved_amount': savedAmount,
      'target_date': targetDate.toIso8601String().split('T')[0],
      'description': description ?? '',
      'is_reached': isReached,
    };
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (savedAmount / targetAmount * 100).clamp(0, 100);
  }
}

