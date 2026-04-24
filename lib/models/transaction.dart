class Transaction {
  final int? id;
  final int userId;
  final String type; // 'Income' or 'Expense'
  final double amount;
  final String category;
  final DateTime date;
  final String? description;
  final String transactionType; // 'Cash' or 'Online'

  Transaction({
    this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    required this.transactionType,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      date: DateTime.parse(json['date']),
      description: json['description'],
      transactionType: json['transaction_type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String().split('T')[0],
      'description': description ?? '',
      'transaction_type': transactionType,
    };
  }
}

