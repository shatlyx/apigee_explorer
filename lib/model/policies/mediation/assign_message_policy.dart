import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/model/policies/policy.dart';

class AssignMessagePolicy extends Policy {

  final XmlFileIdentification xmlFileIdentification;
  final String content;

  AssignMessagePolicy({required this.xmlFileIdentification, required this.content});

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
    return {"request.header.authorization", "request.header.correlationId", "flow.input"};
  }

  @override
  Set<String> fetchOutputs() {
    return {"flow.oauth.type", "flow.oauth.step", "flow.a.out"};
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