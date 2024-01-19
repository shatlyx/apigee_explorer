import 'package:apigee_explorer/model/tree_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TreeTile extends StatelessWidget {

  final TreeEntry<TreeNode> entry;
  final VoidCallback onTap;

  const TreeTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TreeIndentation(
      entry: entry,
      guide: const IndentGuide.connectingLines(
          indent: 48,
        strokeJoin: StrokeJoin.round,
        padding: EdgeInsets.all(1),
        color: Colors.blue,
        origin: 0.4,
        strokeCap: StrokeCap.round
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Add a widget to indicate the expansion state of this node.
          // See also: ExpandIcon.
          if (entry.hasChildren)
            ExpandIcon(
              color: Colors.blue,
              isExpanded: entry.isExpanded,
              onPressed: (_) => onTap.call(),
            ),
          if (!entry.hasChildren)
            const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(FontAwesomeIcons.file, color: Colors.black45,),
            ),
          entry.node.widget,
        ],
      ),
    );
  }
}