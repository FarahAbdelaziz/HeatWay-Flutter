class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'HEATWAY_API_URL',
    defaultValue: 'http://16.171.225.54:8000',
  );
}
