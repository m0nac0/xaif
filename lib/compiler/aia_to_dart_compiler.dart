// Copyright (C) 2021  m0nac0 (github.com/m0nac0)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
import 'dart:convert';

import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:xml/xml.dart';

import '../main.dart';
import 'aia_compiler_constants.dart';
import 'parse_component.dart';
import 'parse_expression.dart';
import 'parse_statement.dart';
import 'parsing_state.dart';
import 'pubspec_builder.dart';
import 'util_parser.dart';
import 'util_xml.dart';

//TODO-List of issues / future work:
// - fix GridLayout;
// - dialog behaviour not exactly same as original?
// - ideas: Clock (timer)/location
// - Font Typeface; Focus; Button.FeedbackVisible/Shape(partial)/TextAlignment(incorrect; different default values; needs alignment: Alignment.centerLeft for Buttons)
// - Further Features: BackgroundColor, Scrolling/Table-Arrangement

//Another idea: first parse the XML/(in the future JSON?) into a custom tree of dart objects with
//relevant details, then walk that tree to generate dart code

const methodNamePrefix = "methods";

/// Transpiles the content of a blockly-file and SCM-file from an AIA project file
/// into corresponding code for the main.dart and pubspec.yaml files of a Flutter app
class AIAToDartCompiler {
  ParsingState state = ParsingState();

