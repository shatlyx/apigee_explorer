import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/utils/condition_utils.dart';
import 'package:apigee_explorer/utils/constants.dart';
import 'package:apigee_explorer/widgets/endpoint_tile.dart';
import 'package:flutter/material.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../widgets/stage_tile.dart';

class ProxyEndpointsExplorer extends StatefulWidget {

  const ProxyEndpointsExplorer({
    super.key,
  });

  @override
  State<ProxyEndpointsExplorer> createState() => _ProxyEndpointsExplorerState();
}

class _ProxyEndpointsExplorerState extends State<ProxyEndpointsExplorer> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, child) {
        if (ref.proxyEndpoints.isNotEmpty) {
          var nodes = TreeNode.root();
          for (internal.EndpointsRepresentation proxyEndpoint in ref.proxyEndpoints) {
            var proxyEndpointNode = TreeNode<internal.EndpointsRepresentation>(key: p.basenameWithoutExtension(proxyEndpoint.name), data: proxyEndpoint)
              ..add(TreeNode<internal.Flow>(key: preFlow, data: proxyEndpoint.preFlow));
            if (proxyEndpoint.flows != null && proxyEndpoint.flows!.isNotEmpty) {
              for (internal.Flow flow in proxyEndpoint.flows!) {
                proxyEndpointNode.add(TreeNode<internal.Flow>(
                  key: flow.name,
                  data: flow,
                ));
              }
            }
            proxyEndpointNode
              ..add(TreeNode(key: postFlow, data: proxyEndpoint.postFlow))
              ..add(TreeNode(key: postClientFlow, data: proxyEndpoint.postClientFlow))
                ;
            nodes.add(proxyEndpointNode);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Proxy Endpoints', style: TextStyle(fontWeight: FontWeight.bold),),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TreeView.simple(
                  showRootNode: false,
                  expansionIndicatorBuilder: (context, node) =>
                    ChevronIndicator.rightDown(
                      alignment: Alignment.centerRight,
                      tree: node,
                      color: Colors.blue,
                      padding: const EdgeInsets.all(8),
                    ),
                  indentation: const Indentation(style: IndentStyle.roundJoint),
                  shrinkWrap: true,
                  tree: nodes,
                  builder: (context, node) {
                    if (node.data is internal.Flow) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: EndpointTile(
                          selected: ref.selectedProxyEndpointFlow != null && ref.selectedProxyEndpointFlow == node.data,
                          onSelect: () => ref.selectProxyEndpointFlow(proxyEndpointName: node.parent!.key, flowName: node.key),
                          name: node.key,
                          condition: (node.data as internal.Flow).condition,
                        ),
                      );
                    }
                    if (node.data is internal.EndpointsRepresentation) {
                      return Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: StageTile(
                          name: node.key,
                          description: (node.data as internal.EndpointsRepresentation).description,
                          onEdit: () => Provider.of<ApigeeProvider>(context, listen: false).editFile(
                              name: (node.data as internal.EndpointsRepresentation).name,
                              type: internal.FileRepresentationType.proxyEndpointDescriptor
                          ),
                        ),
                      );
                    }
                    return ListTile(title: Text(node.key),);
                  },
                ),
              ),
            ],
          );
        }
        return Container();
      }
    );
  }
}