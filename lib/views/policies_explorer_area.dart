import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/utils/condition_utils.dart';
import 'package:apigee_explorer/utils/constants.dart';
import 'package:apigee_explorer/widgets/endpoint_tile.dart';
import 'package:flutter/material.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

import '../model/policies/policy.dart';
import '../widgets/stage_tile.dart';

class PoliciesExplorerArea extends StatefulWidget {

  const PoliciesExplorerArea({
    super.key,
  });

  @override
  State<PoliciesExplorerArea> createState() => _PoliciesExplorerAreaState();
}

class _PoliciesExplorerAreaState extends State<PoliciesExplorerArea> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, child) {
        var policies = ref.getPoliciesByFileType();
        if (policies.isNotEmpty) {
          var nodes = TreeNode.root();
          for (var entry in policies.entries) {
            var typeNode = TreeNode<internal.FileType>(key: entry.key.label, data: entry.key);
            if (entry.value.isNotEmpty) {
              for (Policy policy in entry.value) {
                var policyNode = TreeNode<Policy>(
                  key: p.basenameWithoutExtension(policy.getIdentifyXmlFileIdentification().name),
                  data: policy,
                );
                //Add Flows
                _addPolicyFlowsUsage(ref, policy, policyNode);
                _addInputs(policy, policyNode);
                _addOutputs(policy, policyNode);
                typeNode.add(policyNode);
              }
            }
            nodes.add(typeNode);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
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
                    if (node.data is internal.FileType) {
                      return ListTile(title: Text(node.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),),);
                    }
                    if (node.data is Policy) {
                      return InkWell(
                          onTap: () {
                            var file = (node.data as Policy).getIdentifyXmlFileIdentification();
                            ref.editFile(name: file.name);
                          },
                          child: ListTile(
                            title: Text(node.key, style: const TextStyle(fontSize: 12),),
                          )
                      );
                    }
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
                    return ListTile(
                      title: Tooltip(
                        message: node.key.replaceAll('\[dot\]', '.'),
                        child: Text(node.key, style: const TextStyle(fontSize: 12),)),
                    );
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

  void _addOutputs(Policy policy, TreeNode<Policy> policyNode) {
    var outputs = policy.fetchOutputs();
    if (outputs.isNotEmpty) {
      var outputNode = TreeNode<String>(
        key: "Outputs",
        data: "Outputs",
      );
      for (var output in outputs.toList()..sort()) {
        outputNode.add(TreeNode<String>(key: _formatNodeKey(output), data: output));
      }
      policyNode.add(outputNode);
    }
  }

  void _addInputs(Policy policy, TreeNode<Policy> policyNode) {
    var inputs = policy.fetchInputs();
    if (inputs.isNotEmpty) {
      var inputNode = TreeNode<String>(
        key: "Inputs",
        data: "Inputs",
      );
      for (var input in inputs.toList()..sort()) {
        inputNode.add(TreeNode<String>(key: _formatNodeKey(input), data: input));
      }
      policyNode.add(inputNode);
    }
  }

  void _addPolicyFlowsUsage(ApigeeProvider ref, Policy policy, TreeNode<Policy> policyNode) {
    var flowsUsage = ref.findPolicyFlowsUsage(policyName: policy.getIdentifyXmlFileIdentification().name);
    if (flowsUsage.isNotEmpty) {
      var usageNode = TreeNode<String>(
        key: "Used in",
        data: "Used in",
      );
      for (var flowUsage in flowsUsage.entries) {
        var flowsUsageProxyEndpointNode = TreeNode<String>(
          key: flowUsage.key,
          data: flowUsage.key,
        );
        for (var flow in flowUsage.value) {
          flowsUsageProxyEndpointNode.add(TreeNode<internal.Flow>(
            key: flow.flow.name,
            data: flow.flow,
          ));
        }
        usageNode.add(flowsUsageProxyEndpointNode);
      }
      policyNode.add(usageNode);
    }
  }

  _formatNodeKey(String input) {
    return input.replaceAll("\.", "[dot]");
  }
}