import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/model/tree_node.dart';
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/widgets/tree_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class ResourcesExplorerArea extends StatefulWidget {

  const ResourcesExplorerArea({
    super.key,
  });

  @override
  State<ResourcesExplorerArea> createState() => _ResourcesExplorerAreaState();
}

class _ResourcesExplorerAreaState extends State<ResourcesExplorerArea> {

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
        var resources = ref.resources;
        if (resources.isNotEmpty) {
          List<TreeNode> nodes = [];
          for (var entry in resources.entries) {
            var typeNode = TreeNode<internal.FileType>(
              key: entry.key.label,
              data: entry.key,
              widget: Flexible(
                child: Text(entry.key.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,),),
              ),
              children: entry.value.map((e) => TreeNode<internal.FileRepresentation>(
                key: p.basename(e.name),
                data: e,
                widget: Flexible(
                  child: InkWell(
                      onTap: () => ref.editFile(
                          name: p.basenameWithoutExtension(e.name),
                          type: e.fileRepresentationType
                      ),
                      child: Text(p.basename(e.name), style: const TextStyle(fontSize: 12,),),
                  ),
                )
              )).toList()
            );
            nodes.add(typeNode);
          }
          if (treeController.roots.isEmpty) {
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
}