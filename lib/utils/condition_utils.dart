import 'package:flutter/material.dart';
import 'package:petitparser/petitparser.dart';
import 'package:popover/popover.dart';

class ConditionUtils {

  static Result<dynamic> parse(String s) {
    //"EqualsCaseInsensitive","StartsWith","Equals", "NotEquals", "JavaRegex","MatchesPath","Matches"
    final stringOps = string('EqualsCaseInsensitive').trim()
                    | string('StartsWith').trim()
                    | string('Equals').trim()
                    | string('NotEquals').trim()
                    | string('JavaRegex').trim()
                    | string('MatchesPath').trim()
                    | string('Matches').trim()
                    | string('!=').trim()
                    | string('!~').trim()
                    | string('==').trim()
                    | string('=').trim()
                    | string('~/').trim()
                    | string('~~').trim()
                    | string('~').trim()
    ;
    //"Equals", "NotEquals", "GreaterThanOrEquals","GreaterThan","LesserThanOrEquals","LesserThan"
    final numericOps = string('Equals').trim()
                    | string('NotEquals').trim()
                    | string('GreaterThanOrEquals').trim()
                    | string('GreaterThan').trim()
                    | string('LesserThanOrEquals').trim()
                    | string('LesserThan').trim()
                    | string('>=').trim()
                    | string('>').trim()
                    | string('<=').trim()
                    | string('<').trim()
                    | string('==').trim()
                    | string('!=').trim()
                    | string('=').trim()
    ;
    final primitive = pattern('a-zA-Z0-9_\.\'"/\*').star().flatten().trim()
        .plusSeparated(stringOps.or(numericOps))
    ;

    final builder = ExpressionBuilder();
    builder.primitive(primitive);
    builder.group()
        .wrapper(char('(').trim(), char(')').trim().flatten(), (l, v, r) => [l, v, r]);
    builder.group()
      ..left(string('&&').trim() | string('and').trim(), (a, op, b) => [a, '&&', b])
      ..left(string('||').trim() | string('or').trim(), (a, op, b) => [a, '||', b])
      ..prefix(string('!').trim(), (operator, value) => ['!', value])
    ;
    final parser = builder.build().end();

    return parser.parse(s);
  }

  static String getVerb(Result<dynamic> condition) {
    if (condition is Success) {
      return visitAllNodes(condition.value) ?? "COND";
    }
    return "COND";
  }

  static String? visitAllNodes(dynamic node, {int depth = 0}) {
    if(node is SeparatedList) {
      if (node.elements.contains("request.verb") && (node.separators.contains("=")
          || node.separators.contains("==") || node.separators.contains("Equals"))) {
        return node.elements.firstWhere((element) => "request.verb" != element);
      }
    } else if (node is Iterable) {
      for (var element in node) {
        var verb = visitAllNodes(element,);
        if (verb != null) {
          return verb.replaceAll(RegExp(r'[^a-zA-Z]'), '');
        }
      }
    }
    return null;
  }

  static Future<Object?> showTextPopover({required BuildContext context, required String text}) {
    return showPopover(
      context: context,
      bodyBuilder: (context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          color: Colors.black,
          child: SingleChildScrollView(
            child: SelectableText(
              text, style: const TextStyle(color: Colors.white),
              showCursor: true,
              cursorColor: Colors.yellow,
              cursorWidth: 4,
              contextMenuBuilder: (context, editableTextState) {
                final TextEditingValue value = editableTextState.textEditingValue;
                final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: buttonItems,
                );
              },
            ),
          ),
        ),
      ),
      direction: PopoverDirection.bottom,
      width: 700,
      height: 400,
      arrowHeight: 15,
      arrowWidth: 30,
      backgroundColor: Colors.black,
    );
  }
}

void main() {
  var parse = ConditionUtils.parse("(path MatchesPath '/products/*') and (request.verb = 'GET')");
  print('Verb=${ConditionUtils.getVerb(parse)}');
}