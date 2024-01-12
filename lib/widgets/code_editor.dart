import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:provider/provider.dart';

class CodeEditor extends StatelessWidget {
  final FileRepresentation file;
  const CodeEditor({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    CodeController controller = CodeController(
      text: file.content,
      analyzer: const DefaultLocalAnalyzer(),
      language: _getLanguage(file.contentType),
    );
    controller.autocompleter.setCustomWords(['flow.oauth.idp', 'flow.oauth.accessToken', 'flow.oauth.idpType', 'flow.oauth.idToken','Set>\n</Set>']);
    controller.autocompleter.setText('set var', "yes we can");
    return Consumer<ApigeeProvider>(
      builder: (context, ref, _) => Container(
        color: Colors.black,
        child: SingleChildScrollView(
          child: CodeField(controller: controller,),
        ),
      ),
    );
  }


  _getLanguage(FileContentType contentType) {
    switch (contentType) {
      case FileContentType.xml: return xml;
      default: return javascript;
    }
  }
}
