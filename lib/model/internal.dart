class ApiProxyFiles {
  FileRepresentation apiProxyDescriptor;
  List<FileRepresentation> policiesFiles;
  List<FileRepresentation> proxiesFiles;
  List<FileRepresentation> jsResourcesFiles;
  List<FileRepresentation> oasResourcesFiles;
  List<FileRepresentation> javaResourcesFiles;
  List<FileRepresentation> pythonResourcesFiles;

  ApiProxyFiles(
      {
        required this.apiProxyDescriptor,
        required this.policiesFiles,
        required this.proxiesFiles,
        required this.jsResourcesFiles,
        required this.oasResourcesFiles,
        required this.javaResourcesFiles,
        required this.pythonResourcesFiles,
      });
}

class FileRepresentation {
  String name;
  FileType type;
  String? content;

  FileRepresentation({required this.name, required this.type, this.content});

}

class PolicyAnalysis {
  Set<String>? inputs;
  Set<String>? outputs;

  PolicyAnalysis({this.inputs, this.outputs});
}

enum FileType {
  xml, js, jar, py, yaml
}