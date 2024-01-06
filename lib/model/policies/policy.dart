abstract class Policy {
  Set<String> fetchInputs();
  Set<String> fetchOutputs();
  bool isValid();
  Set<String> getErrors();
  Set<String> getWarnings();
}