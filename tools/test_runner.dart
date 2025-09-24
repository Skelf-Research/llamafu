#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';

/// Comprehensive test runner for the Llamafu project
class LlamafuTestRunner {
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _bold = '\x1B[1m';

  final Map<String, bool> _testResults = {};
  final List<String> _failedTests = [];

  /// Main entry point for running all tests
  Future<void> runAllTests({
    bool comprehensive = false,
    bool performance = false,
    bool native = false,
    bool coverage = false,
    bool verbose = false,
  }) async {
    _printHeader();

    try {
      // Setup test environment
      await _setupTestEnvironment();

      // Run different test suites based on options
      if (comprehensive || !performance && !native) {
        await _runDartTests(coverage: coverage, verbose: verbose);
      }

      if (performance || comprehensive) {
        await _runPerformanceTests(verbose: verbose);
      }

      if (native || comprehensive) {
        await _runNativeTests(verbose: verbose);
      }

      if (comprehensive) {
        await _runIntegrationTests(verbose: verbose);
        await _runSecurityTests(verbose: verbose);
      }

      // Generate final report
      _generateFinalReport();

    } catch (e) {
      _printError('Test execution failed: $e');
      exit(1);
    } finally {
      await _cleanupTestEnvironment();
    }
  }

  /// Sets up the test environment
  Future<void> _setupTestEnvironment() async {
    _printSection('Setting up test environment');

    // Ensure Flutter dependencies are installed
    await _runCommand('flutter', ['pub', 'get'], 'Installing Flutter dependencies');

    // Initialize git submodules if needed
    final result = await _runCommand('git', ['submodule', 'status'], 'Checking git submodules', allowFailure: true);
    if (result.exitCode != 0 || result.stdout.toString().contains('-')) {
      await _runCommand('git', ['submodule', 'update', '--init', '--recursive'], 'Initializing git submodules');
    }

    // Create test output directory
    final testOutputDir = Directory('test_output');
    if (!testOutputDir.existsSync()) {
      testOutputDir.createSync();
    }

    _printSuccess('Test environment setup complete');
  }

  /// Runs Dart/Flutter unit tests
  Future<void> _runDartTests({bool coverage = false, bool verbose = false}) async {
    _printSection('Running Dart/Flutter Tests');

    final testFiles = [
      'test/llamafu_comprehensive_test.dart',
      'test/integration/llamafu_integration_test.dart',
    ];

    for (final testFile in testFiles) {
      if (File(testFile).existsSync()) {
        final args = ['test', testFile];
        if (coverage) args.add('--coverage');
        if (verbose) args.add('--reporter=expanded');

        final testName = testFile.split('/').last.replaceAll('.dart', '');
        final result = await _runCommand('flutter', args, 'Running $testName', allowFailure: true);
        _testResults[testName] = result.exitCode == 0;

        if (result.exitCode != 0) {
          _failedTests.add(testName);
        }
      }
    }

    // Generate coverage report if requested
    if (coverage && _testResults.values.any((passed) => passed)) {
      await _generateCoverageReport();
    }
  }

  /// Runs performance tests
  Future<void> _runPerformanceTests({bool verbose = false}) async {
    _printSection('Running Performance Tests');

    final perfTestFile = 'test/performance/llamafu_performance_test.dart';
    if (File(perfTestFile).existsSync()) {
      final args = ['test', perfTestFile];
      if (verbose) args.add('--reporter=expanded');

      final result = await _runCommand('flutter', args, 'Running performance tests', allowFailure: true);
      _testResults['performance_tests'] = result.exitCode == 0;

      if (result.exitCode != 0) {
        _failedTests.add('performance_tests');
      }
    }
  }

