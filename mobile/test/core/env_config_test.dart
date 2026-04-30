import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/config/env_config.dart';

void main() {
  test('publicFileBaseUrl strips /api from apiBaseUrl', () {
    // In tests we don't pass --dart-define, so these use defaults.
    expect(EnvConfig.apiBaseUrl, 'https://luharide.cloud/api/v1');
    expect(EnvConfig.publicFileBaseUrl, 'https://luharide.cloud');
  });
}

