import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/widgets/code_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tabbed_view/tabbed_view.dart';
import 'package:path/path.dart' as p;

class XmlEditorArea extends StatefulWidget {

  const XmlEditorArea({super.key});

  @override
  State<XmlEditorArea> createState() => _XmlEditorAreaState();
}

class _XmlEditorAreaState extends State<XmlEditorArea> {
  late TabbedViewController _tabsController;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, _) {
        if (ref.openFiles.isEmpty) {
          return _emptyOpenFiles();
        }
        _tabsController = TabbedViewController(ref.openFiles.map((e) => TabData(
            text: p.basenameWithoutExtension(e.name),
            content: CodeEditor(file: e),
        )).toList());
        _tabsController.selectedIndex = ref.getSelectedOpenFileIndex();

        return Padding(
          padding: const EdgeInsets.all(0.0),
          child: TabbedViewTheme(
            data: TabbedViewThemeData.mobile(),
            child: TabbedView(
              controller: _tabsController,
              onTabClose: (index, tab) => ref.closeFile(index),
              onTabSelection: (index) => ref.selectOpenFileName(index!),
            ),
          ),
        );
      }
    );
  }

  Widget _emptyOpenFiles() {
    return const Center(
      child: Text("Double click on Policy to open it",),
    );
  }
}
