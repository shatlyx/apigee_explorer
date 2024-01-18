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

class ResourcesExplorerArea extends StatefulWidget {

  const ResourcesExplorerArea({
    super.key,
  });

  @override
  State<ResourcesExplorerArea> createState() => _ResourcesExplorerAreaState();
}

class _ResourcesExplorerAreaState extends State<ResourcesExplorerArea> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, child) {
        var resources = ref.resources;
        if (resources.isNotEmpty) {
          var nodes = TreeNode.root();
          for (var entry in resources.entries) {
            var typeNode = TreeNode<internal.FileType>(key: entry.key.label, data: entry.key);
            if (entry.value.isNotEmpty) {
              for (internal.FileRepresentation file in entry.value) {
                typeNode.add(TreeNode<internal.FileRepresentation>(
                  key: p.basenameWithoutExtension(file.name),
                  data: file,
                ));
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
                    if (node.data is internal.FileRepresentation && node.key != internal.FileType.javaResource.label) {
                      return InkWell(
                          onTap: () => ref.editFile(
                              name: p.basenameWithoutExtension((node.data as internal.FileRepresentation).name),
                              type: (node.data as internal.FileRepresentation).fileRepresentationType
                          ),
                          child: ListTile(
                            title: Text(node.key, style: const TextStyle(fontSize: 12),),
                          )
                      );
                    }
                    return ListTile(
                      title: Text(node.key, style: const TextStyle(fontSize: 12),),
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
}