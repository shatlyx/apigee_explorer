import 'package:apigee_explorer/model/policies/policy.dart';
import 'package:apigee_explorer/service/parsing_service.dart';
import 'package:apigee_explorer/utils/constants.dart';
import 'package:petitparser/core.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

class FileRepresentation {
  String name;
  FileContentType contentType;
  String? content;

  FileRepresentation({required this.name, required this.contentType, this.content});

  XmlFileIdentification identifyXmlFileIdentification() {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.identifyXmlFileRepresentation(document.rootElement);
    }
    return XmlFileIdentification(
        type: FileType.other,
        name: ""
    );
  }

  Flow? getPreFlowData({required Map<String, Policy> policies}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractFlow(root: document.rootElement, elementName: "PreFlow", policies: policies);
    }
    return Flow(name: "PreFlow", request: [], response: []);
  }

  Flow? getPostFlowData({required Map<String, Policy> policies}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractFlow(root: document.rootElement, elementName: "PostFlow", policies: policies);
    }
    return Flow(name: "PostFlow", request: [], response: []);
  }

  Flow? getPostClientFlowData({required Map<String, Policy> policies}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractFlow(root: document.rootElement, elementName: "PostClientFlow", policies: policies);
    }
    return Flow(name: "PostClientFlow", request: [], response: []);
  }

  List<Flow>? getConditionalFlowsData({required Map<String, Policy> policies}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractConditionalFlows(root: document.rootElement, policies: policies);
    }
    return null;
  }

  String? getEndpointDescription() {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractDescription(root: document.rootElement,);
    }
    return null;
  }
}

class ApiProxyFiles {
  FileRepresentation apiProxyDescriptor;
  List<FileRepresentation> policiesFiles;
  List<FileRepresentation> proxiesFiles;
  List<FileRepresentation> targetsFiles;
  List<FileRepresentation> jsResourcesFiles;
  List<FileRepresentation> oasResourcesFiles;
  List<FileRepresentation> javaResourcesFiles;
  List<FileRepresentation> pythonResourcesFiles;

  ApiProxyFiles(
      {
        required this.apiProxyDescriptor,
        required this.policiesFiles,
        required this.proxiesFiles,
        required this.targetsFiles,
        required this.jsResourcesFiles,
        required this.oasResourcesFiles,
        required this.javaResourcesFiles,
        required this.pythonResourcesFiles,
      });

  Map<String, Policy> getPolicies() {
    return { for (var e in policiesFiles) p.basenameWithoutExtension(e.name) : Policy.of(e) };
  }

  List<ProxyEndpointRepresentation> getProxyEndpointsData(Map<String, Policy> policies) {
    return proxiesFiles
        .map((fileRepresentation) => fromProxyEndpoint(fileRepresentation: fileRepresentation, policies: policies))
        .cast<ProxyEndpointRepresentation>()
        .toList();
  }

  ProxyEndpointRepresentation fromProxyEndpoint({required FileRepresentation fileRepresentation, required Map<String, Policy> policies}) {
    return ProxyEndpointRepresentation(
      name: p.basenameWithoutExtension(fileRepresentation.name),
      preFlow: fileRepresentation.getPreFlowData(policies: policies),
      postFlow: fileRepresentation.getPostFlowData(policies: policies),
      description: fileRepresentation.getEndpointDescription(),
      flows: fileRepresentation.getConditionalFlowsData(policies: policies),
      postClientFlow: fileRepresentation.getPostClientFlowData(policies: policies),
      //Add Faults
    );
  }
}

class ProxyEndpointRepresentation {
  String name;
  String? description;
  Flow? preFlow;
  Flow? postFlow;
  Flow? postClientFlow;
  List<Flow>? flows;
  List<FaultRule>? faultRules;
  List<DefaultFaultRule>? defaultFaultRules;

  ProxyEndpointRepresentation(
      {required this.name,
      this.description,
      this.preFlow,
      this.postFlow,
      this.postClientFlow,
      this.flows,
      this.faultRules,
      this.defaultFaultRules});
}

class Flow {
  String name;
  String? description;
  List<FlowStep> request;
  List<FlowStep> response;
  Result<dynamic>? condition;

  Flow({required this.name, required this.request, required this.response, this.condition, this.description,});
}

class FlowStep {
  String internalId;
  Policy? policy;
  Result<dynamic>? condition;

  FlowStep({this.policy, this.condition}) : internalId = uuid.v4().toString();
}

class FaultRule {
  String name;
  List<FlowStep> steps;
  Result<dynamic>? condition;

  FaultRule({required this.name, required this.steps, this.condition});
}

class DefaultFaultRule extends FaultRule {
  bool alwaysEnforce;

  DefaultFaultRule({required super.name, required super.steps, super.condition, this.alwaysEnforce = false});

}

class PolicyAnalysis {
  Set<String>? inputs;
  Set<String>? outputs;

  PolicyAnalysis({this.inputs, this.outputs});
}

class XmlFileIdentification {
  String name;
  FileType type;
  bool enabled;
  bool continueOnError;

  XmlFileIdentification({required this.name, this.type = FileType.other, this.enabled = true, this.continueOnError = false,});
}

enum FileContentType {
  xml, js, jar, py, yaml
}

enum FileType {
  //Other
  other,
  //Descriptors
  apiProxyDescriptor, proxyDescriptor, targetDescriptor,
  //Cache
  policyInvalidateCache, policyPopulateCache, policyLookupCache, policyResponseCache,
  //Quota
  policyQuota, policyResetQuota, policySpikeArrest,
  //Mediation
  policyAccessEntity, policyAssignMessage, policyExtractVariables, policyJsonToXml,
  policyKeyValueMap, policyOasValidation, policyRaiseFault, policySoapMessageValidation,
  policyXmlToJson, policyXslTransform,
  //Security
  policyAccessControl, policyBasicAuthentication, policyHmac, policyJsonThreatProtection,
  policyDecodeJws, policyGenerateJws, policyVerifyJws, 
  policyDecodeJwt, policyGenerateJwt, policyVerifyJwt,
  policyLdap, 
  policyOauthV2InfoDelete, policyOauthV2InfoGet, policyOauthV2InfoSet,
  policyRegexProtection, policySamlAssertionProtection, policyGenerateSamlAssertion, policyValidateSamlAssertion,
  policyVerifyApiKey, policyXmlThreatProtection,
    //OAuthV2 Operations
  policyOauthV2VerifyAccessToken, policyOauthV2GenerateAccessToken,
  policyOauthV2GenerateAuthorizationCode, policyOauthV2RefreshAccessToken,
  policyOauthV2GenerateAccessTokenImplicitGrant, policyOauthV2Revoke,
  //Extension
  policyExtensionCallout, policyFlowCallout, policyJavaCallout, policyJsCallout, policyServiceCallout,
  policyPyhtonCallout, policyMessageLogging, policyStatisticsCollector,
  //Resources
  jsResource, javaResource, pythonResource, yamlResource,
}

extension FileContentTypeExtension on FileType {
  String get icon => "assets/images/icons/$name.png";
}

enum Phase {request, response}