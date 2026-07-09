import 'package:flutter/material.dart';
import 'branch.dart';

class BranchesData extends ChangeNotifier {
  final List<Branch> _branches = [
    const Branch(id: 'b1', name: 'Main Branch', location: 'Downtown'),
    const Branch(id: 'b2', name: 'Northside Branch', location: 'Uptown'),
  ];

  List<Branch> get branches => List.unmodifiable(_branches);

  void addBranch(Branch branch) {
    _branches.add(branch);
    notifyListeners();
  }

  void removeBranch(String id) {
    _branches.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}

final branchesData = BranchesData();
