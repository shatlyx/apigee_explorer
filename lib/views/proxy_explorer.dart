import 'package:apigee_explorer/views/policies_explorer_area.dart';
import 'package:apigee_explorer/views/resources_explorer_area.dart';
import 'package:apigee_explorer/views/target_endpoints_explorer.dart';
import 'package:apigee_explorer/views/xml_editor_area.dart';
import 'package:contained_tab_bar_view/contained_tab_bar_view.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'diagram_area.dart';
import 'proxy_endpoints_explorer.dart';

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
                initialAreas: [Area(size: 240), Area(weight: 0.7)],
                axis: Axis.horizontal,
                children: [
                  Container(
                    color: Colors.grey.shade100,
                    child: ContainedTabBarView(
                      tabBarViewProperties: const TabBarViewProperties(
                        physics: NeverScrollableScrollPhysics()
                      ),
                      tabs: const [
                        Text('Proxy Endpoints', textAlign: TextAlign.center,),
                        Text('Target Endpoints', textAlign: TextAlign.center,),
                        Text('Policies', textAlign: TextAlign.center,),
                        Text('Resources', textAlign: TextAlign.center,),
                      ],
                      views: const [
                        ProxyEndpointsExplorer(),
                        TargetEndpointsExplorer(),
                        PoliciesExplorerArea(),
                        ResourcesExplorerArea(),
                      ],
                      tabBarProperties: TabBarProperties(
                        //width: 240,
                        height: 50,
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8.0), topRight: Radius.circular(8.0)),
                          ),
                        ),
                        position: TabBarPosition.top,
                        alignment: TabBarAlignment.start,
                        indicatorColor: Colors.blue,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.black,
                        indicatorWeight: 4,
                      ),
                    ),
                  ),
                  const DiagramArea(),
                  const XmlEditorArea(),
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
              color: Colors.grey[400]!,
              highlightedColor: Colors.blue,
              count: 11,
              highlightedCount: 19,
              thickness: 3,
            ),
        ),
        child: child);
  }
}
