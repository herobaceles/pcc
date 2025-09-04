import 'package:flutter/material.dart';
import '../models/branch.dart';

class BranchList extends StatelessWidget {
  final List<Branch> branches;
  final ValueChanged<Branch> onSelect;

  const BranchList({super.key, required this.branches, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const Center(child: Text("No branches found."));
    }

    return ListView.builder(
      itemCount: branches.length,
      itemBuilder: (context, i) {
        final branch = branches[i];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.red),
          title: Text(branch.name),
          subtitle: Text(branch.address),
          onTap: () => onSelect(branch),
        );
      },
    );
  }
}
