import 'package:apigee_explorer/model/internal.dart';
import 'package:apigee_explorer/model/policies/extension/javascript_policy.dart';
import 'package:apigee_explorer/model/policies/mediation/assign_message_policy.dart';
import 'package:apigee_explorer/model/policies/unkown_policy.dart';

abstract class Policy {
  XmlFileIdentification getIdentifyXmlFileIdentification();
  String getContent();
  Set<String> fetchInputs();
  Set<String> fetchOutputs();
  bool isValid();
  Set<String> getErrors();
  Set<String> getWarnings();

  static Policy of(FileRepresentation fileRepresentation) {
    var identifyXmlFileIdentification = fileRepresentation.identifyXmlFileIdentification();
    switch(identifyXmlFileIdentification.type) {
      case FileType.policyJsCallout:
        return JavascriptPolicy(xmlFileIdentification: identifyXmlFileIdentification, content: fileRepresentation.content ?? '');
      case FileType.policyAssignMessage:
        return AssignMessagePolicy(xmlFileIdentification: identifyXmlFileIdentification, content: fileRepresentation.content ?? '');
      default:
        return UnknownPolicy(xmlFileIdentification: identifyXmlFileIdentification, content: fileRepresentation.content ?? '');
    }
  }
}