  /// Runs native C++ tests
  Future<void> _runNativeTests({bool verbose = false}) async {
    _printSection('Running Native C++ Tests');

    // Check if we can build native tests
    final cmakeExists = await _checkCommand('cmake');
    if (!cmakeExists) {
      _printWarning('CMake not found, skipping native tests');
      return;
    }

    try {
      // Create build directory
      final buildDir = Directory('build_test');
      if (buildDir.existsSync()) {
        buildDir.deleteSync(recursive: true);
      }
      buildDir.createSync();

      // Configure CMake for tests
      await _runCommand('cmake', [
        '-B', 'build_test',
        '-S', '.',
        '-DBUILD_TESTING=ON',
        '-DCMAKE_BUILD_TYPE=Debug',
      ], 'Configuring CMake for tests');

      // Build tests
      await _runCommand('cmake', [
        '--build', 'build_test',
        '--config', 'Debug',
        '--parallel',
      ], 'Building native tests');

      // Run tests with CTest
      final result = await _runCommand('ctest', [
        '--test-dir', 'build_test',
        '--output-on-failure',
        if (verbose) '--verbose',
      ], 'Running native tests', allowFailure: true);

      _testResults['native_tests'] = result.exitCode == 0;

      if (result.exitCode != 0) {
        _failedTests.add('native_tests');
      }

    } catch (e) {
      _printWarning('Native tests failed to run: $e');
      _testResults['native_tests'] = false;
      _failedTests.add('native_tests');
    }
  }

  /// Runs integration tests
  Future<void> _runIntegrationTests({bool verbose = false}) async {
    _printSection('Running Integration Tests');

    final integrationDir = Directory('test/integration');
    if (integrationDir.existsSync()) {
      final args = ['test', 'test/integration/'];
      if (verbose) args.add('--reporter=expanded');

      final result = await _runCommand('flutter', args, 'Running integration tests', allowFailure: true);
      _testResults['integration_tests'] = result.exitCode == 0;

      if (result.exitCode != 0) {
        _failedTests.add('integration_tests');
      }
    }
  }

  /// Runs security tests
  Future<void> _runSecurityTests({bool verbose = false}) async {
    _printSection('Running Security Tests');

    // Run security-focused unit tests
    final args = ['test', 'test/llamafu_comprehensive_test.dart', '--name', 'Security'];
    if (verbose) args.add('--reporter=expanded');

    final result = await _runCommand('flutter', args, 'Running security tests', allowFailure: true);
    _testResults['security_tests'] = result.exitCode == 0;

    if (result.exitCode != 0) {
      _failedTests.add('security_tests');
    }

    // Check for hardcoded secrets (basic check)
    await _runSecretsScan();
  }

  /// Generates coverage report
  Future<void> _generateCoverageReport() async {
    _printInfo('Generating coverage report');

    try {
      // Activate coverage tool
      await _runCommand('dart', ['pub', 'global', 'activate', 'coverage'], 'Activating coverage tool');

      // Format coverage
      await _runCommand('dart', [
        'pub', 'global', 'run', 'coverage:format_coverage',
        '--lcov',
        '--in=coverage',
        '--out=coverage/lcov.info',
        '--packages=.dart_tool/package_config.json',
        '--report-on=lib',
      ], 'Formatting coverage report');

      _printSuccess('Coverage report generated at coverage/lcov.info');
    } catch (e) {
      _printWarning('Failed to generate coverage report: $e');
    }
  }

