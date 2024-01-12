import 'package:apigee_explorer/views/xml_editor_area.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'api_proxy_explorer_area.dart';
import 'diagram_area.dart';

class ProxyExplorer extends StatefulWidget {
  final Widget Function(BuildContext context) bottomBar;

  const ProxyExplorer({Key? key, required this.bottomBar}) : super(key: key);
  @override
  ProxyExplorerState createState() => ProxyExplorerState();
}

class ProxyExplorerState extends State<ProxyExplorer> {

  @override
  Widget build(BuildContext context) {
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
                initialAreas: [Area(size: 240), Area(weight: 0.5)],
                axis: Axis.horizontal,
                children: [
                  const ApiProxyExplorerArea(),
                  const DiagramArea(),
                  SplitView(
                    child: MultiSplitView(
                      axis: Axis.vertical,
                      children: [
                        const XmlEditorArea(),
                        Container(color: Colors.green,),
                      ],
                    ),
                  ),
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
