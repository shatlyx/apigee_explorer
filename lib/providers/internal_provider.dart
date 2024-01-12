import 'package:apigee_explorer/model/internal.dart' as internal;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../model/policies/policy.dart';
import '../service/files_service.dart';

class ApigeeProvider extends ChangeNotifier {

  internal.ApiProxyFiles? _apiProxyFiles;
  List<internal.ProxyEndpointRepresentation> _proxyEndpoints = [];
  Map<String, Policy> _policies = {};
  internal.Flow? _selectedFlow;
  String? _selectedProxyEndpoint;
  //File editor
  final List<internal.FileRepresentation> _openFiles = [];
  String? _selectedOpenFileName;

  ApigeeProvider() {
    readApiProxyFolder('/Users/monta/Downloads/apigee/first-proxy/apiproxy');
  }

  List<internal.ProxyEndpointRepresentation> get proxyEndpoints => _proxyEndpoints;
  internal.Flow? get selectedFlow => _selectedFlow;

  List<internal.FileRepresentation> get openFiles => _openFiles;
  String? get selectedOpenFileName => _selectedOpenFileName;

  void openXmlFile(String name) {
    if (!_openFiles.any((element) => p.basenameWithoutExtension(element.name) == name)) {
      _openFiles.add(_apiProxyFiles!.policiesFiles.firstWhere((element) => p.basenameWithoutExtension(element.name) == name));
    }
    _selectedOpenFileName = name;
    notifyListeners();
  }

  void closeFile(int index) {
    _openFiles.removeAt(index);
    if (_openFiles.isEmpty) {
      _selectedOpenFileName = null;
    } else {
      _selectedOpenFileName = p.basenameWithoutExtension(_openFiles[index].name);
    }
    notifyListeners();
  }

  int? getSelectedOpenFileIndex() {
    return _selectedOpenFileName != null ? _openFiles.indexWhere((element) => p.basenameWithoutExtension(element.name) == _selectedOpenFileName) : null;
  }

  void selectOpenFileName(int index) {
    _selectedOpenFileName = p.basenameWithoutExtension(_openFiles[index].name);
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
      _selectedFlow = selectedProxyEndpoint.flows != null && selectedProxyEndpoint.flows!.isNotEmpty ? selectedProxyEndpoint.flows!.first : null;
    }
  }

  void selectFlow({required String proxyEndpointName, required String flowName}) {
    if (_selectedProxyEndpoint != null && proxyEndpointName != _selectedProxyEndpoint) {
      _selectedProxyEndpoint = proxyEndpointName;
    }
    if (flowName == "PreFlow") {
      _selectedFlow = _proxyEndpoints.where((element) => element.name == proxyEndpointName)
          .first
          .preFlow;
    } else if (flowName == "PostFlow") {
      _selectedFlow = _proxyEndpoints.where((element) => element.name == proxyEndpointName)
          .first
          .postFlow;
    } else if (flowName == "PostClientFlow") {
      _selectedFlow = _proxyEndpoints.where((element) => element.name == proxyEndpointName)
          .first
          .postClientFlow;
    } else {
      _selectedFlow = _proxyEndpoints
          .where((element) => element.name == proxyEndpointName)
          .expand((element) => element.flows!)
          .where((element) => element.name == flowName)
          .firstOrNull;
    }
    print("Selected flow $_selectedProxyEndpoint > ${_selectedFlow!.name}");
    notifyListeners();
  }

  internal.ProxyEndpointRepresentation getSelectedProxyEndpoint() {
    return proxyEndpoints.where((element) => element.name == _selectedProxyEndpoint).first;
  }


}