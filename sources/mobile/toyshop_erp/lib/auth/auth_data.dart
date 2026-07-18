import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/core.dart';
import '../core/api_config.dart';
import '../core/utils/storage_service.dart';

class AuthRepository {
  const AuthRepository();

  Future<List<Account>> fetchRoster() async {
    final url = ApiConfig.authPublicUsers;
    debugPrint('[AuthRepo] fetchRoster → $url');
    try {
      final response = await http.get(Uri.parse(url));
      debugPrint('[AuthRepo] fetchRoster ← status=${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> usersJson = data['data'];
          final accounts = usersJson
              .map((json) => Account.fromJson(json))
              .where((a) => a.role == UserRole.owner || a.role == UserRole.staff)
              .toList();
          debugPrint('[AuthRepo] fetchRoster found ${accounts.length} accounts');
          return accounts;
        } else {
          debugPrint('[AuthRepo] fetchRoster bad payload: ${response.body.substring(0, 200)}');
        }
      }
      return [];
    } catch (e, st) {
      debugPrint('[AuthRepo] fetchRoster ERROR: $e\n$st');
      return [];
    }
  }

  Future<bool> login(String email, String pin) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pin}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final tokenData = data['data'];
          if (tokenData['accessToken'] != null && tokenData['refreshToken'] != null) {
            await StorageService.saveTokens(
              accessToken: tokenData['accessToken'],
              refreshToken: tokenData['refreshToken'],
            );
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error during login: $e');
      return false;
    }
  }
}

const String kDemoPinHint = 'Enter 4-digit PIN (mapped to password)';
