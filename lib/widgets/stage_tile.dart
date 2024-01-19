import 'package:flutter/material.dart';

class StageTile extends StatelessWidget {
  final String name;
  final String? description;
  final void Function()? onEdit;
  const StageTile({super.key, required this.name, this.description, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: description != null && description!.isNotEmpty ? description! : 'No description available',
            child: const Icon(Icons.info),
          ),
          const SizedBox(width: 6,),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),),
          const SizedBox(width: 6,),
          InkWell(
            onTap: onEdit,
            child: const Icon(Icons.edit, size: 18, color: Colors.blue,),
          ),
        ],
      ),
    );
  }

}
