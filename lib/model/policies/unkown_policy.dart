import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/model/policies/policy.dart';

class UnknownPolicy extends Policy {

  final XmlFileIdentification xmlFileIdentification;
  final String content;

  UnknownPolicy({required this.xmlFileIdentification, required this.content});

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
    // TODO: implement fetchInputs
    return {};
  }

  @override
  Set<String> fetchOutputs() {
    // TODO: implement fetchOutputs
    return {};
  }

  @override
  Set<String> getErrors() {
    // TODO: implement getErrors
    return {};
  }

  @override
  Set<String> getWarnings() {
    // TODO: implement getWarnings
    return {};
  }

  @override
  bool isValid() {
    // TODO: implement isValid
    return true;
  }


}