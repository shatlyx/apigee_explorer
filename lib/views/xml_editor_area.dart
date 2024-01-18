import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/widgets/code_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class XmlEditorArea extends StatefulWidget {

  const XmlEditorArea({super.key});

  @override
  State<XmlEditorArea> createState() => _XmlEditorAreaState();
}

class _XmlEditorAreaState extends State<XmlEditorArea> {

  final GlobalKey _globalKey = GlobalKey();

  @override
  void initState() {
    print("initState XML Editor Data...");
    super.initState();
  }

  @override
  void dispose() {
    print("Disposing XML Editor Data...");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("build XML Editor Data...");
    return Consumer<ApigeeProvider>(
      builder: (context, ref, child) {
        if (ref.openFiles.isEmpty) {
          return _emptyOpenFiles();
        }
        List<Widget> tabs = [];
        WidgetsBinding.instance.addPostFrameCallback((_) => Scrollable.ensureVisible(_globalKey.currentContext ?? context));

        for (FileRepresentation file in ref.openFiles) {
          tabs.add(CodeEditor(file: file, key: ValueKey(p.basenameWithoutExtension(file.name))));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 46,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ref.openFiles.map((e) => Card(
                    key: p.basenameWithoutExtension(e.name) == p.basenameWithoutExtension(ref.getSelectedOpenFile()!.name) ? _globalKey : null,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(topRight: Radius.circular(15), topLeft: Radius.circular(15)),
                    ),
                    shadowColor: Colors.blue,
                    elevation: p.basenameWithoutExtension(e.name) == p.basenameWithoutExtension(ref.getSelectedOpenFile()!.name) ? 5 : 1,
                    color: p.basenameWithoutExtension(e.name) == p.basenameWithoutExtension(ref.getSelectedOpenFile()!.name) ? Colors.blue : null,
                    child: InkWell(
                      onTap: () => ref.selectOpenFileName(e.name),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(p.basenameWithoutExtension(e.name),
                              style: TextStyle(
                                color: p.basenameWithoutExtension(e.name) == p.basenameWithoutExtension(ref.getSelectedOpenFile()!.name) ? Colors.white : Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 6,),
                            InkWell(
                              onTap: () => ref.closeFile(e.name),
                              child: Icon(Icons.cancel_rounded, size: 16, color: p.basenameWithoutExtension(e.name) == p.basenameWithoutExtension(ref.getSelectedOpenFile()!.name) ? Colors.white : Colors.blue,)),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                sizing: StackFit.loose,
                index: ref.openFiles.indexWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(ref.getSelectedOpenFile()!.name)),
                children: tabs,
              ),
            ),
          ],
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
