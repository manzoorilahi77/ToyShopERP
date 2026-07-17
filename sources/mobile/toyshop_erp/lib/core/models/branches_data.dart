import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../utils/storage_service.dart';
import 'branch.dart';

class BranchesData extends ChangeNotifier {
  List<Branch> _branches = [];
  bool _isLoading = false;

  List<Branch> get branches => List.unmodifiable(_branches);
  bool get isLoading => _isLoading;

  BranchesData() {
    fetchBranches();
  }

  Future<void> fetchBranches() async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = await StorageService.getAccessToken();
      final response = await http.get(
        Uri.parse(ApiConfig.branches),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _branches = (data['data'] as List)
              .map((b) => Branch(
                    id: b['id'].toString(),
                    name: b['name'] ?? 'Unknown',
                    location: b['location'] ?? 'Unknown',
                  ))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching branches: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBranch(Branch branch) async {
    final token = await StorageService.getAccessToken();
    final res = await http.post(
      Uri.parse(ApiConfig.branches),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': branch.name,
        'location': branch.location,
      }),
    );
    if (res.statusCode == 201) {
      await fetchBranches();
    }
  }

  Future<void> removeBranch(String id) async {
    final token = await StorageService.getAccessToken();
    final res = await http.delete(
      Uri.parse('${ApiConfig.branches}/$id'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200 || res.statusCode == 204) {
      await fetchBranches();
    }
  }
}

final branchesData = BranchesData();
