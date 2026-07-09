import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/models/branch.dart';
import '../../core/models/branches_data.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  void _addBranch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddBranchSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: branchesData,
      builder: (context, _) {
        final branches = branchesData.branches;
        return AppScaffold(
          title: 'Branches Management',
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _addBranch,
            ),
          ],
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final branch = branches[index];
              return AppCard(
                child: ListTile(
                  leading: const Icon(Icons.store_rounded),
                  title: Text(branch.name),
                  subtitle: Text(branch.location),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: () => branchesData.removeBranch(branch.id),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AddBranchSheet extends StatefulWidget {
  const _AddBranchSheet();

  @override
  State<_AddBranchSheet> createState() => _AddBranchSheetState();
}

class _AddBranchSheetState extends State<_AddBranchSheet> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty) return;
    
    final newBranch = Branch(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
    );
    branchesData.addBranch(newBranch);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Branch', style: AppType.title),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Branch Name', hintText: 'e.g. Southside Branch'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. Suburbs'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('Save Branch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
