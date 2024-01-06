import 'package:apigee_explorer/views/policies_explorer_area.dart';
import 'package:apigee_explorer/views/policy_code_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:graphite/graphite.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

import 'diagram_area.dart';
import 'flows_area.dart';


const presetBasic = '['
    '{"id":"A","next":[{"outcome":"B","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"B","next":[{"outcome":"C","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"C","next":[{"outcome":"D","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"D","next":[{"outcome":"E","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"E","next":[{"outcome":"F","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"F","next":[{"outcome":"G","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"G","next":[{"outcome":"H","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"H","next":[{"outcome":"I","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"I","next":[{"outcome":"J","type":"one"}],"size":{"width": 75.0, "height": 75.0}},'
    '{"id":"J","next":[],"size":{"width": 75.0, "height": 75.0}}'
    ']';

class ProxyExplorer extends StatefulWidget {
  final Widget Function(BuildContext context) bottomBar;

  const ProxyExplorer({Key? key, required this.bottomBar}) : super(key: key);
  @override
  ProxyExplorerState createState() => ProxyExplorerState();
}

class ProxyExplorerState extends State<ProxyExplorer> {

  @override
  Widget build(BuildContext context) {
    var list = nodeInputFromJson(presetBasic);
    final _controller = CodeController(
      text: "//take input from the users",
      language: javascript,
      analyzer: const DefaultLocalAnalyzer(),
    );
    return Scaffold(
      appBar: AppBar(
          leading: const Icon(Icons.view_module),
          title: const Text('cib-proxy-oauth')),
      body: SplitView(
        child: MultiSplitView(
          axis: Axis.vertical,
          children: [
            SplitView(
              child: MultiSplitView(
                initialAreas: [Area(weight: 0.1)],
                axis: Axis.horizontal,
                children: [
                  PoliciesExplorerArea(),
                  SplitView(
                    child: MultiSplitView(
                      initialAreas: [Area(size: 50)],
                      axis: Axis.vertical,
                      children: [
                        FlowsArea(),
                        DiagramArea(list: list),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SplitView(
              child: MultiSplitView(
                children: [
                  PolicyCodeArea(controller: _controller),
                  Container(color: Colors.green,),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.bottomBar(context),
    );
  }

}

class SplitView extends StatelessWidget {
  final MultiSplitView child;
  const SplitView({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
            dividerPainter: DividerPainters.grooved2(
                color: Colors.grey[400]!, highlightedColor: Colors.red)),
        child: child);
  }
}