  CompilationResult toCode(String blockly, String scheme) {
    final jsonString = scheme.substring(9, scheme.length - 3);
    final decoded = jsonDecode(jsonString);

    state.appName = decoded["Properties"]["AppName"] ?? "";
    state.screenName = decoded["Properties"]["Title"] ?? "";
    state.aboutMessage = decoded["Properties"]["AboutScreen"] ?? "";

    final xml = blockly.isEmpty ? XmlDocument() : XmlDocument.parse(blockly);
    if (xml.getElement("xml") != null) {
      for (var block in xml.getElement("xml")!.findElements("block")) {
        // Walk through all events and store a no-op
        // In the next pass we can then know for which events the user has added handlers.
        // Events without handlers are not called and no handling dart method is created
        // But to know whether a later xml block has a listener for an event, we have to do this first pass
        tryParseEvent(block, withStatements: false);
      }

      for (var block in xml.getElement("xml")!.findElements("block")) {
        tryParseEvent(block);
        tryParseGlobalVariableDeclaration(block);
        tryParseGlobalMethodDeclaration(block);
      }
    }

    var componentParser = ComponentParser(state);
    List<Expression> children =
        (decoded["Properties"]["\$Components"] as Iterable)
            .map((component) =>
                componentParser.parseComponent(component, false, true))
            .whereNotNull()
            .toList();

    var myAppStateClass = Class((b) {
      b
        ..name = "MyAppState"
        ..extend = r("State<MyApp>", materialPackage)
        ..fields.addAll(state.fields.entries
            .map((e) => Field((b) => b
              ..name = e.key
              ..assignment = e.value?.code ?? literalNull.code))
            .toList()
            .where((element) =>
                state.gettersSetters.none((p0) => p0.name == element.name)))
        ..methods.addAll(state.gettersSetters)
        ..methods.add(Method((b) => b
          ..name = 'build'
          ..requiredParameters.add(Parameter((b) => b
            ..name = "context"
            ..type = r("BuildContext", materialPackage)))
          ..body =
              InvokeExpression.newOf(r("MaterialApp", materialPackage), [], {
            "debugShowCheckedModeBanner": lfalse, // hide the debug banner
            "home": InvokeExpression.newOf(r("Scaffold", materialPackage), [], {
              "appBar": r("AppBar").newInstance([], {
                //Otherwise Appbar ignores primaryColor
                "backwardsCompatibility": literalTrue,
                "title":
                    r("Text").newInstance([literalString(state.screenName)]),
                // The overflow menu with the "About" item / dialog
                "actions": literalList([
                  r("PopupMenuButton").newInstance([], {
                    "itemBuilder": Method((m) => m
                      ..requiredParameters
                          .add(Parameter((p) => p..name = "context"))
                      ..body = literalList([
                        r("PopupMenuItem").newInstance([], {
                          "child":
                              r("Text").newInstance([literalString("About")]),
                          "onTap": Method((m) => m
                            ..body = r("Future").newInstanceNamed("delayed", [
                              r("Duration").newInstance([]),
                              wrapCodeWithEmptyLambda(r("showAboutDialog")([], {
                                "context": r("context"),
                                "applicationName": literalString(state.appName),
                                "applicationLegalese": literalString(
                                    "This app (${state.appName}) was built with $toolName. $toolName allows developers to transform applications "
                                    "developed with MIT App Inventor into cross platform apps.\nAbout ${state.appName}:\n${state.aboutMessage}")
                              }))
                            ]).statement).closure
                        })
                      ]).returned.statement).closure
                  })
                ])
              }),
              "body": r("Builder").newInstance(
                [],
                {
                  "builder": Method((b) => b
                    ..requiredParameters.add(
                      Parameter((p) => p..name = "context"),
                    )
                    ..body = Block.of([
                      r("latestContext").assign(r("context")).statement,
                      InvokeExpression.newOf(r("Column", materialPackage), [], {
                        "crossAxisAlignment": r("CrossAxisAlignment.start"),
                        "children": literalList(children)
                      }).returned.statement
                    ])).closure
                },
              )
            }),
            "theme": r("ThemeData").newInstance([], {
              "primaryColor": r("Color").newInstance([
                r("0x" +
                    (decoded["Properties"]["PrimaryColor"]?.substring(2) ??
                        "FF2196F3"))
              ]),
            })
          }).returned.statement
          ..returns = r("Widget", materialPackage)))
        ..methods.addAll(state.methods.entries
            .expand((element) => element.value.entries.map((e) => e.value)));

      b.methods.add(Method(
        (m) => m
          ..name = "numToCrossAxisAlignment"
          ..requiredParameters.add(Parameter((p) => p..name = "value"))
          ..body = r("value")
              .equalTo(literalNum(1))
              .conditional(
                  r("CrossAxisAlignment.start"),
                  r("value").equalTo(literalNum(2)).conditional(
                      r("CrossAxisAlignment.end"),
                      r("CrossAxisAlignment.center")))
              .returned
              .statement,
      ));
      b.methods.add(Method(
        (m) => m
          ..name = "numToMainAxisAlignment"
          ..requiredParameters.add(Parameter((p) => p..name = "value"))
          ..body = r("value")
              .equalTo(literalNum(1))
              .conditional(
                  r("MainAxisAlignment.start"),
                  r("value").equalTo(literalNum(2)).conditional(
                      r("MainAxisAlignment.end"),
                      r("MainAxisAlignment.center")))
              .returned
              .statement,
      ));
      if (state.usesSharedPreferences) {
        b.fields.add(Field((f) => f
          ..name = "sharedPrefs"
          ..type = r("SharedPreferences")
          ..modifier));
        b.methods.add(Method((m) => m
          ..name = "initState"
          ..body = Block.of([
            r("initSharedPrefs")([]).statement,
            r("super.initState").statement
          ])));
        b.methods.add(Method((m) => m
          ..name = "initSharedPrefs"
          ..modifier = MethodModifier.async
          ..body = Block.of([
            if (state.usesSharedPreferences)
              r("sharedPrefs")
                  .assign(r("SharedPreferences.getInstance")([]).awaited)
                  .statement,
          ])));
      }
      if (state.usesEnsureNum) {
        b.methods.add(Method((m) => m
          ..name = "ensureNum"
          ..requiredParameters.add(Parameter((p) => p..name = "value"))
          ..lambda = true
          ..body = r("value")
              .isA(r("num"))
              .conditional(r("value"),
                  r("num.parse")([r("value").property("toString")([])]))
              .code));
      }
    });

    var myAppClass = Class((b) => b
      ..name = "MyApp"
      ..extend = r("StatefulWidget", materialPackage)
      ..methods.add(Method((b) => b
        ..name = 'createState'
        ..body = InvokeExpression.newOf(r("MyAppState"), []).code
        ..returns = r("MyAppState")
        ..lambda = true)));

    final library = Library((b) => b.body.addAll([
          Method.returnsVoid(
            (b) => b
              ..name = 'main'
              ..body = r("runApp")([InvokeExpression.newOf(r("MyApp"), [])])
                  .statement,
          ),
          myAppClass,
          myAppStateClass
        ]));

    var allocator = Allocator();
    final emitter = DartEmitter(allocator: allocator);
    const dartVersion = "// @dart=2.9\r\n"; // no sound null safety
    const linterHints =
        "// ignore_for_file: non_constant_identifier_names\r\n// ignore_for_file: prefer_const_constructors\r\n";
    //possibly instead call toString() in text_join for every argument
    const safePlusExtension = r'''extension SafePlus on String{
      /// A safer String addition, that automatically calls toString() for
      /// every added object (like AI does). Allows e.g. "a" + ["b"]
      String operator % (dynamic a){
        return this + a.toString();
      }
    }''';
    var sourceString =
        dartVersion + linterHints + library.accept(emitter).toString();
    if (state.usesSafeStringAddition) {
      sourceString += safePlusExtension;
    }
    var dartCode = DartFormatter().format(sourceString);
    var packageRegex = RegExp(r"package:(\w+)\/[\w\/]+\.dart");
    var imports = allocator.imports
        .map((import) => packageRegex.firstMatch(import.url)?.group(1))
        .whereNotNull()
        .toList();
    return CompilationResult(dartCode, PubspecBuilder.getPubspec(imports));
  }

