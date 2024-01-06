
import 'package:flutter/material.dart';
import 'package:graphite/core/typings.dart';
import 'package:graphite/graphite.dart';

class DiagramArea extends StatelessWidget {
  const DiagramArea({
    super.key,
    required this.list,
  });

  final List<NodeInput> list;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewer(
          constrained: false,
          child: DirectGraph(
            list: list,
            defaultCellSize: const Size(100.0, 100.0),
            cellPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 30),
            contactEdgesDistance: 10.0,
            orientation: MatrixOrientation.Horizontal,
            edgeLabels: EdgeLabels(
              alignment: EdgeLabelTextAlignment.after,
              positionPriority: EdgeLabelPositionPriority.horizontal,
              builder: (context, edge, isVertical) => const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.filter_list_outlined),
              ),
            ),
            centered: true,
            minScale: .1,
            maxScale: 1,
          ),
        ),
      ],
    );
  }
}
