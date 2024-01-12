import 'package:apigee_explorer/utils/condition_utils.dart';
import 'package:xml/xml.dart';

import '../model/internal.dart';
import '../model/policies/policy.dart';

class ParsingService {

  static XmlFileIdentification identifyXmlFileRepresentation(XmlElement rootElement) {
    switch(rootElement.name.qualified) {
      //// Policies
    //Cache
      case "InvalidateCache": return resolvePolicyIdentification(FileType.policyInvalidateCache, rootElement);
      case "LookupCache": return resolvePolicyIdentification(FileType.policyLookupCache, rootElement);
      case "PopulateCache": return resolvePolicyIdentification(FileType.policyPopulateCache, rootElement);
      case "ResponseCache": return resolvePolicyIdentification(FileType.policyResponseCache, rootElement);
    //Quota
      case "Quota": return resolvePolicyIdentification(FileType.policyQuota, rootElement);
      case "ResetQuota": return resolvePolicyIdentification(FileType.policyResetQuota, rootElement);
      case "SpikeArrest": return resolvePolicyIdentification(FileType.policySpikeArrest, rootElement);
    //Mediation
      case "AccessEntity": return resolvePolicyIdentification(FileType.policyAccessEntity, rootElement);
      case "AssignMessage": return resolvePolicyIdentification(FileType.policyAssignMessage, rootElement);
      case "ExtractVariables": return resolvePolicyIdentification(FileType.policyExtractVariables, rootElement);
      case "JsonToXml": return resolvePolicyIdentification(FileType.policyJsonToXml, rootElement);
      case "KeyValueMapOperations": return resolvePolicyIdentification(FileType.policyKeyValueMap, rootElement);
      case "OasValidation": return resolvePolicyIdentification(FileType.policyOasValidation, rootElement);
      case "RaiseFault": return resolvePolicyIdentification(FileType.policyRaiseFault, rootElement);
      case "SoapMessageValidation": return resolvePolicyIdentification(FileType.policySoapMessageValidation, rootElement);
      case "XmlToJson": return resolvePolicyIdentification(FileType.policyXmlToJson, rootElement);
      case "XslTransform": return resolvePolicyIdentification(FileType.policyXslTransform, rootElement);
    //Security
      case "AccessControl": return resolvePolicyIdentification(FileType.policyAccessControl, rootElement);
      case "BasicAuthentication": return resolvePolicyIdentification(FileType.policyBasicAuthentication, rootElement);
      case "HMAC": return resolvePolicyIdentification(FileType.policyHmac, rootElement);
      case "JSONThreatProtection": return resolvePolicyIdentification(FileType.policyJsonThreatProtection, rootElement);
      case "DecodeJWS": return resolvePolicyIdentification(FileType.policyDecodeJws, rootElement);
      case "GenerateJWS": return resolvePolicyIdentification(FileType.policyGenerateJws, rootElement);
      case "VerifyJWS": return resolvePolicyIdentification(FileType.policyVerifyJws, rootElement);
      case "DecodeJWT": return resolvePolicyIdentification(FileType.policyDecodeJwt, rootElement);
      case "GenerateJWT": return resolvePolicyIdentification(FileType.policyGenerateJwt, rootElement);
      case "VerifyJWT": return resolvePolicyIdentification(FileType.policyVerifyJwt, rootElement);
      case "Ldap": return resolvePolicyIdentification(FileType.policyLdap, rootElement);
      case "DeleteOAuthV2Info": return resolvePolicyIdentification(FileType.policyOauthV2InfoDelete, rootElement);
      case "GetOAuthV2Info": return resolvePolicyIdentification(FileType.policyOauthV2InfoGet, rootElement);
      case "SetOAuthV2Info": return resolvePolicyIdentification(FileType.policyOauthV2InfoSet, rootElement);
      case "RevokeOAuthV2": return resolvePolicyIdentification(FileType.policyOauthV2Revoke, rootElement);
      case "OAuthV2":
        String? operation = rootElement.siblingElements
            .where((e) => e.name.qualified == "Operation")
            .map((e) => e.innerText)
            .firstOrNull;
        if (operation != null) {
          switch(operation) {
            case "VerifyAccessToken": return resolvePolicyIdentification(FileType.policyOauthV2VerifyAccessToken, rootElement);
            case "GenerateAccessToken": return resolvePolicyIdentification(FileType.policyOauthV2GenerateAccessToken, rootElement);
            case "GenerateAccessTokenImplicitGrant": return resolvePolicyIdentification(FileType.policyOauthV2GenerateAccessTokenImplicitGrant, rootElement);
            case "GenerateAuthorizationCode": return resolvePolicyIdentification(FileType.policyOauthV2GenerateAuthorizationCode, rootElement);
            case "RefreshAccessToken": return resolvePolicyIdentification(FileType.policyOauthV2RefreshAccessToken, rootElement);
            default: return resolvePolicyIdentification(FileType.other, rootElement);
          }
        }
        return resolvePolicyIdentification(FileType.other, rootElement);
      case "RegularExpressionProtection": return resolvePolicyIdentification(FileType.policyRegexProtection, rootElement);
      case "GenerateSAMLAssertion": return resolvePolicyIdentification(FileType.policyGenerateSamlAssertion, rootElement);
      case "ValidateSAMLAssertion": return resolvePolicyIdentification(FileType.policyValidateSamlAssertion, rootElement);
      case "VerifyAPIKey": return resolvePolicyIdentification(FileType.policyVerifyApiKey, rootElement);
      case "XMLThreatProtection": return resolvePolicyIdentification(FileType.policyXmlThreatProtection, rootElement);
    //Extension
      case "ConnectorCallout": return resolvePolicyIdentification(FileType.policyExtensionCallout, rootElement);
      case "FlowCallout": return resolvePolicyIdentification(FileType.policyFlowCallout, rootElement);
      case "JavaCallout": return resolvePolicyIdentification(FileType.policyJavaCallout, rootElement);
      case "Javascript": return resolvePolicyIdentification(FileType.policyJsCallout, rootElement);
      case "MessageLogging": return resolvePolicyIdentification(FileType.policyMessageLogging, rootElement);
      case "Script": return resolvePolicyIdentification(FileType.policyPyhtonCallout, rootElement);
      case "ServiceCallout": return resolvePolicyIdentification(FileType.policyServiceCallout, rootElement);
      case "StatisticsCollector": return resolvePolicyIdentification(FileType.policyStatisticsCollector, rootElement);

      //// Descriptors
      case "APIProxy": return resolveDescriptorIdentification(FileType.apiProxyDescriptor, rootElement);
      case "ProxyEndpoint": return resolveDescriptorIdentification(FileType.proxyDescriptor, rootElement);
      case "TargetEndpoint": return resolveDescriptorIdentification(FileType.targetDescriptor, rootElement);

      default: return resolvePolicyIdentification(FileType.other, rootElement);
    }
  }

