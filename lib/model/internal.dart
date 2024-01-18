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
  FileRepresentationType? fileRepresentationType;

  FileRepresentation({required this.name, required this.contentType, this.content, this.fileRepresentationType,});

  XmlFileIdentification identifyXmlFileIdentification() {
    if (contentType == FileContentType.xml && content != null) {
      try {
        final document = XmlDocument.parse(content!);
        return ParsingService.identifyXmlFileRepresentation(
            document.rootElement);
      } catch(e) {
        print('XML parsing error');
      }
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

  FileRepresentation insertXmlCodeSnippet({required String xpath, required String snippet}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      final builder = XmlBuilder();
      builder.xml(snippet);
      // Split the path into individual node names

      // Find the parent node where you want to insert the new node
      document.rootElement.children.add(builder.buildFragment());
      document.rootElement.children;
      content = document.toXmlString(pretty: true);
    }
    return this;
  }

  List<FaultRule> getFaultRules({required Map<String, Policy> policies}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractFaultRules(root: document.rootElement, policies: policies);
    }
    return [];
  }

  DefaultFaultRule? getDefaultFaultRule({required Map<String, Policy> policies}) {
    if (contentType == FileContentType.xml && content != null) {
      final document = XmlDocument.parse(content!);
      return ParsingService.extractDefaultFaultRule(root: document.rootElement, policies: policies);
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

  List<EndpointsRepresentation> getProxyEndpointsData(Map<String, Policy> policies) {
    return proxiesFiles
        .map((fileRepresentation) => fromEndpoint(fileRepresentation: fileRepresentation, policies: policies))
        .cast<EndpointsRepresentation>()
        .toList();
  }

  List<EndpointsRepresentation> getTargetEndpointsData(Map<String, Policy> policies) {
    return targetsFiles
        .map((fileRepresentation) => fromEndpoint(fileRepresentation: fileRepresentation, policies: policies))
        .cast<EndpointsRepresentation>()
        .toList();
  }

  EndpointsRepresentation fromEndpoint({required FileRepresentation fileRepresentation, required Map<String, Policy> policies}) {
    return EndpointsRepresentation(
      name: p.basenameWithoutExtension(fileRepresentation.name),
      preFlow: fileRepresentation.getPreFlowData(policies: policies),
      postFlow: fileRepresentation.getPostFlowData(policies: policies),
      description: fileRepresentation.getEndpointDescription(),
      flows: fileRepresentation.getConditionalFlowsData(policies: policies),
      postClientFlow: fileRepresentation.getPostClientFlowData(policies: policies),
      faultRules: fileRepresentation.getFaultRules(policies: policies),
      defaultFaultRule: fileRepresentation.getDefaultFaultRule(policies: policies) ?? DefaultFaultRule.empty(),
    );
  }

  void updateFile(FileRepresentation file) {
    switch(file.fileRepresentationType) {
      case FileRepresentationType.apiDescriptor:
        apiProxyDescriptor = file;
        break;
      case FileRepresentationType.proxyEndpointDescriptor:
        var i = proxiesFiles.indexWhere((element) => element.name == file.name);
        proxiesFiles[i] = file;
        break;
      case FileRepresentationType.targetEndpointDescriptor:
        var i = targetsFiles.indexWhere((element) => element.name == file.name);
        targetsFiles[i] = file;
        break;
      case FileRepresentationType.policy:
        var i = policiesFiles.indexWhere((element) => element.name == file.name);
        policiesFiles[i] = file;
        break;
      case FileRepresentationType.yamlResource:
        var i = oasResourcesFiles.indexWhere((element) => element.name == file.name);
        oasResourcesFiles[i] = file;
        break;
      case FileRepresentationType.jsResource:
        var i = jsResourcesFiles.indexWhere((element) => element.name == file.name);
        jsResourcesFiles[i] = file;
        break;
      case FileRepresentationType.pythonResource:
        var i = pythonResourcesFiles.indexWhere((element) => element.name == file.name);
        pythonResourcesFiles[i] = file;
        break;
      default: return;
    }
  }
}

class EndpointsRepresentation {
  String name;
  String? description;
  Flow? preFlow;
  Flow? postFlow;
  Flow? postClientFlow;
  List<Flow>? flows;
  List<FaultRule>? faultRules;
  DefaultFaultRule defaultFaultRule;

  EndpointsRepresentation(
      {required this.name,
      this.description,
      this.preFlow,
      this.postFlow,
      this.postClientFlow,
      this.flows,
      this.faultRules,
      required this.defaultFaultRule});
}

class Flow {
  String name;
  String? description;
  List<FlowStep> request;
  List<FlowStep> response;
  Result<dynamic>? condition;

  Flow({required this.name, required this.request, required this.response, this.condition, this.description,});

  List<FlowPolicyUsage> getPolicyUsage({required policyName,}) {
    List<FlowPolicyUsage> result = [];
    int requestOccurrences = request.where((element) => p.basenameWithoutExtension(element.policy!.getIdentifyXmlFileIdentification().name) == policyName).length;
    int responseOccurrences = response.where((element) => p.basenameWithoutExtension(element.policy!.getIdentifyXmlFileIdentification().name) == policyName).length;
    if (requestOccurrences > 0 || responseOccurrences > 0) {
      result.add(FlowPolicyUsage(flow: this, requestOccurrences: requestOccurrences, responseOccurrences: responseOccurrences,));
    }
    return result;
  }
}

class FlowPolicyUsage {
  Flow flow;
  int requestOccurrences;
  int responseOccurrences;

  FlowPolicyUsage(
      {
        required this.flow,
        this.requestOccurrences = 0,
        this.responseOccurrences = 0,
      });
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

  static DefaultFaultRule empty() {
    return DefaultFaultRule(name: "default", steps: [], alwaysEnforce: false,);
  }

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
  String? resourceUrl;

  XmlFileIdentification({required this.name, this.type = FileType.other, this.enabled = true, this.continueOnError = false, this.resourceUrl,});
}

class CodeSnippet {
  String label;
  String snippet;
  String? xpath;

  CodeSnippet({required this.label, required this.snippet, this.xpath});
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
  String get label {
    switch(this) {
      case FileType.policyInvalidateCache: return "Cache - Invalidate";
      case FileType.policyPopulateCache: return "Cache - Populate";
      case FileType.policyLookupCache: return "Cache - Lookup";
      case FileType.policyResponseCache: return "Cache - Response";

      case FileType.policyQuota: return "Quota - Response";
      case FileType.policyResetQuota: return "Quota - Reset";
      case FileType.policySpikeArrest: return "Quota - SpikeArrest";

      case FileType.policyAccessEntity: return "Mediation - AccessEntity";
      case FileType.policyAssignMessage: return "Mediation - AssignMessage";
      case FileType.policyExtractVariables: return "Mediation - ExtractVariables";
      case FileType.policyJsonToXml: return "Mediation - JsonToXml";
      case FileType.policyKeyValueMap: return "Mediation - KeyValueMap";
      case FileType.policyOasValidation: return "Mediation - OasValidation";
      case FileType.policyRaiseFault: return "Mediation - RaiseFault";
      case FileType.policySoapMessageValidation: return "Mediation - SoapMessageValidation";
      case FileType.policyXmlToJson: return "Mediation - XmlToJson";
      case FileType.policyXslTransform: return "Mediation - XslTransform";

      case FileType.policyAccessControl: return "Security - AccessControl";
      case FileType.policyBasicAuthentication: return "Security - BasicAuthentication";
      case FileType.policyHmac: return "Security - HMAC";
      case FileType.policyJsonThreatProtection: return "Security - JsonThreatProtection";
      case FileType.policyDecodeJws: return "Security - DecodeJWS";
      case FileType.policyGenerateJws: return "Security - GenerateJWS";
      case FileType.policyVerifyJws: return "Security - VerifyJWS";
      case FileType.policyDecodeJwt: return "Security - DecodeJWT";
      case FileType.policyGenerateJwt: return "Security - GenerateJWT";
      case FileType.policyVerifyJwt: return "Security - VerifyJWT";
      case FileType.policyLdap: return "Security - LDAP";
      case FileType.policyOauthV2InfoDelete: return "Security - OauthV2InfoDelete";
      case FileType.policyOauthV2InfoGet: return "Security - OauthV2InfoGet";
      case FileType.policyOauthV2InfoSet: return "Security - OauthV2InfoSet";
      case FileType.policyRegexProtection: return "Security - RegexProtection";
      case FileType.policySamlAssertionProtection: return "Security - SamlAssertionProtection";
      case FileType.policyGenerateSamlAssertion: return "Security - GenerateSamlAssertion";
      case FileType.policyValidateSamlAssertion: return "Security - ValidateSamlAssertion";
      case FileType.policyVerifyApiKey: return "Security - VerifyApiKey";
      case FileType.policyXmlThreatProtection: return "Security - XmlThreatProtection";

      case FileType.policyOauthV2VerifyAccessToken: return "OauthV2 - VerifyAccessToken";
      case FileType.policyOauthV2GenerateAccessToken: return "OauthV2 - GenerateAccessToken";
      case FileType.policyOauthV2GenerateAuthorizationCode: return "OauthV2 - GenerateAuthorizationCode";
      case FileType.policyOauthV2RefreshAccessToken: return "OauthV2 - RefreshAccessToken";
      case FileType.policyOauthV2GenerateAccessTokenImplicitGrant: return "OauthV2 - GenerateAccessTokenImplicitGrant";
      case FileType.policyOauthV2Revoke: return "OauthV2 - Revoke";

      case FileType.policyExtensionCallout: return "Extension - ExtensionCallout";
      case FileType.policyFlowCallout: return "Extension - FlowCallout";
      case FileType.policyJavaCallout: return "Extension - JavaCallout";
      case FileType.policyJsCallout: return "Extension - JsCallout";
      case FileType.policyServiceCallout: return "Extension - ServiceCallout";
      case FileType.policyPyhtonCallout: return "Extension - PyhtonCallout";
      case FileType.policyMessageLogging: return "Extension - MessageLogging";
      case FileType.policyStatisticsCollector: return "Extension - StatisticsCollector";

      case FileType.jsResource: return "Javascript";
      case FileType.javaResource: return "Java";
      case FileType.pythonResource: return "Python";
      case FileType.yamlResource: return "YAML";

      default: name;
    }
    return name;
  }
}

enum Phase {request, response}
enum FileRepresentationType {apiDescriptor, proxyEndpointDescriptor, targetEndpointDescriptor, policy, jsResource, javaResource, pythonResource, yamlResource}
