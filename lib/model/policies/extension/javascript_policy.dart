import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/model/policies/policy.dart';

class JavascriptPolicy extends Policy {

  final XmlFileIdentification xmlFileIdentification;
  final String content;

  JavascriptPolicy({required this.xmlFileIdentification, required this.content});

  @override
  String getContent() {
    return content;
  }

  @override
  XmlFileIdentification getIdentifyXmlFileIdentification() {
    return xmlFileIdentification;
  }

  @override
  Set<String> fetchInputs() {
    return {};
  }

  @override
  Set<String> fetchOutputs() {
    return {};
  }

  @override
  Set<String> getErrors() {
    return {};
  }

  @override
  Set<String> getWarnings() {
    return {};
  }

  @override
  bool isValid() {
    return true;
  }


}