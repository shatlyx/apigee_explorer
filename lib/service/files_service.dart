import 'dart:io';
import 'package:apigee_explorer/exceptions/parsing_exceptions.dart';
import 'package:path/path.dart' as p;

import 'package:apigee_explorer/model/internal.dart';

class FilesService {

  static ApiProxyFiles parseProxyFolder(String folder) {
    final dir = Directory(folder);
    final File? proxyDescriptor = dir.listSync().toList().whereType<File>().where((file) => ".xml" == p.extension(file.path)).firstOrNull;
    final Directory? policiesFolder = dir.listSync().toList().whereType<Directory>().where((file) => "policies" == p.basename(file.path)).firstOrNull;
    final Directory? proxiesFolder = dir.listSync().toList().whereType<Directory>().where((file) => "proxies" == p.basename(file.path)).firstOrNull;
    final Directory? targetsFolder = dir.listSync().toList().whereType<Directory>().where((file) => "targets" == p.basename(file.path)).firstOrNull;
    final Directory? resourcesFolder = dir.listSync().toList().whereType<Directory>().where((file) => "resources" == p.basename(file.path)).firstOrNull;
    if (proxyDescriptor == null) {
      throw ProxyParsingException(cause: 'Proxy Descriptor File Not Found');
    }
    return ApiProxyFiles(
      apiProxyDescriptor: readXmlFile(proxyDescriptor),
      proxiesFiles: proxiesFolder != null ? readXmlFiles(proxiesFolder) : [],
      targetsFiles: targetsFolder != null ? readXmlFiles(targetsFolder) : [],
      policiesFiles: policiesFolder != null ? readXmlFiles(policiesFolder) : [],
      jsResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "jsc", extension: ".js", reader: (File f) => readJsFile(f)) : [],
      javaResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "java", extension: ".jar", reader: (File f) => readJavaFile(f)) : [],
      pythonResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "py", extension: ".py", reader: (File f) => readPythonFile(f)) : [],
      oasResourcesFiles: resourcesFolder != null ? readResourceFiles(resourcesFolder: resourcesFolder, subFolder: "oas", extension: ".yaml", reader: (File f) => readYamlFile(f)) : [],
    );
  }

  static FileRepresentation readXmlFile(File file) {
    return FileRepresentation(name: file.path, contentType: FileContentType.xml, content: file.readAsStringSync());
  }

  static FileRepresentation readJsFile(File file) {
    return FileRepresentation(name: file.path, contentType: FileContentType.js, content: file.readAsStringSync(),);
  }

  static FileRepresentation readPythonFile(File file) {
    return FileRepresentation(name: file.path, contentType: FileContentType.py, content: file.readAsStringSync(),);
  }

  static FileRepresentation readYamlFile(File file) {
    return FileRepresentation(name: file.path, contentType: FileContentType.yaml, content: file.readAsStringSync(),);
  }

  static FileRepresentation readJavaFile(File file) {
    return FileRepresentation(name: file.path, contentType: FileContentType.jar,);
  }

  static List<FileRepresentation> readXmlFiles(Directory directory) {
    return directory.listSync().toList()
        .whereType<File>().where((file) => ".xml" == p.extension(file.path))
        .map((file) => readXmlFile(file))
        .toList();
  }

  static List<FileRepresentation> readResourceFiles({required Directory resourcesFolder,
    required String subFolder,
    required String extension,
    required FileRepresentation Function(File) reader}) {

    Directory? folder = resourcesFolder.listSync().toList()
        .whereType<Directory>()
        .where((folder) => subFolder == p.basename(folder.path))
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