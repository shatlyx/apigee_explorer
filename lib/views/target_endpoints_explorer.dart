import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/utils/constants.dart';
import 'package:apigee_explorer/widgets/endpoint_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../model/tree_node.dart';
import '../widgets/stage_tile.dart';
import '../widgets/tree_tile.dart';

class TargetEndpointsExplorer extends StatefulWidget {

  const TargetEndpointsExplorer({
    super.key,
  });

  @override
  State<TargetEndpointsExplorer> createState() => _TargetEndpointsExplorerState();
}

class _TargetEndpointsExplorerState extends State<TargetEndpointsExplorer> {

  late final TreeController<TreeNode> treeController;

  @override
  void initState() {
    super.initState();
    treeController = TreeController<TreeNode>(
      roots: [],
      childrenProvider: (TreeNode node) => node.children ?? [],
    );
  }

  @override
  void dispose() {
    treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, child) {
        if (ref.targetEndpoints.isNotEmpty) {
          List<TreeNode> nodes = [];
          if (treeController.roots.isEmpty) {
            _buildNodes(ref, context, nodes);
            treeController.roots = nodes;
          }
          return InteractiveViewer(
            constrained: false,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                child: TreeView<TreeNode>(
                  shrinkWrap: true,
                  treeController: treeController,
                  // Provide a widget builder callback to map your tree nodes into widgets.
                  nodeBuilder: (BuildContext context, TreeEntry<TreeNode> entry) {
                    return TreeTile(
                      key: ValueKey(entry.node.key),
                      entry: entry,
                      // Add a callback to toggle the expansion state of this node.
                      onTap: () => treeController.toggleExpansion(entry.node),
                    );
                  },
                ),
              ),
            ),
          );
        }
        return Container();
      }
    );
  }

  void _buildNodes(ApigeeProvider ref, BuildContext context, List<TreeNode<dynamic>> nodes) {

    for (internal.EndpointsRepresentation targetEndpoint in ref.targetEndpoints) {
      var proxyEndpointNode = TreeNode<internal.EndpointsRepresentation>(
        key: p.basenameWithoutExtension(targetEndpoint.name),
        data: targetEndpoint,
        widget: Padding(
          padding: const EdgeInsets.all(3.0),
          child: StageTile(
            name: p.basenameWithoutExtension(targetEndpoint.name),
            description: targetEndpoint.description,
            onEdit: () => Provider.of<ApigeeProvider>(context, listen: false).editFile(
                name: targetEndpoint.name,
                type: internal.FileRepresentationType.targetEndpointDescriptor
            ),
          ),
        )
      )
        ..addChild(child: TreeNode<internal.Flow>(
          key: preFlow,
          data: targetEndpoint.preFlow,
          widget: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: EndpointTile(
              selected: ref.selectedTargetEndpointFlow != null && ref.selectedTargetEndpointFlow == targetEndpoint.preFlow,
              onSelect: () => ref.selectTargetEndpointFlow(targetEndpointName: p.basenameWithoutExtension(targetEndpoint.name), flowName: preFlow),
              name: preFlow,
              condition: targetEndpoint.preFlow!.condition,
            ),
          )
        )
        );
      if (targetEndpoint.flows != null && targetEndpoint.flows!.isNotEmpty) {
        for (internal.Flow flow in targetEndpoint.flows!) {
          proxyEndpointNode.addChild(child: TreeNode<internal.Flow>(
            key: flow.name,
            data: flow,
            widget: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: EndpointTile(
                selected: ref.selectedTargetEndpointFlow != null && ref.selectedTargetEndpointFlow == flow,
                onSelect: () => ref.selectTargetEndpointFlow(targetEndpointName: p.basenameWithoutExtension(targetEndpoint.name), flowName: flow.name),
                name: flow.name,
                condition: flow.condition,
              ),
            )
          ));
        }
      }
      proxyEndpointNode
        ..addChild(
            child: TreeNode<internal.Flow>(
              key: postFlow,
              data: targetEndpoint.postFlow,
              widget: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: EndpointTile(
                  selected: ref.selectedTargetEndpointFlow != null && ref.selectedTargetEndpointFlow == targetEndpoint.postFlow,
                  onSelect: () => ref.selectTargetEndpointFlow(targetEndpointName: p.basenameWithoutExtension(targetEndpoint.name), flowName: postFlow),
                  name: postFlow,
                  condition: targetEndpoint.postFlow!.condition,
                ),
              )
            ))
        ..addChild(
            child: TreeNode<internal.Flow>(
              key: postClientFlow,
              data: targetEndpoint.postClientFlow,
                widget: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: EndpointTile(
                    selected: ref.selectedTargetEndpointFlow != null && ref.selectedTargetEndpointFlow == targetEndpoint.postClientFlow,
                    onSelect: () => ref.selectTargetEndpointFlow(targetEndpointName: p.basenameWithoutExtension(targetEndpoint.name), flowName: postClientFlow),
                    name: postClientFlow,
                    condition: targetEndpoint.postClientFlow!.condition,
                  ),
                )
            ))
          ;
      nodes.add(proxyEndpointNode);
    }
  }
}