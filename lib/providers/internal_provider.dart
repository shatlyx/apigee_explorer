import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:apigee_explorer/utils/constants.dart';
import "package:collection/collection.dart";
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../model/policies/policy.dart';
import '../service/files_service.dart';

class ApigeeProvider extends ChangeNotifier {

  internal.ApiProxyFiles? _apiProxyFiles;
  List<internal.EndpointsRepresentation> _proxyEndpoints = [];
  List<internal.EndpointsRepresentation> _targetEndpoints = [];
  Map<String, Policy> _policies = {};
  internal.Flow? _selectedProxyEndpointFlow;
  internal.Flow? _selectedTargetEndpointFlow;
  String? _selectedProxyEndpoint;
  String? _selectedTargetEndpoint;
  //File editor
  final List<internal.FileRepresentation> _openFiles = [];
  String? _selectedOpenFileName;
  //Resource File editor
  //final List<internal.FileRepresentation> _openResourceFiles = [];
  //String? _selectedOpenResourceFileName;
  final Set<internal.FileType> _openableResourceTypes = {internal.FileType.policyJsCallout, internal.FileType.policyPyhtonCallout};
  //Code Snippets
  //TODO: Read from external file
  final Map<internal.FileType, List<internal.CodeSnippet>> codeSnippets = {
    internal.FileType.policyAssignMessage: [
      internal.CodeSnippet(label: "Assign Variable", snippet: "<AssignVariable><Name>name</Name><Value/><Ref/></AssignVariable>",),
      internal.CodeSnippet(label: "Copy Request", snippet: "<Copy source=\"request\"><Headers/><QueryParams/><FormParams/><Payload></Payload><Verb/><StatusCode/><ReasonPhrase/><Path/></Copy>",),
      internal.CodeSnippet(label: "Remove", snippet: "<Remove><Headers><Header name=\"h1\"/></Headers><QueryParams><QueryParam name=\"q1\"/></QueryParams><FormParams><FormParam name=\"f1\"/></FormParams><Payload></Payload></Remove>",),
      internal.CodeSnippet(label: "Add", snippet: "<Add><Headers/><QueryParams/><FormParams/></Add>",),
      internal.CodeSnippet(label: "Set", snippet: "<Set><Headers/><QueryParams/><FormParams/><Path/></Set>",),
    ]
  };

  ApigeeProvider() {
    readApiProxyFolder('/Users/monta/Downloads/apigee/first-proxy/apiproxy');
  }

  List<internal.EndpointsRepresentation> get proxyEndpoints => _proxyEndpoints;
  List<internal.EndpointsRepresentation> get targetEndpoints => _targetEndpoints;
  internal.Flow? get selectedProxyEndpointFlow => _selectedProxyEndpointFlow;
  internal.Flow? get selectedTargetEndpointFlow => _selectedTargetEndpointFlow;

  Map<internal.FileType, List<internal.FileRepresentation>> get resources => _apiProxyFiles != null
      ? {
          internal.FileType.jsResource: _apiProxyFiles!.jsResourcesFiles,
          internal.FileType.javaResource: _apiProxyFiles!.javaResourcesFiles,
          internal.FileType.pythonResource: _apiProxyFiles!.pythonResourcesFiles,
          internal.FileType.yamlResource: _apiProxyFiles!.oasResourcesFiles,
        }
        : {};

  List<internal.FileRepresentation> get openFiles => _openFiles;
  String? get selectedOpenFileName => _selectedOpenFileName;

  void editFile({required String name, internal.FileRepresentationType? type}) {
    List<internal.FileRepresentation> filesList;
    if (!_openFiles.any((element) => p.basenameWithoutExtension(element.name) == name)) {
      switch (type) {
        case internal.FileRepresentationType.apiDescriptor:
          filesList = [_apiProxyFiles!.apiProxyDescriptor];
          break;
        case internal.FileRepresentationType.proxyEndpointDescriptor:
          filesList = _apiProxyFiles!.proxiesFiles;
          break;
        case internal.FileRepresentationType.targetEndpointDescriptor:
          filesList = _apiProxyFiles!.targetsFiles;
          break;
        case internal.FileRepresentationType.policy:
          filesList = _apiProxyFiles!.policiesFiles;
          break;
        case internal.FileRepresentationType.jsResource:
          filesList = _apiProxyFiles!.jsResourcesFiles;
          break;
        case internal.FileRepresentationType.pythonResource:
          filesList = _apiProxyFiles!.pythonResourcesFiles;
          break;
        case internal.FileRepresentationType.yamlResource:
          filesList = _apiProxyFiles!.oasResourcesFiles;
          break;
        default:
          filesList = [_apiProxyFiles!.apiProxyDescriptor] + _apiProxyFiles!.proxiesFiles
              + _apiProxyFiles!.targetsFiles + _apiProxyFiles!.policiesFiles
              + _apiProxyFiles!.jsResourcesFiles + _apiProxyFiles!.pythonResourcesFiles
              + _apiProxyFiles!.oasResourcesFiles;
      }
      var file = filesList.firstWhere((element) => p.basenameWithoutExtension(element.name) == name);
      _openFiles.add(file);
    }
    _selectedOpenFileName = name;
    notifyListeners();
  }

