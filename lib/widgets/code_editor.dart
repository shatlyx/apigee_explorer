import 'dart:async';

import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/providers/internal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:provider/provider.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:xml/xml.dart';

class CodeEditor extends StatefulWidget {
  final FileRepresentation file;
  const CodeEditor({super.key, required this.file});

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {

  late CodeController controller;
  List<CodeSnippet> codeSnippets = [];
  late FileRepresentation _currentFile;
  late Timer _saveTimer;

  @override
  void initState() {
    super.initState();
    print("initState Code Editor with key ${widget.key}......");
    _currentFile = FileRepresentation(
      name: widget.file.name,
      contentType: widget.file.contentType,
      content: widget.file.content,
      fileRepresentationType: widget.file.fileRepresentationType,
    );
    controller = CodeController(
      text: _currentFile.content,
      analyzer: const DefaultLocalAnalyzer(),
      language: _getLanguage(_currentFile.contentType),
    );

    controller.autocompleter.setCustomWords(['context.getVariable("")', 'context.setVariable("", "")']);
    controller.addListener(_listenToModifications);
    _saveTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _autoSaveFile();
    });
  }

  void _autoSaveFile() {
    if (controller.code.text != _currentFile.content) {
      if (_currentFile.contentType == FileContentType.xml) {
        try {
          XmlDocument.parse(controller.code.text);
          _currentFile = Provider.of<ApigeeProvider>(context, listen: false)
              .saveFileRepresentation(
            file: _currentFile.name,
            type: _currentFile.fileRepresentationType!,
            content: controller.code.text ?? '',
          );
        } catch(e) {
          print('XML parsing error');
        }
      } else {
        _currentFile = Provider.of<ApigeeProvider>(context, listen: false)
            .saveFileRepresentation(
          file: _currentFile.name,
          type: _currentFile.fileRepresentationType!,
          content: controller.code.text ?? '',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("build Code Editor with key ${widget.key}......");
    return Consumer<ApigeeProvider>(
      builder: (context, ref, _) {
        if (_currentFile.contentType == FileContentType.xml) {
          var xmlFileIdentification = _currentFile.identifyXmlFileIdentification();
          codeSnippets = ref.codeSnippets[xmlFileIdentification.type] ?? [];
        }
        return CodeTheme(
          data: CodeThemeData(styles: monokaiSublimeTheme),
          child: Container(
            color: Colors.black,
            child: SingleChildScrollView(
              child: StickyHeader(
                header: Container(
                  height: 40.0,
                  color: Colors.black,
                  alignment: Alignment.centerLeft,
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    children: [
                      IconButton(
                        onPressed: controller.code.text != _currentFile.content ? _autoSaveFile : null,
                        icon: controller.code.text != _currentFile.content
                            ? const Icon(Icons.save, color: Colors.white,)
                            : const Icon(Icons.check_circle, color: Colors.green,)
                      ),
                      for (CodeSnippet snippet in codeSnippets)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.blue.shade100,
                            ),
                            icon: const Icon(Icons.code, color: Colors.white,),
                            onPressed: () {
                              ref.insertCodeSnippet(file: _currentFile, snippet: snippet);
                            },
                            label: Text(snippet.label, style: const TextStyle(color: Colors.white),),
                          ),
                        ),
                    ],
                  ),
                ),
                content: CodeField(controller: controller,)
              ),
            ),
          ),
        );
      }
    );
  }

  _getLanguage(FileContentType contentType) {
    switch (contentType) {
      case FileContentType.xml: return xml;
      case FileContentType.js: return javascript;
      case FileContentType.py: return python;
      case FileContentType.yaml: return yaml;
      default: return javascript;
    }
  }

  @override
  void dispose() {
    print("Disposed Code Editor with key ${widget.key} ........");
    controller.removeListener(_listenToModifications);
    controller.dispose();
    _saveTimer.cancel();
    super.dispose();
  }


  void _listenToModifications() {
    if (controller.code.text != _currentFile.content) {
      setState(() {

      });
    }
  }
}
