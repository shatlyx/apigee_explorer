import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/widgets/diagram_step.dart';
import 'package:apigee_explorer/widgets/endpoint_tile.dart';
import 'package:flutter/material.dart';
import 'package:petitparser/petitparser.dart';

class FlowDiagram extends StatelessWidget {
  final String name;
  final internal.Phase phase;
  final Result<dynamic>? condition;
  final List<internal.FlowStep>? steps;
  const FlowDiagram({super.key, required this.name, required this.phase, this.steps, this.condition,});

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
          header: phase == internal.Phase.response ? null : _header(),
          footer: phase == internal.Phase.response ? _header() : null,
          children: steps == null
              ? []
              : getOrderedSteps().map((step) => DiagramStep(step: step, key: Key(step.internalId),)).toList(),
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
      ),
      leading: phase == internal.Phase.response ? const Icon(Icons.arrow_upward) : const Icon(Icons.arrow_downward),
      trailing: Icon(Icons.more_vert),
    );
  }

  Iterable<internal.FlowStep> getOrderedSteps() {
    if (phase == internal.Phase.response) {
      return steps!.reversed;
    }
    return steps!;
  }
}
