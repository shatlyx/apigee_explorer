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

class ProxyEndpointsExplorer extends StatefulWidget {

  const ProxyEndpointsExplorer({
    super.key,
  });

  @override
  State<ProxyEndpointsExplorer> createState() => _ProxyEndpointsExplorerState();
}

class _ProxyEndpointsExplorerState extends State<ProxyEndpointsExplorer> {

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
        if (ref.proxyEndpoints.isNotEmpty) {
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

    for (internal.EndpointsRepresentation proxyEndpoint in ref.proxyEndpoints) {
      var proxyEndpointNode = TreeNode<internal.EndpointsRepresentation>(
        key: p.basenameWithoutExtension(proxyEndpoint.name),
        data: proxyEndpoint,
        widget: Padding(
          padding: const EdgeInsets.all(3.0),
          child: StageTile(
            name: p.basenameWithoutExtension(proxyEndpoint.name),
            description: proxyEndpoint.description,
            onEdit: () => Provider.of<ApigeeProvider>(context, listen: false).editFile(
                name: proxyEndpoint.name,
                type: internal.FileRepresentationType.proxyEndpointDescriptor
            ),
          ),
        )
      )
        ..addChild(child: TreeNode<internal.Flow>(
          key: preFlow,
          data: proxyEndpoint.preFlow,
          widget: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: EndpointTile(
              selected: ref.selectedProxyEndpointFlow != null && ref.selectedProxyEndpointFlow == proxyEndpoint.preFlow,
              onSelect: () => ref.selectProxyEndpointFlow(proxyEndpointName: p.basenameWithoutExtension(proxyEndpoint.name), flowName: preFlow),
              name: preFlow,
              condition: proxyEndpoint.preFlow!.condition,
            ),
          )
        )
        );
      if (proxyEndpoint.flows != null && proxyEndpoint.flows!.isNotEmpty) {
        for (internal.Flow flow in proxyEndpoint.flows!) {
          proxyEndpointNode.addChild(child: TreeNode<internal.Flow>(
            key: flow.name,
            data: flow,
            widget: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: EndpointTile(
                selected: ref.selectedProxyEndpointFlow != null && ref.selectedProxyEndpointFlow == flow,
                onSelect: () => ref.selectProxyEndpointFlow(proxyEndpointName: p.basenameWithoutExtension(proxyEndpoint.name), flowName: flow.name),
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
              data: proxyEndpoint.postFlow,
              widget: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: EndpointTile(
                  selected: ref.selectedProxyEndpointFlow != null && ref.selectedProxyEndpointFlow == proxyEndpoint.postFlow,
                  onSelect: () => ref.selectProxyEndpointFlow(proxyEndpointName: p.basenameWithoutExtension(proxyEndpoint.name), flowName: postFlow),
                  name: postFlow,
                  condition: proxyEndpoint.postFlow!.condition,
                ),
              )
            ))
        ..addChild(
            child: TreeNode<internal.Flow>(
              key: postClientFlow,
              data: proxyEndpoint.postClientFlow,
                widget: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: EndpointTile(
                    selected: ref.selectedProxyEndpointFlow != null && ref.selectedProxyEndpointFlow == proxyEndpoint.postClientFlow,
                    onSelect: () => ref.selectProxyEndpointFlow(proxyEndpointName: p.basenameWithoutExtension(proxyEndpoint.name), flowName: postClientFlow),
                    name: postClientFlow,
                    condition: proxyEndpoint.postClientFlow!.condition,
                  ),
                )
            ))
          ;
      nodes.add(proxyEndpointNode);
    }
  }
}