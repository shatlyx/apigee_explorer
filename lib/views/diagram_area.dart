
import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/utils/constants.dart';
import 'package:apigee_explorer/widgets/fault_rule_diagram.dart';
import 'package:apigee_explorer/widgets/flow_diagram.dart';
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
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, _) {
        return InteractiveViewer(
          constrained: false,
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
                        if (ref.selectedProxyEndpointFlow != null)
                          FlowDiagram(name: ref.selectedProxyEndpointFlow!.name, phase: Phase.request, steps: ref.selectedProxyEndpointFlow!.request, condition: ref.selectedProxyEndpointFlow!.condition,),
                        FlowDiagram(name: postFlow, phase: Phase.request, steps: ref.getSelectedProxyEndpoint().postFlow?.request,),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12,),
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
                        if (ref.selectedProxyEndpointFlow != null)
                          FlowDiagram(name: ref.selectedProxyEndpointFlow!.name, phase: Phase.response, steps: ref.selectedProxyEndpointFlow!.response, condition: ref.selectedProxyEndpointFlow!.condition),
                        FlowDiagram(name: preFlow, phase: Phase.response, steps: ref.getSelectedProxyEndpoint().preFlow?.response,),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12,),
                  //Fault Rules Column
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: Colors.blueAccent)
                    ),
                    child: Column(
                      children: [
                        const Label(title: "Default Fault Rule", icon: Icon(Icons.electric_bolt),),
                        FaultRuleDiagram(
                          name: ref.getSelectedProxyEndpoint().defaultFaultRule.name,
                          steps: ref.getSelectedProxyEndpoint().defaultFaultRule.steps,
                        ),
                        const Label(title: "Fault Rules", icon: Icon(Icons.electric_bolt),),
                        for (FaultRule faultRule in ref.getSelectedProxyEndpoint().faultRules ?? [])
                          FaultRuleDiagram(name: faultRule.name, steps: faultRule.steps, condition: faultRule.condition,),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50,),
              const Label(title: "Target", icon: Icon(FontAwesomeIcons.bullseye),),
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
                        FlowDiagram(name: preFlow, phase: Phase.request, steps: ref.getSelectedTargetEndpoint().preFlow?.request,),
                        if (ref.selectedTargetEndpointFlow != null)
                          FlowDiagram(name: ref.selectedTargetEndpointFlow!.name, phase: Phase.request, steps: ref.selectedTargetEndpointFlow!.request, condition: ref.selectedTargetEndpointFlow!.condition,),
                        FlowDiagram(name: postFlow, phase: Phase.request, steps: ref.getSelectedTargetEndpoint().postFlow?.request,),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12,),
                  //Request Column
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: Colors.blueAccent)
                    ),
                    child: Column(
                      children: [
                        const Label(title: "Response", icon: Icon(Icons.arrow_upward),),
                        FlowDiagram(name: postClientFlow, phase: Phase.response, steps: ref.getSelectedTargetEndpoint().postClientFlow?.response,),
                        FlowDiagram(name: postFlow, phase: Phase.response, steps: ref.getSelectedTargetEndpoint().postFlow?.response,),
                        if (ref.selectedTargetEndpointFlow != null)
                          FlowDiagram(name: ref.selectedTargetEndpointFlow!.name, phase: Phase.response, steps: ref.selectedTargetEndpointFlow!.response, condition: ref.selectedTargetEndpointFlow!.condition),
                        FlowDiagram(name: preFlow, phase: Phase.response, steps: ref.getSelectedTargetEndpoint().preFlow?.response,),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12,),
                  //Fault Rules Column
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(color: Colors.blueAccent)
                    ),
                    child: Column(
                      children: [
                        const Label(title: "Default Fault Rule", icon: Icon(Icons.electric_bolt),),
                        FaultRuleDiagram(
                          name: ref.getSelectedTargetEndpoint().defaultFaultRule.name,
                          steps: ref.getSelectedTargetEndpoint().defaultFaultRule.steps,
                        ),
                        const Label(title: "Fault Rules", icon: Icon(Icons.electric_bolt),),
                        for (FaultRule faultRule in ref.getSelectedTargetEndpoint().faultRules?.reversed ?? [])
                          FaultRuleDiagram(name: faultRule.name, steps: faultRule.steps, condition: faultRule.condition,),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 150,),
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
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            if (icon != null)
              icon!,
            const SizedBox(width: 10,),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