  /// Try to parse a block as a global variable declaration. Do nothing if it
  /// is a different kind of block.
  void tryParseGlobalVariableDeclaration(XmlElement block) {
    if (block.getAttribute("type") != "global_declaration") {
      return;
    }
    Expression value = ExpressionParser(state).parseExpressionXMLChild(
        block, "VALUE", StatementParser(state).parseStatement);
    String name = findXMLChildByName(block, "NAME", "field").innerText;
    state.fields.putIfAbsent(getVarName(name), () => value);
  }

  /// Try to parse a block as a global method declaration. Do nothing if it
  /// is a different kind of block.
  void tryParseGlobalMethodDeclaration(XmlElement block) {
    if (block.getAttribute("type") == "procedures_defnoreturn") {
      String name = findXMLChildByName(block, "NAME", "field").innerText;
      var parameters = <Parameter>[];
      block.getElement("mutation")?.findElements("arg").forEach((element) {
        parameters
            .add(Parameter((p) => p..name = element.getAttribute("name")!));
      });
      XmlElement? walkedBlock = block;
      List<Code> statements = [
        StatementParser(state).parseStatement(
            findBlockOfXMLChildByName(walkedBlock, "STACK", "statement"))
      ];

      walkedBlock = findBlockOfXMLChildByName(walkedBlock, "STACK", "statement")
          .getElement("next")
          ?.getElement("block");

      while (walkedBlock != null) {
        statements.add(StatementParser(state).parseStatement(walkedBlock));
        walkedBlock = walkedBlock.getElement("next")?.getElement("block");
      }

      state.addMethod(
          methodNamePrefix,
          name,
          Method((m) => m
            ..name = getMethodName(name)
            ..requiredParameters.addAll(parameters)
            ..body = Block.of(statements)));
    } else if (block.getAttribute("type") == "procedures_defreturn") {
      String name = findXMLChildByName(block, "NAME", "field").innerText;
      var parameters = <Parameter>[];
      block.getElement("mutation")?.findElements("arg").forEach((element) {
        parameters
            .add(Parameter((p) => p..name = element.getAttribute("name")!));
      });
      Expression value = ExpressionParser(state).parseExpressionXMLChild(
          block, "RETURN", StatementParser(state).parseStatement);
      state.addMethod(
          methodNamePrefix,
          name,
          Method((m) => m
            ..name = getMethodName(name)
            ..requiredParameters.addAll(parameters)
            ..body = value.returned.statement));
    }
  }

  /// Try to parse a block as an event handler (of a component event).
  /// Do nothing if it is a different kind of block.
  void tryParseEvent(XmlElement block, {bool withStatements = true}) {
    if (block.getAttribute("type") != "component_event") {
      return;
    }
    var mutation = block.getElement("mutation")!;
    var instanceName = getInstanceName(mutation);
    var eventName = mutation.getAttribute("event_name")!;
    var componentType = mutation.getAttribute("component_type");

    var method = Method.returnsVoid((b) => b
      ..name = instanceName + "_on" + eventName
      ..body = withStatements
          ? Block.of(parseStatements(
              block.getElement("statement")!.findElements("block")))
          : null
      // add parameters if required
      ..requiredParameters.addAll(events[componentType!]
              ?.firstWhereOrNull((event) => event.name == eventName)
              ?.arguments
              .map((key, value) => MapEntry(
                  key,
                  Parameter((p) => p
                    ..name = key
                    ..type = value)))
              .values ??
          []));

    state.addMethod(instanceName, eventName, method);
  }

  /// Parse a list of statements
  List<Code> parseStatements(Iterable<XmlElement> list) {
    List<Code> statements = [];
    XmlElement? statement = list.first;
    var statementParser = StatementParser(state);
    while (statement != null) {
      statements.add(statementParser.parseStatement(statement));
      statement = statement.getElement("next")?.getElement("block");
    }
    return statements;
  }
}

/// The result of compiling an AIA file to a flutter project
class CompilationResult {
  /// The dart code for lib/main.dart
  String dartCode;

  /// The content of pubspec.yaml
  String pubspec;

  CompilationResult(this.dartCode, this.pubspec);
}
