import 'package:flutter/material.dart';

class StageTile extends StatelessWidget {
  final String name;
  final String? description;
  const StageTile({super.key, required this.name, this.description});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.grey.shade50,
      title: Text(name,),
      leading: Tooltip(
        message: description != null && description!.isNotEmpty ? description! : 'No description available',
        child: const Icon(Icons.info),
      ),
    );
  }

}