  void closeFile(String name) {
    var index = _openFiles.indexWhere((e) => p.basenameWithoutExtension(name) == p.basenameWithoutExtension(e.name));
    _openFiles.removeAt(index);
    if (_openFiles.isEmpty) {
      _selectedOpenFileName = null;
    } else {
      _selectedOpenFileName = p.basenameWithoutExtension(_openFiles[index > 0 ? index-1 : index].name);
    }
    notifyListeners();
  }

  internal.FileRepresentation? getSelectedOpenFile() {
    return _selectedOpenFileName != null ? _openFiles.where((element) => p.basenameWithoutExtension(element.name) == _selectedOpenFileName).firstOrNull : null;
  }

  void selectOpenFileName(String fileName) {
    _selectedOpenFileName = p.basenameWithoutExtension(fileName);
    notifyListeners();
  }

  void readApiProxyFolder(String proxyFolder) {
    _apiProxyFiles = FilesService.parseProxyFolder(proxyFolder);
    if (_apiProxyFiles != null) {
      _initWorkData();
    }
  }

  void reorderOpenFiles(int i, int j) {
    var e = _openFiles[i];
    _openFiles[i] = _openFiles[j];
    _openFiles[j] = e;
    notifyListeners();
  }

  void _initWorkData() {
    _policies = _apiProxyFiles?.getPolicies() ?? {};
    _proxyEndpoints = _apiProxyFiles?.getProxyEndpointsData(_policies) ?? [];
    if (_proxyEndpoints.isNotEmpty) {
      var selectedProxyEndpoint = _proxyEndpoints.first;
      _selectedProxyEndpoint = selectedProxyEndpoint.name;
      _selectedProxyEndpointFlow = selectedProxyEndpoint.flows != null && selectedProxyEndpoint.flows!.isNotEmpty ? selectedProxyEndpoint.flows!.first : null;
    }
    _targetEndpoints = _apiProxyFiles?.getTargetEndpointsData(_policies) ?? [];
    if (_targetEndpoints.isNotEmpty) {
      var selectedTargetEndpoint = _targetEndpoints.first;
      _selectedTargetEndpoint = selectedTargetEndpoint.name;
      _selectedTargetEndpointFlow = selectedTargetEndpoint.flows != null && selectedTargetEndpoint.flows!.isNotEmpty ? selectedTargetEndpoint.flows!.first : null;
    }
  }

  void selectProxyEndpointFlow({required String proxyEndpointName, required String flowName}) {
    if (_selectedProxyEndpoint != null && proxyEndpointName != _selectedProxyEndpoint) {
      _selectedProxyEndpoint = proxyEndpointName;
    }
    if (fixedFlows.contains(flowName)) {
      _selectedProxyEndpointFlow = null;
    } else {
      _selectedProxyEndpointFlow = _proxyEndpoints
          .where((element) => element.name == proxyEndpointName)
          .expand((element) => element.flows!)
          .where((element) => element.name == flowName)
          .firstOrNull;
    }
    notifyListeners();
  }

  internal.EndpointsRepresentation getSelectedProxyEndpoint() {
    return proxyEndpoints.where((element) => element.name == _selectedProxyEndpoint).first;
  }

  void selectTargetEndpointFlow({required String targetEndpointName, required String flowName}) {
    if (_selectedTargetEndpoint != null && targetEndpointName != _selectedTargetEndpoint) {
      _selectedTargetEndpoint = targetEndpointName;
    }
    if (fixedFlows.contains(flowName)) {
      _selectedTargetEndpointFlow = null;
    } else {
      _selectedTargetEndpointFlow = _targetEndpoints
          .where((element) => element.name == targetEndpointName)
          .expand((element) => element.flows!)
          .where((element) => element.name == flowName)
          .firstOrNull;
    }
    notifyListeners();
  }

  internal.EndpointsRepresentation getSelectedTargetEndpoint() {
    return targetEndpoints.where((element) => element.name == _selectedTargetEndpoint).first;
  }

