import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/widgets/endpoint_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../model/policies/policy.dart';
import '../model/tree_node.dart';
import '../widgets/tree_tile.dart';

class PoliciesExplorerArea extends StatefulWidget {

  const PoliciesExplorerArea({
    super.key,
  });

  @override
  State<PoliciesExplorerArea> createState() => _PoliciesExplorerAreaState();
}

class _PoliciesExplorerAreaState extends State<PoliciesExplorerArea> {

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
        var policies = ref.getPoliciesByFileType();
        if (policies.isNotEmpty) {
          List<TreeNode> nodes = [];
          if (treeController.roots.isEmpty) {
            _buildData(policies, ref, nodes);
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

  void _buildData(Map<internal.FileType, List<Policy>> policies, ApigeeProvider ref, List<TreeNode<dynamic>> nodes) {
    for (var entry in policies.entries) {
      var typeNode = TreeNode<internal.FileType>(
          key: entry.key.label,
          data: entry.key,
          widget: Text(entry.key.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),),
      );
      if (entry.value.isNotEmpty) {
        for (Policy policy in entry.value) {
          var xmlIdentification = policy.getIdentifyXmlFileIdentification();
          var policyNode = TreeNode<Policy>(
            key: p.basenameWithoutExtension(xmlIdentification.name),
            data: policy,
            widget: InkWell(
                onTap: () {
                  var file = policy.getIdentifyXmlFileIdentification();
                  ref.editFile(name: file.name);
                },
                child: Text(xmlIdentification.name, style: const TextStyle(fontSize: 12),),
            ),
          );
          //Add Flows
          _addPolicyFlowsUsage(ref, policy, policyNode);
          _addInputs(policy, policyNode);
          _addOutputs(policy, policyNode);
          typeNode.addChild(child: policyNode);
        }
      }
      nodes.add(typeNode);
    }
  }

  void _addOutputs(Policy policy, TreeNode<Policy> policyNode) {
    var outputs = policy.fetchOutputs();
    if (outputs.isNotEmpty) {
      var outputNode = TreeNode<String>(
        key: "Outputs",
        data: "Outputs",
        widget: const Text("Outputs", style: TextStyle(fontWeight: FontWeight.w500),)
      );
      for (var output in outputs.toList()..sort()) {
        outputNode.addChild(child: TreeNode<String>(
            key: output,
            data: output,
            widget: Text(output, style: const TextStyle(fontWeight: FontWeight.w500),)
        ));
      }
      policyNode.addChild(child: outputNode);
    }
  }

  void _addInputs(Policy policy, TreeNode<Policy> policyNode) {
    var inputs = policy.fetchInputs();
    if (inputs.isNotEmpty) {
      var inputNode = TreeNode<String>(
        key: "Inputs",
        data: "Inputs",
        widget: const Text("Inputs", style: TextStyle(fontWeight: FontWeight.w500),)
      );
      for (var input in inputs.toList()..sort()) {
        inputNode.addChild(child: TreeNode<String>(
          key: input,
          data: input,
          widget: Text(input, style: const TextStyle(fontWeight: FontWeight.w500),)
        ));
      }
      policyNode.addChild(child: inputNode);
    }
  }

  void _addPolicyFlowsUsage(ApigeeProvider ref, Policy policy, TreeNode<Policy> policyNode) {
    var flowsUsage = ref.findPolicyFlowsUsage(policyName: policy.getIdentifyXmlFileIdentification().name);
    if (flowsUsage.isNotEmpty) {
      var usageNode = TreeNode<String>(
        key: "Used in",
        data: "Used in",
        widget: const Text("Used in"),
      );
      for (var flowUsage in flowsUsage.entries) {
        var flowsUsageProxyEndpointNode = TreeNode<String>(
          key: flowUsage.key,
          data: flowUsage.key,
          widget: Text(flowUsage.key),
        );
        for (var flow in flowUsage.value) {
          flowsUsageProxyEndpointNode.addChild(child: TreeNode<internal.Flow>(
            key: flow.flow.name,
            data: flow.flow,
            widget: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: EndpointTile(
                selected: ref.selectedProxyEndpointFlow != null && ref.selectedProxyEndpointFlow == flow.flow,
                onSelect: () => ref.selectProxyEndpointFlow(proxyEndpointName: flowUsage.key, flowName: flow.flow.name),
                name: flow.flow.name,
                condition: flow.flow.condition,
              ),
            )
          ));
        }
        usageNode.addChild(child: flowsUsageProxyEndpointNode);
      }
      policyNode.addChild(child: usageNode);
    }
  }

}