  /// Performs basic secrets scanning
  Future<void> _runSecretsScan() async {
    _printInfo('Running basic secrets scan');

    final suspiciousPatterns = [
      RegExp(r'(?i)(password|passwd|pwd)\s*[=:]\s*["\'][^"\']+["\']'),
      RegExp(r'(?i)(api_key|apikey|secret_key)\s*[=:]\s*["\'][^"\']+["\']'),
      RegExp(r'(?i)(access_token|auth_token)\s*[=:]\s*["\'][^"\']+["\']'),
      RegExp(r'-----BEGIN [A-Z]+ PRIVATE KEY-----'),
      RegExp(r'(?i)(username|user)\s*[=:]\s*["\'][^"\']+["\']'),
    ];

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    var foundIssues = false;

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        for (final pattern in suspiciousPatterns) {
          if (pattern.hasMatch(lines[i])) {
            _printWarning('Potential secret found in ${file.path}:${i + 1}');
            foundIssues = true;
          }
        }
      }
    }

    if (!foundIssues) {
      _printSuccess('No obvious secrets found');
    }

    _testResults['secrets_scan'] = !foundIssues;
  }

  /// Cleans up test environment
  Future<void> _cleanupTestEnvironment() async {
    _printSection('Cleaning up test environment');

    // Remove build directory
    final buildDir = Directory('build_test');
    if (buildDir.existsSync()) {
      buildDir.deleteSync(recursive: true);
    }

    // Clean up temporary test files
    final tempFiles = Directory.current
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('temp_test_') || file.path.contains('.tmp'));

    for (final file in tempFiles) {
      try {
        file.deleteSync();
      } catch (e) {
        // Ignore cleanup errors
      }
    }

    _printSuccess('Cleanup complete');
  }

  /// Generates final test report
  void _generateFinalReport() {
    _printSection('Test Results Summary');

    final totalTests = _testResults.length;
    final passedTests = _testResults.values.where((passed) => passed).length;
    final failedTests = totalTests - passedTests;

    print('${_bold}Total Tests: $totalTests$_reset');
    print('${_green}Passed: $passedTests$_reset');
    print('${_red}Failed: $failedTests$_reset');

    if (_testResults.isNotEmpty) {
      print('\n${_bold}Detailed Results:$_reset');
      for (final entry in _testResults.entries) {
        final status = entry.value ? '${_green}PASS$_reset' : '${_red}FAIL$_reset';
        print('  ${entry.key}: $status');
      }
    }

    if (_failedTests.isNotEmpty) {
      print('\n${_bold}${_red}Failed Tests:$_reset');
      for (final test in _failedTests) {
        print('  • $test');
      }
    }

    final success = failedTests == 0;
    final overallStatus = success ? '${_green}SUCCESS$_reset' : '${_red}FAILURE$_reset';
    print('\n${_bold}Overall Result: $overallStatus$_reset');

    if (!success) {
      exit(1);
    }
  }

  /// Runs a command and returns the result
  Future<ProcessResult> _runCommand(
    String command,
    List<String> args,
    String description, {
    bool allowFailure = false,
  }) async {
    _printInfo('$description...');

    final result = await Process.run(command, args);

    if (result.exitCode == 0) {
      _printSuccess('$description completed');
    } else if (!allowFailure) {
      _printError('$description failed with exit code ${result.exitCode}');
      if (result.stderr.toString().isNotEmpty) {
        print('${_red}Error output:$_reset');
        print(result.stderr);
      }
      throw Exception('Command failed: $command ${args.join(' ')}');
    }

    return result;
  }

  /// Checks if a command is available
  Future<bool> _checkCommand(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  void _printHeader() {
    print('$_bold$_blue');
    print('╔══════════════════════════════════════════════════════════════════════╗');
    print('║                         LLAMAFU TEST RUNNER                         ║');
    print('╚══════════════════════════════════════════════════════════════════════╝');
    print('$_reset');
  }

  void _printSection(String title) {
    print('\n$_bold$_yellow=== $title ===$_reset');
  }

  void _printInfo(String message) {
    print('$_blue[INFO]$_reset $message');
  }

  void _printSuccess(String message) {
    print('$_green[SUCCESS]$_reset $message');
  }

  void _printWarning(String message) {
    print('$_yellow[WARNING]$_reset $message');
  }

  void _printError(String message) {
    print('$_red[ERROR]$_reset $message');
  }
}

/// Command line interface
void main(List<String> args) async {
  final runner = LlamafuTestRunner();

  final comprehensive = args.contains('--comprehensive') || args.contains('-c');
  final performance = args.contains('--performance') || args.contains('-p');
  final native = args.contains('--native') || args.contains('-n');
  final coverage = args.contains('--coverage');
  final verbose = args.contains('--verbose') || args.contains('-v');

  if (args.contains('--help') || args.contains('-h')) {
    print('''
Llamafu Test Runner

Usage: dart test_runner.dart [options]

Options:
  -c, --comprehensive   Run all test suites (unit, integration, performance, native, security)
  -p, --performance     Run performance tests only
  -n, --native          Run native C++ tests only
  --coverage            Generate coverage report (for Dart tests)
  -v, --verbose         Enable verbose output
  -h, --help            Show this help message

Examples:
  dart test_runner.dart                 # Run basic unit tests
  dart test_runner.dart -c              # Run comprehensive test suite
  dart test_runner.dart -p --coverage   # Run performance tests with coverage
  dart test_runner.dart -n -v           # Run native tests with verbose output
''');
    return;
  }

  await runner.runAllTests(
    comprehensive: comprehensive,
    performance: performance,
    native: native,
    coverage: coverage,
    verbose: verbose,
  );
}