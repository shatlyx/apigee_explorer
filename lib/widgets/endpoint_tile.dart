import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:petitparser/src/core/result.dart';

import '../utils/condition_utils.dart';

class EndpointTile extends StatelessWidget {
  final String name;
  final bool selected;
  final void Function()? onSelect;
  final Result<dynamic>? condition;
  final bool showVerbBadge;
  const EndpointTile({super.key, required this.name, this.selected = false, this.onSelect, this.condition, this.showVerbBadge = true,});

  @override
  Widget build(BuildContext context) {
    String verb = _resolveVerb();
    return InkWell(
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.grey : null,
          borderRadius: const BorderRadius.all(Radius.circular(20))
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showVerbBadge)
                InkWell(
                  onTap: onSelect,
                  child: Badge(
                    textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    largeSize: 20,
                    backgroundColor: _resolveColor(verb),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Center(child: Text(verb, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    ),
                  ),
                ),
              if (showVerbBadge)
                const SizedBox(width: 5,),
              InkWell(
                onTap: onSelect,
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),),
              ),
              const SizedBox(width: 5,),
              if (condition != null)
                InkWell(
                  onTap: () => ConditionUtils.showTextPopover(context: context, text: condition?.buffer ?? 'No Content'),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.filter_list, color: Colors.grey,),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveVerb() {
    return condition != null ? ConditionUtils.getVerb(condition!) : "ALL";
  }

  _resolveColor(String verb) {
    switch(verb) {
      case 'COND': return Colors.grey;
      case 'ALL': return Colors.orange;
      case 'POST': return Colors.blue;
      case 'GET': return Colors.green;
      case 'PUT': return Colors.grey;
      case 'DELETE': return Colors.red;
      default: Colors.grey;
    }
  }
}
