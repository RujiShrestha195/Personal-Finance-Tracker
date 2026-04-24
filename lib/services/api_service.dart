import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction.dart';
import '../models/goal.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
  // For iOS simulator use: 'http://localhost:5000'
  // For web/Windows desktop use: 'http://localhost:5000'
  // For physical device use your computer's IP: 'http://192.168.x.x:5000'

  // Authentication
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
        'confirmPassword': confirmPassword,
      })
    );
    final data = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Registration failed: ${response.statusCode}');
    }
    return data;
  }
  static Future<Map<String, dynamic>> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email_or_phone': emailOrPhone,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Login failed');
    }
    return data;
  }
  static Future<Map<String, dynamic>> getSummary(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/summary/$userId'));
    return jsonDecode(response.body);
  }
  // Transactions
  static Future<List<Transaction>> getRecentTransactions(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/recent/$userId'),
    );
    final data = jsonDecode(response.body);
    return (data['transactions'] as List)
        .map((json) => Transaction.fromJson(json))
        .toList();
  }
  static Future<Map<String, dynamic>> addTransaction(Transaction transaction) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(transaction.toJson()),
    );
    return jsonDecode(response.body);
  }
  static Future<Map<String, dynamic>> updateTransaction(
    int transactionId,
    Map<String, dynamic> updates,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/transactions/$transactionId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    return jsonDecode(response.body);
  }

  // Goals
  static Future<List<Goal>> getUserGoals(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/goals/user/$userId'),
    );
    final data = jsonDecode(response.body);
    return (data['goals'] as List)
        .map((json) => Goal.fromJson(json))
        .toList();
  }

  static Future<Map<String, dynamic>> createGoal(Goal goal) async {
    final response = await http.post(
      Uri.parse('$baseUrl/goals'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(goal.toJson()),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateGoal(
    int goalId,
    Map<String, dynamic> updates,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/goals/$goalId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteGoal(int goalId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/goals/$goalId'),
    );

    return jsonDecode(response.body);
  }

  // Profile
  static Future<Map<String, dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> updates,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/profile/update/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updates),
    );

    return jsonDecode(response.body);
  }
}
