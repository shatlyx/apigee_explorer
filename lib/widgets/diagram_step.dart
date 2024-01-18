import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:apigee_explorer/utils/condition_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DiagramStep extends StatelessWidget {
  final internal.FlowStep step;
  const DiagramStep({super.key, required this.step,});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApigeeProvider>(
      builder: (context, ref, _) => InkWell(
        onDoubleTap: () => Provider.of<ApigeeProvider>(context, listen: false)
            .editFile(name: step.policy!.getIdentifyXmlFileIdentification().name),
        onTap: () => ConditionUtils.showTextPopover(context: context, text: step.policy?.getContent() ?? 'No Content'),
        child: ListTile(
          tileColor: ref.selectedOpenFileName != null && ref.selectedOpenFileName == step.policy!.getIdentifyXmlFileIdentification().name
              ? Colors.blue.shade50
              : null,
          title: Wrap(
            children: [
              Text(step.policy!.getIdentifyXmlFileIdentification().name),
              if (!step.policy!.getIdentifyXmlFileIdentification().enabled)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Tooltip(
                    message: 'Disabled',
                    child: Icon(Icons.not_interested, color: Colors.red,),
                  ),
                ),
              if (step.condition != null && step.condition!.buffer.isNotEmpty)
                InkWell(
                  onTap: () => ConditionUtils.showTextPopover(context: context, text: step.condition?.buffer ?? 'No Content'),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.filter_list, color: Colors.grey,),
                  ),
                ),
            ],
          ),
          leading: const Icon(Icons.list),
        ),
      )
    );
  }

}
