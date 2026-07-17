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
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Branch'),
                          content: const Text('Are you sure you want to delete this branch?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await branchesData.removeBranch(branch.id);
                      }
                    },
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

  bool _busy = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty) return;
    
    setState(() => _busy = true);
    final newBranch = Branch(
      id: '', // Backend assigns ID
      name: _nameCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
    );
    try {
      await branchesData.addBranch(newBranch);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add branch: $e')));
        setState(() => _busy = false);
      }
    }
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
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving...' : 'Save Branch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
