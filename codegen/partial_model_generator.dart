import 'dart:async';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:build/build.dart';
import 'package:models/models.dart';
import 'package:source_gen/source_gen.dart';
import 'package:pluralize/pluralize.dart';

/// Factory function for creating the generator
Builder partialModelGeneratorFactory(BuilderOptions options) =>
    SharedPartBuilder([PartialModelGenerator()], 'partial_models');

/// Generator that creates partial model mixins for annotated model classes
class PartialModelGenerator
    extends GeneratorForAnnotation<GeneratePartialModel> {
  const PartialModelGenerator();

  @override
  FutureOr<String?> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        'GeneratePartialModel can only be applied to classes.',
        element: element,
      );
    }

    return _generatePartialMixin(element, buildStep);
  }

  Future<String?> _generatePartialMixin(
      ClassElement classElement, BuildStep buildStep) async {
    final className = classElement.name;
    final partialMixinName = 'Partial${className}Mixin';

    // Determine the model type and corresponding partial model base class
    final modelInfo = _getModelInfo(classElement);
    if (modelInfo == null) {
      throw InvalidGenerationSourceError(
        'Class $className must extend RegularModel, EphemeralModel, ReplaceableModel, or ParameterizableReplaceableModel.',
        element: classElement,
      );
    }

    final partialBaseClass = modelInfo.partialBaseClass;

    // Parse the library to get getter implementations
    final getterImplementations =
        await _parseGetterImplementations(classElement, buildStep);

    // Generate properties (getters and setters) from the original class
    final methods = _generateMethods(classElement, getterImplementations);

    return '''
// ignore_for_file: annotate_overrides

/// Generated partial model mixin for $className
mixin $partialMixinName on $partialBaseClass<$className> {
${methods.join('\n')}
}''';
  }

  Future<Map<String, String>> _parseGetterImplementations(
      ClassElement classElement, BuildStep buildStep) async {
    final implementations = <String, String>{};

    try {
      // Get the library source (main file that includes all parts)
      final library = classElement.library;
      final librarySource = library.source;

      // Convert library URI to AssetId
      final uri = librarySource.uri;
      AssetId assetId;

      if (uri.scheme == 'package') {
        final parts = uri.pathSegments;
        final packageName = parts[0];
        final path = parts.skip(1).join('/');
        assetId = AssetId(packageName, 'lib/$path');
      } else if (uri.scheme == 'file') {
        final path = uri.path;
        if (path.contains('/lib/')) {
          final libIndex = path.indexOf('/lib/');
          final relativePath = path.substring(libIndex + 1);
          assetId = AssetId('models', relativePath);
        } else {
          return implementations;
        }
      } else {
        return implementations;
      }

      // Read and parse the main library file
      final contents = await buildStep.readAsString(assetId);
      final parseResult = parseString(content: contents);
      final unit = parseResult.unit;

      // Find all part files and parse them too
      final allUnits = <CompilationUnit>[unit];

      for (final directive in unit.directives) {
        if (directive is PartDirective) {
          final partUri = directive.uri.stringValue;
          if (partUri != null) {
            try {
              final partAssetId = AssetId('models', 'lib/$partUri');
              final partContents = await buildStep.readAsString(partAssetId);
              final partParseResult = parseString(content: partContents);
              allUnits.add(partParseResult.unit);
            } catch (e) {
              // Skip if part file can't be read
            }
          }
        }
      }

      // Find the target class and extract getter implementations
      for (final unit in allUnits) {
        for (final declaration in unit.declarations) {
          if (declaration is ClassDeclaration &&
              declaration.name.lexeme == classElement.name) {
            for (final member in declaration.members) {
              if (member is MethodDeclaration && member.isGetter) {
                final propertyName = member.name.lexeme;
                final bodySource = member.body.toSource();
                implementations[propertyName] = bodySource;
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      // If parsing fails, return empty map
    }

    return implementations;
  }

  List<String> _generateMethods(
      ClassElement classElement, Map<String, String> getterImplementations) {
    final methods = <String>[];
    final generatedMethodNames = <String>{};

    // Process all accessors (getters) in the class
    for (final accessor in classElement.accessors) {
      if (accessor.isGetter &&
          !accessor.isSynthetic &&
          !accessor.isStatic &&
          !_isInheritedFromBaseModel(accessor)) {
        final propertyName = accessor.name;
        final implementation = getterImplementations[propertyName];

        if (implementation != null && implementation.contains('event.')) {
          final property = _generatePropertyFromImplementation(
              accessor, implementation, generatedMethodNames);
          if (property != null) {
            methods.addAll(property);
          }
        }
      }
    }

    if (methods.isEmpty) {
      methods.add('  // No event-based getters found in ${classElement.name}');
    }

    return methods;
  }

  bool _isInheritedFromBaseModel(PropertyAccessorElement accessor) {
    final enclosingClass = accessor.enclosingElement3 as ClassElement;

    // If the getter is declared in the current class, it's not inherited
    if (accessor.declaration.enclosingElement3 == enclosingClass) {
      return false;
    }

    // Check if the getter is declared in a base model class
    final declaringClass = accessor.declaration.enclosingElement3;
    if (declaringClass is ClassElement) {
      final declaringClassName = declaringClass.name;
      if ({
        'Model',
        'RegularModel',
        'EphemeralModel',
        'ReplaceableModel',
        'ParameterizableReplaceableModel',
        'RegularPartialModel',
        'EphemeralPartialModel',
        'ReplaceablePartialModel',
        'ParameterizableReplaceablePartialEvent'
      }.contains(declaringClassName)) {
        return true;
      }
    }

    return false;
  }

  List<String>? _generatePropertyFromImplementation(
      PropertyAccessorElement accessor,
      String implementation,
      Set<String> generatedMethodNames) {
    final propertyName = accessor.name;
    final returnType = accessor.returnType.getDisplayString();

    final methods = <String>[];

    if (implementation.contains('event.getFirstTagValue')) {
      // Extract tag name from event.getFirstTagValue('tagName')
      final tagMatch = RegExp(r"event\.getFirstTagValue\('([^']+)'\)")
          .firstMatch(implementation);
      if (tagMatch != null) {
        final tagName = tagMatch.group(1)!;
        methods.add(_generateTagValueGetter(propertyName, returnType, tagName));
        methods.add(_generateTagValueSetter(propertyName, returnType, tagName));
      }
    } else if (implementation.contains('event.getTagSetValues')) {
      // Extract tag name from event.getTagSetValues('tagName')
      final tagMatch = RegExp(r"event\.getTagSetValues\('([^']+)'\)")
          .firstMatch(implementation);
      if (tagMatch != null) {
        final tagName = tagMatch.group(1)!;
        methods.add(_generateSetGetter(propertyName, returnType, tagName));
        methods.add(_generateSetSetter(propertyName, tagName));
        methods.add(_generateAddMethod(propertyName, tagName));
        methods.add(_generateRemoveMethod(propertyName, tagName));
      }
    } else if (implementation.contains('event.content') &&
        !implementation.contains('event.getFirstTagValue') &&
        !implementation.contains('event.getTagSetValues')) {
      // Only treat as content property if it ONLY uses event.content (no tag fallbacks)
      methods.add(_generateContentGetter(propertyName, returnType));
      methods.add(_generateContentSetter(propertyName, returnType));
    }

    return methods.isEmpty ? null : methods;
  }

  String _generateContentGetter(String propertyName, String returnType) {
    final nullableType = _makeNullable(returnType);
    return '  $nullableType get $propertyName => event.content.isEmpty ? null : event.content;';
  }

  String _generateContentSetter(String propertyName, String returnType) {
    final nullableType = _makeNullable(returnType);
    return "  set $propertyName($nullableType value) => event.content = value ?? '';";
  }

  String _generateTagValueGetter(
      String propertyName, String returnType, String tagName) {
    if (returnType.contains('DateTime')) {
      return "  DateTime? get $propertyName => event.getFirstTagValue('$tagName')?.toInt()?.toDate();";
    } else if (returnType.contains('int')) {
      return "  int? get $propertyName => int.tryParse(event.getFirstTagValue('$tagName') ?? '');";
    } else {
      return "  String? get $propertyName => event.getFirstTagValue('$tagName');";
    }
  }

  String _generateTagValueSetter(
      String propertyName, String returnType, String tagName) {
    if (returnType.contains('DateTime')) {
      return "  set $propertyName(DateTime? value) => event.setTagValue('$tagName', value?.toSeconds().toString());";
    } else if (returnType.contains('int')) {
      return "  set $propertyName(int? value) => event.setTagValue('$tagName', value?.toString());";
    } else {
      return "  set $propertyName(String? value) => event.setTagValue('$tagName', value);";
    }
  }

  String _generateSetGetter(
      String propertyName, String returnType, String tagName) {
    return '  Set<String> get $propertyName => event.getTagSetValues(\'$tagName\');';
  }

  String _generateSetSetter(String propertyName, String tagName) {
    return '  set $propertyName(Set<String> value) => event.setTagValues(\'$tagName\', value);';
  }

  String _generateAddMethod(String propertyName, String tagName) {
    final pluralize = Pluralize();
    final singularName = pluralize.singular(propertyName);
    final capitalizedName = _capitalize(singularName);
    return '  void add$capitalizedName(String? value) => event.addTagValue(\'$tagName\', value);';
  }

  String _generateRemoveMethod(String propertyName, String tagName) {
    final pluralize = Pluralize();
    final singularName = pluralize.singular(propertyName);
    final capitalizedName = _capitalize(singularName);
    return '  void remove$capitalizedName(String? value) => event.removeTagWithValue(\'$tagName\', value);';
  }

  String _makeNullable(String type) {
    if (type.endsWith('?') || type == 'void' || type.startsWith('Set<')) {
      return type;
    }
    return '$type?';
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  _ModelInfo? _getModelInfo(ClassElement classElement) {
    InterfaceType? supertype = classElement.supertype;

    while (supertype != null) {
      final supertypeElement = supertype.element;
      if (supertypeElement is ClassElement) {
        final supertypeName = supertypeElement.name;

        switch (supertypeName) {
          case 'RegularModel':
            return _ModelInfo('RegularPartialModel');
          case 'EphemeralModel':
            return _ModelInfo('EphemeralPartialModel');
          case 'ReplaceableModel':
            return _ModelInfo('ReplaceablePartialModel');
          case 'ParameterizableReplaceableModel':
            return _ModelInfo('ParameterizableReplaceablePartialEvent');
        }

        // Move up the inheritance chain
        supertype = supertypeElement.supertype;
      } else {
        break;
      }
    }

    return null;
  }
}

class _ModelInfo {
  final String partialBaseClass;

  _ModelInfo(this.partialBaseClass);
}
