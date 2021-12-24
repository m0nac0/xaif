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
import 'package:code_builder/code_builder.dart';
import 'package:xml/xml.dart';

import 'parse_expression.dart';
import 'parsing_state.dart';
import 'util_parser.dart';
import 'util_xml.dart';

class StatementParser {
  StatementParser(this.state) : expressionParser = ExpressionParser(state);

  ParsingState state;
  ExpressionParser expressionParser;

  /// Parse a statement
  Code parseStatement(XmlElement block) {
    final type = block.getAttribute("type")!;
    if (type == "component_set_get") {
      var mutation = block.getElement("mutation")!;
      bool isSetter = mutation.getAttribute("set_or_get") == "set";
      var instanceName = getInstanceName(mutation);
      var propertyName = mutation.getAttribute("property_name")!;
      final textVar = instanceName + "_" + propertyName;
      state.ensureFieldExists(textVar);

      if (isSetter) {
        return r("setState")([
          Method((b) => b
            ..body = r(textVar)
                .assign(expressionParser.parseExpression(
                    block.getElement("value")!.getElement("block")!,
                    parseStatement))
                .statement).closure
        ]).statement;
      } else {
        return r(textVar).code;
      }
    } else if (type == "component_method") {
      return parseStatementComponentMethod(block);
    } else if (type == "controls_if") {
      bool hasElse = block.getElement("mutation")?.getAttribute("else") == "1";
      int numberElseIfs = int.parse(
          block.getElement("mutation")?.getAttribute("elseif") ?? "0");
      var result = "if(" +
          expressionParser
              .parseExpressionXMLChild(block, "IF0", parseStatement)
              .accept(DartEmitter())
              .toString() +
          "){" +
          parseStatement(findBlockOfXMLChildByName(block, "DO0", "statement"))
              .accept(DartEmitter())
              .toString() +
          "}";
      for (int i = 1; i <= numberElseIfs; i++) {
        result += "else if(" +
            expressionParser
                .parseExpressionXMLChild(block, "IF$i", parseStatement)
                .accept(DartEmitter())
                .toString() +
            "){" +
            parseStatement(
                    findBlockOfXMLChildByName(block, "DO$i", "statement"))
                .accept(DartEmitter())
                .toString() +
            "}";
      }
      if (hasElse) {
        result += "else{" +
            parseStatement(
                    findBlockOfXMLChildByName(block, "ELSE", "statement"))
                .accept(DartEmitter())
                .toString() +
            "}";
      }
      return Code(result);
    } else if (type == "controls_forRange") {
      DartEmitter emitter = DartEmitter();
      String start = expressionParser
          .parseExpressionXMLChild(block, "START", parseStatement)
          .accept(emitter)
          .toString();
      String end = expressionParser
          .parseExpressionXMLChild(block, "END", parseStatement)
          .accept(emitter)
          .toString();
      String step = expressionParser
          .parseExpressionXMLChild(block, "STEP", parseStatement)
          .accept(emitter)
          .toString();
      Code do0 =
          parseStatement(findBlockOfXMLChildByName(block, "DO", "statement"));
      String name = findXMLChildByName(block, "VAR", "field").innerText;

      return Code("for( int " +
          name +
          " = " +
          start +
          "; " +
          name +
          " < " +
          end +
          "; " +
          name +
          " = " +
          name +
          " + " +
          step +
          "){" +
          do0.accept(emitter).toString() +
          "}");
    } else if (type == "controls_forEach") {
      DartEmitter emitter = DartEmitter();
      Expression list = expressionParser.parseExpressionXMLChild(
          block, "LIST", parseStatement);
      Code do0 =
          parseStatement(findBlockOfXMLChildByName(block, "DO", "statement"));

      return Code("for(" +
          findXMLChildByName(block, "VAR", "field").innerText +
          ":" +
          list.accept(emitter).toString() +
          "){" +
          do0.accept(emitter).toString() +
          "}");
    } else if (type == "controls_while") {
      Expression condition = expressionParser.parseExpressionXMLChild(
          block, "TEST", parseStatement);
      Code do0 =
          parseStatement(findBlockOfXMLChildByName(block, "DO", "statement"));
      return Code("while(" +
          condition.accept(DartEmitter()).toString() +
          "){" +
          do0.accept(DartEmitter()).toString() +
          "}");
    } else if (type == "controls_eval_but_ignore") {
      Expression value = expressionParser.parseExpressionXMLChild(
          block, "VALUE", parseStatement);
      return value.statement;
    } else if (type.startsWith("lists_")) {
      switch (type) {
        case "lists_insert_item":
          {
            Expression list = expressionParser.parseExpressionXMLChild(
                block, "LIST", parseStatement);
            Expression index = expressionParser.parseExpressionXMLChild(
                block, "INDEX", parseStatement);
            Expression item = expressionParser.parseExpressionXMLChild(
                block, "ITEM", parseStatement);
            return list.property("insert")([index, item]).statement;
          }
        case "lists_replace_item":
          {
            Expression list = expressionParser.parseExpressionXMLChild(
                block, "LIST", parseStatement);
            Expression index = expressionParser.parseExpressionXMLChild(
                block, "INDEX", parseStatement);
            Expression item = expressionParser.parseExpressionXMLChild(
                block, "ITEM", parseStatement);
            return list.operatorBracketAccessor(index).assign(item).statement;
            // Previous code, since operatorBracketAccessor didn't exist
            // in published code_builder
            // return CodeExpression(Code(list.accept(emitter).toString() +
            //         "[" +
            //         index.accept(emitter).toString() +
            //         "]"))
            //     .assign(item)
            //     .statement;
          }
        case "lists_remove_item":
          {
            Expression list = expressionParser.parseExpressionXMLChild(
                block, "LIST", parseStatement);
            Expression index = expressionParser.parseExpressionXMLChild(
                block, "INDEX", parseStatement);

            return list.property("removeAt")([index]).statement;
          }
        case "lists_append_list":
          {
            Expression list0 = expressionParser.parseExpressionXMLChild(
                block, "LIST0", parseStatement);
            Expression list1 = expressionParser.parseExpressionXMLChild(
                block, "List1", parseStatement);

            return list0.property("addAll")([list1]).statement;
          }
        default:
          return literalString(type + "not found").statement;
      }
    } else if (type == "dictionaries_set_pair") {
      Expression key = expressionParser.parseExpressionXMLChild(
          block, "KEY", parseStatement);
      Expression dict = expressionParser.parseExpressionXMLChild(
          block, "DICT", parseStatement);
      Expression value = expressionParser.parseExpressionXMLChild(
          block, "VALUE", parseStatement);
      return dict.operatorBracketAccessor(key).assign(value).statement;
    } else if (type == "dictionaries_delete_pair") {
      Expression key = expressionParser.parseExpressionXMLChild(
          block, "KEY", parseStatement);
      Expression dict = expressionParser.parseExpressionXMLChild(
          block, "DICT", parseStatement);
      return dict.property("remove")([key]).statement;
    } else if (type == "lexical_variable_set") {
      Expression value = expressionParser.parseExpressionXMLChild(
          block, "VALUE", parseStatement);
      return wrapWithSetState(r(findXMLChildByName(block, "VAR", "field")
              .innerText
              .replaceAll("global ", "var_"))
          .assign(value)
          .statement);
    } else if (type == "local_declaration_statement") {
      Code stack = parseStatement(
          findBlockOfXMLChildByName(block, "STACK", "statement"));
      Expression value = expressionParser.parseExpressionXMLChild(
          block, "DECL0", parseStatement);
      String varName = block
          .findElements("field")
          .where((element) =>
              element.getAttribute("name")?.startsWith("VAR") ?? false)
          .first
          .innerText;
      return Block.of([value.assignVar(varName).statement, stack]);
    } else if (type == "procedures_callnoreturn") {
      String name = findXMLChildByName(block, "PROCNAME", "field").innerText;
      var arguments = <Expression>[];
      block
          .findElements("value")
          .where((element) =>
              element.getAttribute("name")?.startsWith("ARG") ?? false)
          .forEach((element) {
        arguments.add(expressionParser.parseExpression(
            element.getElement("block")!, parseStatement));
      });
      return r(getMethodName(name))(arguments).statement;
    } else {
      return r("print")([literalString("hello")]).statement;
    }
  }

