import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StageTile extends StatelessWidget {
  final String name;
  final String? description;
  final void Function()? onEdit;
  const StageTile({super.key, required this.name, this.description, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.grey.shade100,
      title: Wrap(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),),
          const SizedBox(width: 6,),
          InkWell(
            onTap: onEdit,
            child: const Icon(Icons.edit, size: 18, color: Colors.blue,),
          ),
        ],
      ),
      leading: Tooltip(
        message: description != null && description!.isNotEmpty ? description! : 'No description available',
        child: const Icon(Icons.info),
      ),
    );
  }

}
