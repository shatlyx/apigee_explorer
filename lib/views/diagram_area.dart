
import 'dart:ui';

import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/utils/constants.dart';
import 'package:apigee_explorer/widgets/flow_diagram.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

class DiagramArea extends StatefulWidget {
  const DiagramArea({
    super.key,
  });

  @override
  State<DiagramArea> createState() => _DiagramAreaState();
}

class _DiagramAreaState extends State<DiagramArea> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, _) {
        if(ref.selectedFlow == null) {
          return Container();
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Label(title: "API Client", icon: Icon(Icons.ads_click),),
              const SizedBox(height: 50,),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //Request Column
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: Colors.blueAccent)
                    ),
                    child: Column(
                      children: [
                        const Label(title: "Request", icon: Icon(Icons.arrow_downward),),
                        FlowDiagram(name: preFlow, phase: Phase.request, steps: ref.getSelectedProxyEndpoint().preFlow?.request,),
                        FlowDiagram(name: ref.selectedFlow!.name, phase: Phase.request, steps: ref.selectedFlow!.request, condition: ref.selectedFlow!.condition,),
                        FlowDiagram(name: postFlow, phase: Phase.request, steps: ref.getSelectedProxyEndpoint().postFlow?.request,),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10,),
                  //Request Column
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: Colors.blueAccent)
                    ),
                    child: Column(
                      children: [
                        const Label(title: "Response", icon: Icon(Icons.arrow_upward),),
                        FlowDiagram(name: postClientFlow, phase: Phase.response, steps: ref.getSelectedProxyEndpoint().postClientFlow?.response,),
                        FlowDiagram(name: postFlow, phase: Phase.response, steps: ref.getSelectedProxyEndpoint().postFlow?.response,),
                        FlowDiagram(name: ref.selectedFlow!.name, phase: Phase.response, steps: ref.selectedFlow!.response, condition: ref.selectedFlow!.condition),
                        FlowDiagram(name: preFlow, phase: Phase.response, steps: ref.getSelectedProxyEndpoint().preFlow?.response,),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50,),
              const Label(title: "Target", icon: Icon(FontAwesomeIcons.bullseye),),
            ],
          ),
        );
      }
    );
  }
}

class Label extends StatelessWidget {
  final String title;
  final Icon? icon;
  const Label({
    super.key, required this.title, this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: SizedBox(
        width: 160,
        height: 50,
        child: ListTile(
          leading: icon,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