  Code parseStatementComponentMethod(XmlElement block) {
    var mutation = block.getElement("mutation")!;
    var instanceName = getInstanceName(mutation);
    var methodName = mutation.getAttribute("method_name")!;
    final componentType = mutation.getAttribute("component_type");
    if (componentType == "TextBox" && methodName == "HideKeyboard") {
      return const Code("FocusManager.instance.primaryFocus?.unfocus();");
    } else if (componentType == "DatePicker") {
      return parseStatementDatePickerMethod(methodName, instanceName, block);
    } else if (componentType == "TimePicker") {
      return parseStatementTimePickerMethod(methodName, instanceName, block);
    } else if (componentType == "Notifier") {
      return parseStatementNotifierMethod(methodName, block, instanceName);
    } else if (componentType == "PhoneCall" && methodName == "MakePhoneCall") {
      return r("launch", urlLauncherPackage)([
        literalString("tel:")
            .operatorAdd(getExpressionForAttribute(instanceName, "PhoneNumber"))
      ]).statement;
    } else if (componentType == "Sharing") {
      return parseStatementSharingMethod(methodName, block, instanceName);
    } else if (componentType == "Texting" && methodName == "SendMessage") {
      //TODO possibly we need to use sms:// for some android platforms
      return r("launch", urlLauncherPackage)([
        literalString("sms:").operatorAdd(getExpressionForAttribute(
                instanceName, "PhoneNumber")
            .operatorAdd(literalString("&body="))
            .operatorAdd(getExpressionForAttribute(instanceName, "Message")))
      ]).statement;
    } else if (componentType == "File") {
      return parseStatementFileMethod(methodName, block, instanceName);
    } else if (componentType == "Camera" && methodName == "TakePicture") {
      return r("ImagePicker", imagePickerPackage)
          .newInstance([])
          .property("pickImage")([], {"source": r("ImageSource.camera")})
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p
                ..name = "value"
                ..type = r("XFile")))
              ..body = Block.of([
                safeCallEventHandler(
                    getDartEventHandler(state, instanceName, "AfterPicture"),
                    [r("value.path")])
              ])).closure
          ])
          .statement;
    } else if (componentType == "Camcorder" && methodName == "RecordView") {
      return r("ImagePicker", imagePickerPackage)
          .newInstance([])
          .property("pickVideo")([], {"source": r("ImageSource.camera")})
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p
                ..name = "value"
                ..type = r("XFile")))
              ..body = Block.of([
                safeCallEventHandler(
                    getDartEventHandler(state, instanceName, "AfterRecording"),
                    [r("value.path")])
              ])).closure
          ])
          .statement;
    } else if (componentType == "TinyDB") {
      return parseStatementTinyDBMethod(methodName, block, instanceName);
    } else if (componentType == "TinyWebDB") {
      return parseStatementTinyWebDBMethod(methodName, block, instanceName);
    }
    return parseStatementComponentMethodError(instanceName, methodName);
  }

  Code parseStatementDatePickerMethod(
      String methodName, String instanceName, XmlElement block) {
    if (methodName == "LaunchPicker") {
      return r(instanceName + "_launchPicker")([r("latestContext")]).statement;
    } else if (methodName == "SetDateToDisplay") {
      var year = expressionParser
          .parseArgExpression(block, 0, parseStatement)
          .asA(r("int"));
      var month = expressionParser
          .parseArgExpression(block, 1, parseStatement)
          .asA(r("int"));
      var day = expressionParser
          .parseArgExpression(block, 2, parseStatement)
          .asA(r("int"));
      return r(instanceName + "_Date")
          .assign(r("DateTime").newInstanceNamed("utc", [year, month, day]))
          .statement;
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementTimePickerMethod(
      String methodName, String instanceName, XmlElement block) {
    if (methodName == "LaunchPicker") {
      return r(instanceName + "_launchPicker")([r("context")]).statement;
    } else if (methodName == "SetTimeToDisplay") {
      var hour = expressionParser
          .parseArgExpression(block, 0, parseStatement)
          .asA(r("int"));
      var minute = expressionParser
          .parseArgExpression(block, 1, parseStatement)
          .asA(r("int"));
      return r(instanceName + "_Time")
          .assign(
              r("TimeOfDay").newInstance([], {"hour": hour, "minute": minute}))
          .statement;
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementNotifierMethod(
      String methodName, XmlElement block, String instanceName) {
    if (["LogInfo", "LogWarning", "LogError"].contains(methodName)) {
      // print("(I): <message>")
      return r("print")([
        literalString("(" + methodName.substring(3, 4) + "): ").operatorAdd(
            expressionParser.parseArgExpression(block, 0, parseStatement))
      ]).statement;
    } else if (methodName == "ShowMessageDialog") {
      return getDartCodeForDialog(
          instanceName,
          DialogType.message,
          expressionParser.parseArgExpression(block, 0, parseStatement),
          expressionParser.parseArgExpression(block, 1, parseStatement),
          button1:
              expressionParser.parseArgExpression(block, 2, parseStatement));
    } else if (methodName == "ShowProgressDialog") {
      return getDartCodeForDialog(
        instanceName,
        DialogType.progress,
        expressionParser.parseArgExpression(block, 0, parseStatement),
        expressionParser.parseArgExpression(block, 1, parseStatement),
      );
    } else if (methodName == "ShowChooseDialog") {
      return getDartCodeForDialog(
        instanceName,
        DialogType.choose,
        expressionParser.parseArgExpression(block, 0, parseStatement),
        expressionParser.parseArgExpression(block, 1, parseStatement),
        button1: expressionParser.parseArgExpression(block, 2, parseStatement),
        button2: expressionParser.parseArgExpression(block, 3, parseStatement),
      );
    } else if (["ShowTextDialog", "ShowPasswordDialog"].contains(methodName)) {
      return getDartCodeForDialog(
        instanceName,
        methodName == "ShowTextDialog" ? DialogType.text : DialogType.password,
        expressionParser.parseArgExpression(block, 0, parseStatement),
        expressionParser.parseArgExpression(block, 1, parseStatement),
        cancelable:
            expressionParser.parseArgExpression(block, 2, parseStatement),
      );
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementSharingMethod(
      String methodName, XmlElement block, String instanceName) {
    if (methodName == "ShareMessage") {
      return r("Share", sharePlusPackage)
          .property("share")
          ([expressionParser.parseArgExpression(block, 0, parseStatement)])
          .statement;
    } else if (methodName == "ShareFile") {
      return r("Share", sharePlusPackage)
          .property("shareFiles")([
            literalList(
                [expressionParser.parseArgExpression(block, 0, parseStatement)])
          ])
          .statement;
    } else if (methodName == "ShareFileWithMessage") {
      return r("Share", sharePlusPackage)
          .property("shareFiles")([
            literalList(
                [expressionParser.parseArgExpression(block, 0, parseStatement)])
          ], {
            "text":
                expressionParser.parseArgExpression(block, 1, parseStatement)
          })
          .statement;
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementFileMethod(
      String methodName, XmlElement block, String instanceName) {
    if (methodName == "SaveFile") {
      Expression text =
          expressionParser.parseArgExpression(block, 0, parseStatement);
      Expression filename =
          expressionParser.parseArgExpression(block, 1, parseStatement);
      // generates code like: XFile.fromData(utf8.encode('hello world'), name: 'test.txt', mimeType: 'text/plain')
      //         .saveTo('test.txt').then((String value) => File1_AfterFileSaved(value));
      return r("XFile", xfilePackage)
          .newInstanceNamed("fromData", [
            r("utf8.encode", convertPackage)([text])
          ], {
            "name": filename,
            "mimeType": literalString("text/plain"),
          })
          .property("saveTo")([filename])
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p..name = "value"))
              ..body = Block.of([
                safeCallEventHandler(
                    getDartEventHandler(state, instanceName, "AfterFileSaved"),
                    [filename])
              ])).closure
          ])
          .statement;
    } else if (methodName == "ReadFrom") {
      Expression filename =
          expressionParser.parseArgExpression(block, 0, parseStatement);
      // generates code like: XFile("a.txt").readAsString().then((value) => File1_GotText(value));
      return r("XFile", xfilePackage)
          .newInstance([filename])
          .property("readAsString")([])
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p
                ..name = "value"
                ..type = r("String")))
              ..body = Block.of([
                safeCallEventHandler(
                    getDartEventHandler(state, instanceName, "GotText"),
                    [r("value")])
              ])).closure
          ])
          .statement;
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementTinyDBMethod(
      String methodName, XmlElement block, String instanceName) {
    state.usesSharedPreferences = true;
    if (methodName == "StoreValue") {
      Expression tag = expressionParser.parseExpressionXMLChild(
          block, "ARG0", parseStatement);
      Expression value = expressionParser.parseExpressionXMLChild(
          block, "ARG1", parseStatement);
      return r("sharedPrefs", sharedPrefsPackage)
          .property("setString")([tag, value])
          .statement;
    } else if (methodName == "ClearAll") {
      return r("sharedPrefs", sharedPrefsPackage)
          .property("clear")([])
          .statement;
    } else if (methodName == "ClearTag") {
      Expression tag = expressionParser.parseExpressionXMLChild(
          block, "ARG0", parseStatement);
      return r("sharedPrefs", sharedPrefsPackage)
          .property("remove")([tag])
          .statement;
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementTinyWebDBMethod(
      String methodName, XmlElement block, String instanceName) {
    if (methodName == "StoreValue") {
      Expression tag = expressionParser.parseExpressionXMLChild(
          block, "ARG0", parseStatement);
      Expression value = expressionParser.parseExpressionXMLChild(
          block, "ARG1", parseStatement);
      return r("post", httpPackage)([
        r("Uri.parse")([
          getExpressionForAttribute(instanceName, "ServiceUrl")
              .operatorAdd(literalString("/storevalue"))
        ])
      ], {
        "body": literalMap({
          literalString("tag"): tag,
          literalString("value"): value,
          literalString("fmt"): literalString("json")
        })
      })
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p..name = "value"))
              ..body = Block.of([
                safeCallEventHandler(
                    getDartEventHandler(state, instanceName, "ValueStored"))
              ])).closure
          ])
          .statement;
    } else if (methodName == "GetValue") {
      Expression tag = expressionParser.parseExpressionXMLChild(
          block, "ARG0", parseStatement);

      return r("post", httpPackage)([
        r("Uri.parse")([
          getExpressionForAttribute(instanceName, "ServiceUrl")
              .operatorAdd(literalString("/getvalue"))
        ])
      ], {
        "body": literalMap({
          literalString("tag"): tag,
          literalString("fmt"): literalString("json")
        })
      })
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p..name = "value"))
              ..body = Block.of([
                safeCallEventHandler(
                    getDartEventHandler(state, instanceName, "GotValue"), [
                  r("jsonDecode", convertPackage)([r("value").property("body")])
                      .operatorBracketAccessor(literalNum(1)),
                  r("jsonDecode", convertPackage)([r("value").property("body")])
                      .operatorBracketAccessor(literalNum(2))
                ])
              ])).closure
          ])
          .statement;
    } else {
      return parseStatementComponentMethodError(instanceName, methodName);
    }
  }

  Code parseStatementComponentMethodError(
      String instanceName, String methodName) {
    return Code(
        "print('$instanceName : $methodName - error generating dart method');");
  }

  Code getDartCodeForDialog(String componentName, DialogType type,
      Expression message, Expression title,
      {Expression? button1,
      Expression? button2,
      Expression cancelable = ltrue}) {
    bool text = (type == DialogType.text || type == DialogType.password);

    return r("showDialog")([], {
      "context": r("latestContext"),
      "barrierDismissible": cancelable,
      "builder": Method((m) => m
        ..requiredParameters.add(Parameter((p) => p
          ..name = "context"
          ..type = r("BuildContext")))
        ..body = Block.of([
          if (text)
            r("TextEditingController")
                .newInstance([])
                .assignVar("controller")
                .statement,
          r("AlertDialog")
              .newInstance([], {
                "title": r("Text").constInstance([title]),
                "content": r("Column").newInstance([], {
                  "mainAxisSize": r("MainAxisSize.min"),
                  "children": literalList([
                    r("Text").constInstance([message]),
                    if (type == DialogType.progress)
                      r("CircularProgressIndicator").constInstance([]),
                    if (text)
                      r("TextField").newInstance([], {
                        "controller": r("controller"),
                        if (type == DialogType.password) "obscureText": ltrue,
                      }),
                  ])
                }),
                "actions": literalList([
                  r("TextButton").newInstance([], {
                    "child": r("Text")
                        .constInstance([button1 ?? literalString("OK")]),
                    "onPressed": Method((m) => m
                      ..body = Block.of([
                        if (text)
                          safeCallEventHandler(
                              getDartEventHandler(
                                  state, componentName, "AfterTextInput"),
                              [r("controller.text")]),
                        if (type == DialogType.choose && button1 != null)
                          safeCallEventHandler(
                              getDartEventHandler(
                                  state, componentName, "AfterChoosing"),
                              [button1]),
                        r("Navigator.of(context).pop")([]).statement,
                      ])).closure,
                  }),
                  if (button2 != null)
                    r("TextButton").newInstance([], {
                      "child": r("Text").constInstance([button2]),
                      "onPressed": Method((m) => m
                        ..body = Block.of([
                          if (type == DialogType.choose)
                            safeCallEventHandler(
                                getDartEventHandler(
                                    state, componentName, "AfterChoosing"),
                                [button2]),
                          r("Navigator.of(context).pop")([]).statement,
                        ])).closure,
                    }),
                ])
              })
              .returned
              .statement
        ])).closure
    }).statement;
  }

  /// Used when parsing blocks: get the expression to access the variable for
  /// a component attribute
  /// IMPORTANT: has side effect: puts null into fields for that variable -->
  /// so that a dart variable is actually later created.
  Reference getExpressionForAttribute(String instanceName, String attribute) {
    state.fields[instanceName + "_" + attribute] = null;
    return r(instanceName + "_" + attribute);
  }

  Code wrapWithSetState(Code code) {
    return r("setState")([Method((d) => d..body = code).closure]).statement;
  }
}

enum DialogType { message, choose, password, progress, text }
