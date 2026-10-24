
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'http://localhost/nutritrack_api/api';

  static String? token;
  static Map<String, dynamic>? currentUser;

  // Decode JSON responses from the PHP API.
  static Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw const FormatException(
        'Unexpected API response.',
      );
    } on FormatException {
      throw Exception(
        'Invalid response from PHP server '
        '(HTTP ${response.statusCode}). Check your PHP API.',
      );
    }
  }

  // LOGIN
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(
          data['error']?.toString() ?? 'Login failed.',
        );
      }

      final receivedToken = data['token'];
      final receivedUser = data['user'];

      if (receivedToken is! String ||
          receivedUser is! Map) {
        throw Exception(
          'Incomplete login response from PHP.',
        );
      }

      final user = Map<String, dynamic>.from(receivedUser);

      if (user['role'] == null ||
          user['email'] == null ||
          user['id'] == null) {
        throw Exception(
          'User information is incomplete.',
        );
      }

      token = receivedToken;
      currentUser = user;

      return Map<String, dynamic>.from(user);
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception(
        'Cannot connect to the NutriTrack API. '
        'Check XAMPP, the API URL, and your network.',
      );
    }
  }

  // LOGOUT
  static Future<void> logout() async {
    final oldToken = token;

    try {
      if (oldToken != null) {
        await http
            .post(
              Uri.parse('$baseUrl/logout.php'),
              headers: {
                'Authorization': 'Bearer $oldToken',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));
      }
    } finally {
      token = null;
      currentUser = null;
    }
  }

  // ADMIN: CREATE ACCOUNT
  // The new user sets their own password through the email link.
  static Future<Map<String, dynamic>> createUser({
    required String fullName,
    required String email,
    required String phone,
    required String role,
  }) async {
    final currentToken = token;

    if (currentToken == null || currentToken.isEmpty) {
      throw Exception('Please log in again.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/admin/create_user.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $currentToken',
            },
            body: jsonEncode({
              'full_name': fullName.trim(),
              'email': email.trim().toLowerCase(),
              'phone': phone.trim(),
              'role': role.trim().toLowerCase(),
            }),
          )
          .timeout(const Duration(seconds: 35));

      final data = _decodeResponse(response);

      // Only HTTP 201 counts as successful account creation.
      if (response.statusCode != 201) {
        throw Exception(
          data['error']?.toString() ??
              data['message']?.toString() ??
              'Could not create account '
                  '(HTTP ${response.statusCode}).',
        );
      }

      final user = data['user'];

      if (user is! Map) {
        throw Exception(
          'The API reported success but did not return '
          'valid user information.',
        );
      }

      return Map<String, dynamic>.from(user);
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception(
        'Cannot connect to the NutriTrack API. '
        'Check XAMPP, the API URL, and your network.',
      );
    }
  }

  // ADMIN: GET ACCOUNTS FROM DATABASE
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final currentToken = token;

    if (currentToken == null || currentToken.isEmpty) {
      throw Exception('Please log in again.');
    }

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/admin/list_users.php'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $currentToken',
            },
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode != 200) {
        throw Exception(
          data['error']?.toString() ??
              'Could not retrieve accounts '
                  '(HTTP ${response.statusCode}).',
        );
      }

      final usersData = data['users'];

      if (usersData is! List) {
        throw Exception(
          'Invalid users data returned by the PHP API.',
        );
      }

      return usersData
          .whereType<Map>()
          .map(
            (user) => Map<String, dynamic>.from(user),
          )
          .toList();
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception(
        'Cannot connect to the NutriTrack API. '
        'Check XAMPP and the API URL.',
      );
    }
  }

  // AI: GENERATE NUTRITION MEAL PLAN
  static Future<Map<String, dynamic>> generateMealPlan({
    required String ingredients,
    String budget = '',
    int days = 1,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/generate_meal_plan.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'ingredients': ingredients,
              'budget': budget,
              'days': days,
            }),
          )
          .timeout(const Duration(seconds: 100));

      final data = _decodeResponse(response);

      if (response.statusCode != 200 ||
          data['success'] != true) {
        throw Exception(
          data['error']?.toString() ??
              'Could not generate the AI meal plan '
                  '(HTTP ${response.statusCode}).',
        );
      }

      final plan = data['plan'];

      if (plan is! Map) {
        throw Exception(
          'The AI returned an invalid meal-plan format.',
        );
      }

      if (plan['meals'] is! List ||
          plan['exercises'] is! List) {
        throw Exception(
          'The AI meal plan is missing meals or exercises.',
        );
      }

      return Map<String, dynamic>.from(plan);
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception(
        'Cannot connect to the AI meal-plan endpoint. '
        'Check XAMPP and the API URL.',
      );
    }
  }
}
