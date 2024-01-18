import 'dart:io';
import 'package:apigee_explorer/exceptions/parsing_exceptions.dart';
import 'package:path/path.dart' as p;

import 'package:apigee_explorer/model/internal.dart';

class FilesService {

  static ApiProxyFiles parseProxyFolder(String folder) {
    final dir = Directory(folder);
    final File? proxyDescriptor = dir.listSync().toList().whereType<File>().where((file) => ".xml" == p.extension(file.path)).firstOrNull;
    final Directory? policiesFolder = dir.listSync().toList().whereType<Directory>().where((file) => "policies" == p.basenameWithoutExtension(file.path)).firstOrNull;
    final Directory? proxiesFolder = dir.listSync().toList().whereType<Directory>().where((file) => "proxies" == p.basenameWithoutExtension(file.path)).firstOrNull;
    final Directory? targetsFolder = dir.listSync().toList().whereType<Directory>().where((file) => "targets" == p.basenameWithoutExtension(file.path)).firstOrNull;
    final Directory? resourcesFolder = dir.listSync().toList().whereType<Directory>().where((file) => "resources" == p.basenameWithoutExtension(file.path)).firstOrNull;
    if (proxyDescriptor == null) {
      throw ProxyParsingException(cause: 'Proxy Descriptor File Not Found');
    }
    return ApiProxyFiles(
      apiProxyDescriptor: readXmlFile(proxyDescriptor, fileDescriptorType: FileRepresentationType.apiDescriptor),
      proxiesFiles: proxiesFolder != null ? readXmlFiles(proxiesFolder, fileDescriptorType: FileRepresentationType.proxyEndpointDescriptor) : [],
      targetsFiles: targetsFolder != null ? readXmlFiles(targetsFolder, fileDescriptorType: FileRepresentationType.targetEndpointDescriptor) : [],
      policiesFiles: policiesFolder != null ? readXmlFiles(policiesFolder, fileDescriptorType: FileRepresentationType.policy) : [],
      jsResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "jsc", extension: ".js", reader: (File f) => readJsFile(f, fileDescriptorType: FileRepresentationType.jsResource)) : [],
      javaResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "java", extension: ".jar", reader: (File f) => readJavaFile(f, fileDescriptorType: FileRepresentationType.javaResource)) : [],
      pythonResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "py", extension: ".py", reader: (File f) => readPythonFile(f, fileDescriptorType: FileRepresentationType.pythonResource)) : [],
      oasResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "oas", extension: ".yaml", reader: (File f) => readYamlFile(f, fileDescriptorType: FileRepresentationType.yamlResource)) : [],
    );
  }

  static FileRepresentation readXmlFile(File file, {FileRepresentationType? fileDescriptorType}) {
    return FileRepresentation(name: file.path, contentType: FileContentType.xml, content: file.readAsStringSync(), fileRepresentationType: fileDescriptorType);
  }

  static FileRepresentation readJsFile(File file, {FileRepresentationType? fileDescriptorType}) {
    return FileRepresentation(name: file.path, contentType: FileContentType.js, content: file.readAsStringSync(), fileRepresentationType: fileDescriptorType);
  }

  static FileRepresentation readPythonFile(File file, {FileRepresentationType? fileDescriptorType}) {
    return FileRepresentation(name: file.path, contentType: FileContentType.py, content: file.readAsStringSync(), fileRepresentationType: fileDescriptorType);
  }

  static FileRepresentation readYamlFile(File file, {FileRepresentationType? fileDescriptorType}) {
    return FileRepresentation(name: file.path, contentType: FileContentType.yaml, content: file.readAsStringSync(), fileRepresentationType: fileDescriptorType);
  }

  static FileRepresentation readJavaFile(File file, {FileRepresentationType? fileDescriptorType}) {
    return FileRepresentation(name: file.path, contentType: FileContentType.jar, fileRepresentationType: fileDescriptorType);
  }

  static List<FileRepresentation> readXmlFiles(Directory directory, {FileRepresentationType? fileDescriptorType}) {
    return directory.listSync().toList()
        .whereType<File>().where((file) => ".xml" == p.extension(file.path))
        .map((file) => readXmlFile(file, fileDescriptorType: fileDescriptorType))
        .toList();
  }

  static List<FileRepresentation> readResourceFiles({required Directory resourcesFolder,
    required String subFolder,
    required String extension,
    required FileRepresentation Function(File) reader}) {

    Directory? folder = resourcesFolder.listSync().toList()
        .whereType<Directory>()
        .where((folder) => subFolder == p.basenameWithoutExtension(folder.path))
        .firstOrNull;
    if (folder == null) {
      return [];
    }
    return folder
        .listSync().toList()
        .whereType<File>().where((file) => extension == p.extension(file.path))
        .map(reader)
        .toList();
  }
}