  Map<internal.FileType, List<Policy>> getPoliciesByFileType() {
    return groupBy(_policies.values, (Policy obj) => obj.getIdentifyXmlFileIdentification().type);
  }

  void insertCodeSnippet({required internal.FileRepresentation file, required internal.CodeSnippet snippet}) {
    file.insertXmlCodeSnippet(xpath: snippet.xpath ?? "/", snippet: snippet.snippet);
    _apiProxyFiles!.updateFile(file);
    notifyListeners();
  }

  void updateFileContent({required internal.FileRepresentation file, required String content}) {
    file.content = content;
    _apiProxyFiles!.updateFile(file);
    _initWorkData();
    notifyListeners();
  }

  Map<String,List<internal.FlowPolicyUsage>> findPolicyFlowsUsage({required String policyName}) {
    Map<String,List<internal.FlowPolicyUsage>> result = {};
    for (var proxy in _proxyEndpoints) {
      List<internal.FlowPolicyUsage> proxyEndpointResult = [];
      proxyEndpointResult.addAll(proxy.preFlow?.getPolicyUsage(policyName: policyName,) ?? []);
      proxyEndpointResult.addAll(proxy.postFlow?.getPolicyUsage(policyName: policyName,) ?? []);
      proxyEndpointResult.addAll(proxy.postClientFlow?.getPolicyUsage(policyName: policyName,) ?? []);
      proxyEndpointResult.addAll(proxy.flows?.expand((e) => e.getPolicyUsage(policyName: policyName,)) ?? []);
      //TODO Add FaultRules
      result[proxy.name] = proxyEndpointResult;
    }
    return result;
  }

  internal.FileRepresentation saveFileRepresentation({required String file, required internal.FileRepresentationType type, required String content}) {
    print("Saving $file");
    switch (type) {
      case internal.FileRepresentationType.policy:
        _apiProxyFiles!.policiesFiles = _updateFileRepresentation(
            filesSource: _apiProxyFiles!.policiesFiles,
            fileName: file,
            content: content);
        _initWorkData();
        notifyListeners();
        return _apiProxyFiles!.policiesFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(file));
      case internal.FileRepresentationType.jsResource:
        _apiProxyFiles!.jsResourcesFiles = _updateFileRepresentation(
            filesSource: _apiProxyFiles!.jsResourcesFiles,
            fileName: file,
            content: content);
        _initWorkData();
        notifyListeners();
        return _apiProxyFiles!.jsResourcesFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(file));
      case internal.FileRepresentationType.pythonResource:
        _apiProxyFiles!.pythonResourcesFiles = _updateFileRepresentation(
            filesSource: _apiProxyFiles!.pythonResourcesFiles,
            fileName: file,
            content: content);
        _initWorkData();
        notifyListeners();
        return _apiProxyFiles!.pythonResourcesFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(file));
      case internal.FileRepresentationType.yamlResource:
        _apiProxyFiles!.oasResourcesFiles = _updateFileRepresentation(
            filesSource: _apiProxyFiles!.oasResourcesFiles,
            fileName: file,
            content: content);
        _initWorkData();
        notifyListeners();
        return _apiProxyFiles!.oasResourcesFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(file));
      case internal.FileRepresentationType.proxyEndpointDescriptor:
        _apiProxyFiles!.proxiesFiles = _updateFileRepresentation(
            filesSource: _apiProxyFiles!.proxiesFiles,
            fileName: file,
            content: content);
        _initWorkData();
        notifyListeners();
        return _apiProxyFiles!.proxiesFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(file));
      case internal.FileRepresentationType.targetEndpointDescriptor:
        _apiProxyFiles!.targetsFiles = _updateFileRepresentation(
            filesSource: _apiProxyFiles!.targetsFiles,
            fileName: file,
            content: content);
        _initWorkData();
        notifyListeners();
        return _apiProxyFiles!.targetsFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(file));
      default: throw Exception("not implemented");
    }
    throw Exception("not implemented");
  }

  List<internal.FileRepresentation> _updateFileRepresentation({required List<internal.FileRepresentation> filesSource, required String fileName, required String content}) {
    var index = filesSource.indexWhere((element) => p.basenameWithoutExtension(element.name) == p.basenameWithoutExtension(fileName));
    if (index >= 0) {
      filesSource[index] = internal.FileRepresentation(
        name: filesSource[index].name,
        contentType: filesSource[index].contentType,
        fileRepresentationType: filesSource[index].fileRepresentationType,
        content: content,
      );
    }
    return filesSource;
  }

}