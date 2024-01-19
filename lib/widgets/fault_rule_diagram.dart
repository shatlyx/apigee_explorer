import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/widgets/diagram_step.dart';
import 'package:apigee_explorer/widgets/endpoint_tile.dart';
import 'package:flutter/material.dart';
import 'package:petitparser/petitparser.dart';

class FaultRuleDiagram extends StatelessWidget {
  final String name;
  final Result<dynamic>? condition;
  final List<internal.FlowStep>? steps;
  const FaultRuleDiagram({super.key, required this.name, this.steps, this.condition,});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: Colors.blueAccent)
        ),
        child: ReorderableListView(
          shrinkWrap: true,
          scrollDirection: Axis.vertical,
          onReorder: (oldIndex, newIndex) {

          },
          footer: _header(),
          children: steps == null
              ? []
              : steps!.reversed.map((step) => DiagramStep(step: step, key: Key(step.internalId),)).toList(),
        ),
      ),
    );
  }

  Widget _header() {
    return ListTile(
      tileColor: Colors.grey.shade100,
      title: EndpointTile(
        name: name,
        condition: condition,
        showVerbBadge: false,
      ),
      leading: const Icon(Icons.arrow_upward),
      trailing: const Icon(Icons.more_vert),
    );
  }

}
