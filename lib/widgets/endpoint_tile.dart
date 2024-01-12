import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EndpointTile extends StatelessWidget {
  final String name;
  final String? verb;
  final bool selected;
  final void Function()? onSelect;
  const EndpointTile({super.key, required this.name, this.verb, this.selected = false, this.onSelect});

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
            children: [
              InkWell(
                onTap: onSelect,
                child: Badge(
                  textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  largeSize: 20,
                  backgroundColor: _resolveColor(verb),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Center(child: Text(verb, textAlign: TextAlign.center,)),
                  ),
                ),
              ),
              const SizedBox(width: 5,),
              InkWell(
                onTap: onSelect,
                child: Text(name,),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveVerb() {
    if (verb == null) {
      return "COND";
    }
    return verb!;
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