  static XmlFileIdentification resolvePolicyIdentification(FileType type, XmlElement rootElement) {
    return XmlFileIdentification(
      name: rootElement.getAttribute("name") ?? '',
      enabled: (rootElement.getAttribute("enabled") ?? "true") == "true",
      continueOnError: (rootElement.getAttribute("enabled") ?? "false") == "true",
      type: type,
    );
  }

  static XmlFileIdentification resolveDescriptorIdentification(FileType type, XmlElement rootElement) {
    return XmlFileIdentification(
      name: rootElement.getAttribute("name") ?? '',
      enabled: true,
      continueOnError: true,
      type: type,
    );
  }

  static Flow? extractFlow({required XmlElement root, required String elementName, required Map<String, Policy> policies}) {
    return root.findElements(elementName)
        .map((e) => mapFlow(e, policies))
        .firstOrNull ?? Flow(name: elementName, request: [], response: [])
    ;
  }

  static List<Flow> extractFlowList({required XmlElement root, required String elementName, required Map<String, Policy> policies}) {
    return root.findElements(elementName)
        .map((e) => mapFlow(e, policies))
        .toList()
    ;
  }

  static Flow mapFlow(XmlElement e, Map<String, Policy> policies) {
    return Flow(
          name: e.getAttribute("name") ?? '',
          request: extractSteps(root: e.findElements("Request").firstOrNull, policies: policies),
          response: extractSteps(root: e.findElements("Response").firstOrNull, policies: policies),
          condition: e.findElements("Condition").map((e) => e.innerText).map((e) => ConditionUtils.parse(e)).firstOrNull
        );
  }

  static List<FlowStep> extractSteps({XmlElement? root, required Map<String, Policy> policies}) {
    if (root == null) {
      return [];
    }
    return root.findElements("Step")
        .map((e) => extractStep(root: e, policies: policies))
        .toList();
  }

  static FlowStep extractStep({required XmlElement root, required Map<String, Policy> policies}) {
    return FlowStep(
      policy: root.findElements("Name").map((e) => e.innerText).map((e) => policies[e]).firstOrNull,
      condition: root.findElements("Condition").map((e) => e.innerText).where((e) => e.isNotEmpty).map((e) => ConditionUtils.parse(e)).firstOrNull,
    );
  }

  static String? extractDescription({required XmlElement root}) {
    return root.findElements("Description").map((e) => e.innerText).firstOrNull;
  }

  static List<Flow>? extractConditionalFlows({required XmlElement root, required Map<String, Policy> policies}) {
    return root.findElements("Flows").expand((e) => extractFlowList(root: e, elementName: "Flow", policies: policies)).cast<Flow>().toList();
  }
}