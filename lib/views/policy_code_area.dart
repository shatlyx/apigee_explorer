
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

class PolicyCodeArea extends StatelessWidget {
  const PolicyCodeArea({
    super.key,
    required CodeController controller,
  }) : _controller = controller;

  final CodeController _controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Stack(
        children: [
          Container(
            height: 500,
            color: Colors.black,
            child: CodeTheme(
              data: CodeThemeData(styles: monokaiSublimeTheme),
              child: SingleChildScrollView(
                child: CodeField(
                  controller: _controller,
                ),
              ),
            ),
          ),
          Positioned(
              top: 0,
              right: 0,
              child: ButtonBar(
                children: [
                  InkWell(
                    child: const Icon(Icons.question_mark, color: Colors.white,),
                    onTap: () => _controller.analyzeCode(),
                  ),
                  Icon(Icons.add, color: Colors.white,),
                  Icon(Icons.ac_unit, color: Colors.white,),
                  Icon(Icons.access_alarm_rounded, color: Colors.white,),
                ],
              )
          )
        ],
      ),
    );
  }
}