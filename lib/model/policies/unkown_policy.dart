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
    throw UnimplementedError();
  }

  @override
  Set<String> fetchOutputs() {
    // TODO: implement fetchOutputs
    throw UnimplementedError();
  }

  @override
  Set<String> getErrors() {
    // TODO: implement getErrors
    throw UnimplementedError();
  }

  @override
  Set<String> getWarnings() {
    // TODO: implement getWarnings
    throw UnimplementedError();
  }

  @override
  bool isValid() {
    // TODO: implement isValid
    throw UnimplementedError();
  }


}