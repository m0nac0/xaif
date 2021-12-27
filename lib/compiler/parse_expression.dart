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

import 'parsing_state.dart';
import 'util_parser.dart';
import 'util_xml.dart';

class ExpressionParser {
  ExpressionParser(this.state);

  ParsingState state;

// Helper methods for common scenarios (mostly necessary due to the structure
// of the xml)
  Expression parseArgExpression(
      block, int i, Code Function(XmlElement block) parseStatement) {
    return parseExpression(
        findBlockOfXMLChildByName(block, "ARG$i"), parseStatement);
  }

  Expression parseExpressionXMLChildA(
          XmlElement block, Code Function(XmlElement block) parseStatement) =>
      parseExpressionXMLChild(block, "A", parseStatement);

  Expression parseExpressionXMLChildB(
          XmlElement block, Code Function(XmlElement block) parseStatement) =>
      parseExpressionXMLChild(block, "B", parseStatement);

  /// Finds a child of the block and parses it as expression
  Expression parseExpressionXMLChild(XmlElement block, String name,
          Code Function(XmlElement block) parseStatement,
          [String elementTag = "value"]) =>
      parseExpression(findBlockOfXMLChildByName(block, name), parseStatement);

  /// Parses an expression (builtin blocks or component methods)
  Expression parseExpression(
      XmlElement block, Code Function(XmlElement block) parseStatement) {
    final type = block.getAttribute("type")!;
    Expression? result;
    if (type.startsWith("text")) {
      result = parseExpressionText(type, block, parseStatement);
    } else if (type.startsWith("logic")) {
      result = parseExpressionLogic(type, block, parseStatement);
    } else if (type.startsWith("math")) {
      result = parseExpressionMath(type, block, parseStatement);
    } else if (type.startsWith("lists")) {
      result = parseExpressionLists(type, block, parseStatement);
    } else if (type.startsWith("dictionaries")) {
      result = parseExpressionDicts(type, block, parseStatement);
    } else if (type.startsWith("color")) {
      result = getDartColor(block.getElement("field")!.innerText.substring(1));
    }
    if (result == null) {
      switch (type) {
        case "component_set_get":
          {
            var mutation = block.getElement("mutation")!;
            var componentType = getComponentType(mutation);
            var instanceName = getInstanceName(mutation);
            var propertyName = mutation.getAttribute("property_name")!;

            if (componentType == "TextBox" && propertyName == "Text") {
              return r(instanceName + "_Controller").property("text");
            } else if (componentType == "DatePicker") {
              // Currently set/displayed/chosen date is stored as DateTime variable
              if (["Day", "Month", "Year"].contains(propertyName)) {
                return r(instanceName + "_Date")
                    .property(propertyName.toLowerCase());
              }
            } else if (componentType == "TimePicker") {
              // Currently set/displayed/chosen time is stored as TimeOfDay variable
              if (["Hour", "Minute"].contains(propertyName)) {
                return r(instanceName + "_Time")
                    .property(propertyName.toLowerCase());
              }
            }
            // Fallback if no special case:
            final textVar = instanceName + "_" + propertyName;
            state.ensureFieldExists(textVar);
            return r(textVar);
          }
        case "component_method":
          {
            return parseExpressionComponentMethod(block, parseStatement);
          }
        case "controls_choose":
          {
            Expression condition = parseExpression(
                findBlockOfXMLChildByName(block, "TEST"), parseStatement);
            Expression thenValue = parseExpression(
                findBlockOfXMLChildByName(block, "THENRETURN"), parseStatement);
            Expression elseValue = parseExpression(
                findBlockOfXMLChildByName(block, "ELSERETURN"), parseStatement);
            return optimizedConditional(condition, thenValue, elseValue);
          }
        case "controls_do_then_return":
          {
            Expression returnVal = parseExpression(
                findBlockOfXMLChildByName(block, "VALUE"), parseStatement);
            Code value = parseStatement(
                findBlockOfXMLChildByName(block, "STM", "statement"));
            // e.g.: (){doSth(); return "a";}()
            return Method((m) =>
                    m..body = Block.of([value, returnVal.returned.statement]))
                .closure
                .call([]);
          }
        case "lexical_variable_get":
          {
            return r(findXMLChildByName(block, "VAR", "field")
                .innerText
                .replaceAll("global ", "var_"));
          }
        case "procedures_callreturn":
          {
            String name =
                findXMLChildByName(block, "PROCNAME", "field").innerText;
            var arguments = <Expression>[];
            block
                .findElements("value")
                .where((element) =>
                    element.getAttribute("name")?.startsWith("ARG") ?? false)
                .forEach((element) {
              arguments.add(parseExpression(
                  element.getElement("block")!, parseStatement));
            });

            return r(getMethodName(name))(arguments);
          }

        case "color_split_color":
          {
            Expression color = getDartColor(
                findXMLChildByName(block, "Color", "field")
                    .innerText
                    .substring(1));
            return literalList([
              color.property("red"),
              color.property("green"),
              color.property("blue")
            ]);
          }
        case "color_make_color":
          {
            Expression colorListGetter = parseExpression(
                    findBlockOfXMLChildByName(block, "COLORLIST"),
                    parseStatement)
                .property("getElementAt");
            return r("Color").newInstanceNamed("fromRGB0", [
              colorListGetter([literalNum(0)]),
              colorListGetter([literalNum(1)]),
              colorListGetter([literalNum(2)])
            ]);
          }

        // Dictionaries (this one block from the dictionaries category doesn't
        // start with "dictionaries"
        case "pair":
          {
            Expression key = parseExpression(
                findBlockOfXMLChildByName(block, "KEY"), parseStatement);
            Expression value = parseExpression(
                findBlockOfXMLChildByName(block, "VALUE"), parseStatement);
            return r("MapEntry").newInstance([key, value]);
          }

        case "local_declaration_expression":
          {
            Expression returnVal = parseExpression(
                findBlockOfXMLChildByName(block, "RETURN"), parseStatement);
            Expression value = parseExpression(
                findBlockOfXMLChildByName(block, "DECL0"), parseStatement);
            String varName = block
                .findElements("field")
                .where((element) =>
                    element.getAttribute("name")?.startsWith("VAR") ?? false)
                .first
                .innerText;
            // e.g.: (){var a="a"; return getVal();}()
            return Method((m) => m
              ..body = Block.of([
                value.assignVar(varName).statement,
                returnVal.returned.statement
              ])).closure.call([]);
          }
        default:
          {
            return r("print('$type not found')");
          }
      }
    } else {
      return result;
    }
  }

  /// Expressions from component methods blocks
  Expression parseExpressionComponentMethod(
      XmlElement block, Code Function(XmlElement block) parseStatement) {
    var mutation = block.getElement("mutation")!;
    var instanceName = getInstanceName(mutation);
    var methodName = mutation.getAttribute("method_name");
    final componentType = mutation.getAttribute("component_type");

    if (componentType == "TinyDB" && methodName == "GetValue") {
      state.usesSharedPreferences = true;
      Expression tag = parseArgExpression(block, 0, parseStatement);
      Expression alternative = parseArgExpression(block, 1, parseStatement);
      return r("sharedPrefs", sharedPrefsPackage)
          .property("get")([tag])
          .ifNullThen(alternative);
    } else if (componentType == "TinyDB" && methodName == "GetTags") {
      state.usesSharedPreferences = true;
      return r("sharedPrefs", sharedPrefsPackage).property("getKeys")([]);
    } else if (componentType == "PhoneStatus" && methodName == "isDirect") {
      return r("true/*TODO not implemented*/");
    } else if (componentType == "Web") {
      if (methodName == "UriDecode") {
        return r("Uri.decodeComponent")(
            [parseArgExpression(block, 0, parseStatement)]);
      } else if (methodName == "UriEncode") {
        return r("Uri.encodeComponent")(
            [parseArgExpression(block, 0, parseStatement)]);
      } else if (methodName == "HtmlTextDecode") {
        return r("parseFragment", htmlPackage)(
            [parseArgExpression(block, 0, parseStatement)]).property("text");
      } else if (methodName == "JsonObjectEncode") {
        return r("jsonEncode", convertPackage)(
            [parseArgExpression(block, 0, parseStatement)]);
      } else if (methodName == "JsonTextDecode") {
        return r("jsonDecode", convertPackage)(
            [parseArgExpression(block, 0, parseStatement)]);
      }
    }
    return literalString(
        "component expression not found $instanceName:$methodName!");
  }

  /// Parse an expression from the text category of builtin blocks
  Expression? parseExpressionText(String type, XmlElement block,
      Code Function(XmlElement block) parseStatement) {
    switch (type) {
      case "text":
        {
          return literalString(block.getElement("field")!.innerText);
        }
      case "text_changeCase":
        {
          bool up = block.getElement("field")!.innerText == "UPCASE";
          final input = parseExpression(
              block.getElement("value")!.getElement("block")!, parseStatement);
          return input.property(up ? "toUpperCase" : "toLowerCase").call([]);
        }
      case "text_join":
        {
          int items = getXMLItemCount(block);
          Expression result = literalString("");
          for (int i = 0; i < items; i++) {
            result = result.operatorEuclideanModulo(parseExpression(
                findBlockOfXMLChildByName(block, "ADD$i"), parseStatement));
          }
          state.usesSafeStringAddition = true;
          return result;
        }
      case "text_compare":
        {
          Expression A =
              parseExpressionXMLChild(block, "TEXT1", parseStatement);
          Expression B =
              parseExpressionXMLChild(block, "TEXT2", parseStatement);
          switch (findXMLChildOp(block)) {
            case "EQUAL":
              {
                return A.property("compareTo")([B]).equalTo(literalNum(0));
              }
            case "NEQ":
              {
                return A.property("compareTo")([B]).notEqualTo(literalNum(0));
              }
            case "LT":
              {
                return A.property("compareTo")([B]).lessThan(literalNum(0));
              }
            case "GT":
              {
                return A.property("compareTo")([B]).greaterThan(literalNum(0));
              }
            default:
              {
                return A.property("compareTo")([B]).equalTo(literalNum(0));
              }
          }
        }
      case "text_contains":
        {
          //TODO other ops than contains (any/all); good first issue
          return parseExpression(
                  findBlockOfXMLChildByName(block, "TEXT"), parseStatement)
              .property("contains")([
            parseExpression(
                findBlockOfXMLChildByName(block, "PIECE"), parseStatement)
          ]);
        }
      case "text_is_string":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "ITEM"), parseStatement)
              .isA(r("String"));
        }
      case "text_split":
        {
          //TODO other ops
          return parseExpression(
                  findBlockOfXMLChildByName(block, "TEXT"), parseStatement)
              .property("split")([
            parseExpression(
                findBlockOfXMLChildByName(block, "AT"), parseStatement)
          ]);
        }
      case "text_split_at_spaces":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "TEXT"), parseStatement)
              .property("split")([literalString(" ")]);
        }
      case "text_isEmpty":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "VALUE"), parseStatement)
              .property("isEmpty");
        }
      case "text_reverse":
        {
          return r("String").newInstanceNamed("fromCharCodes", [
            parseExpression(
                    findBlockOfXMLChildByName(block, "VALUE"), parseStatement)
                .property("runes")
                .property("toList")([])
                .property("reversed")
          ]);
        }
      case "text_trim":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "TEXT"), parseStatement)
              .property("trim")([]);
        }
      case "text_starts_at":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "TEXT"), parseStatement)
              .property("indexOf")([
            parseExpression(
                findBlockOfXMLChildByName(block, "PIECE"), parseStatement)
          ]);
        }
    }
  }

  /// Parse an expression from the logic category of builtin blocks
  Expression? parseExpressionLogic(String type, XmlElement block,
      Code Function(XmlElement block) parseStatement) {
    switch (type) {
      case "logic_boolean":
      case "logic_false":
      case "logic_true":
        {
          return block.getElement("field")!.innerText == "TRUE"
              ? ltrue
              : lfalse;
        }
      case "logic_negate":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "BOOL"), parseStatement)
              .negate();
        }
      case "logic_compare":
        {
          Expression A = parseExpressionXMLChildA(block, parseStatement);
          Expression B = parseExpressionXMLChildB(block, parseStatement);
          return findXMLChildOp(block) == "NEQ"
              ? A.notEqualTo(B)
              : A.equalTo(B);
        }
      case "logic_or":
      case "logic_operation":
        {
          Expression A = parseExpressionXMLChildA(block, parseStatement);
          Expression B = parseExpressionXMLChildB(block, parseStatement);
          return findXMLChildOp(block) == "AND" ? A.and(B) : A.or(B);
        }
    }
  }

  /// Parse an expression from the math category of builtin blocks
  Expression? parseExpressionMath(String type, XmlElement block,
      Code Function(XmlElement block) parseStatement) {
    switch (type) {
      case "math_number":
        {
          var parsed = int.tryParse(
                  findXMLChildByName(block, "NUM", "field").innerText) ??
              (double.tryParse(
                      findXMLChildByName(block, "NUM", "field").innerText) ??
                  0);
          return literalNum(parsed);
        }
      case "math_number_radix":
        {
          //TODO other ops
          switch (findXMLChildOp(block)) {
            case "DEC":
              {
                return literalNum(double.tryParse(
                        findXMLChildByName(block, "NUM", "field").innerText) ??
                    0);
              }
            default:
              return literalNum(double.tryParse(
                      findXMLChildByName(block, "NUM", "field").innerText) ??
                  0);
          }
        }
      case "math_compare":
        {
          Expression A = parseExpressionXMLChildA(block, parseStatement);
          Expression B = parseExpressionXMLChildB(block, parseStatement);
          switch (findXMLChildOp(block)) {
            case "EQ":
              {
                return A.equalTo(B);
              }
            default:
              {
                return A.equalTo(B);
              }
          }
        }
      case "math_add":
        {
          int items = getXMLItemCount(block);
          Expression result = parseExpression(
              findBlockOfXMLChildByName(block, "NUM0"), parseStatement);
          for (int i = 1; i < items; i++) {
            result = result.operatorAdd(parseExpression(
                findBlockOfXMLChildByName(block, "NUM$i"), parseStatement));
          }
          return result;
        }
      case "math_multiply":
        {
          int items = getXMLItemCount(block);
          Expression result = const CodeExpression(Code(""));
          for (int i = 0; i < items; i++) {
            result = result.operatorMultiply(parseExpression(
                findBlockOfXMLChildByName(block, "NUM$i"), parseStatement));
          }
          return result;
        }
      case "math_bitwise":
        {
          //TODO other ops
          int items = getXMLItemCount(block);
          Expression result = parseExpression(
              findBlockOfXMLChildByName(block, "NUM0"), parseStatement);
          for (int i = 1; i < items; i++) {
            switch (findXMLChildOp(block)) {
              case "BITAND":
                {
                  result.operatorBitwiseAnd(parseExpression(
                      findBlockOfXMLChildByName(block, "NUM$i"),
                      parseStatement));
                }
                break;
              default:
                {
                  result.operatorMultiply(parseExpression(
                      findBlockOfXMLChildByName(block, "NUM$i"),
                      parseStatement));
                }
            }
          }
          return result;
        }
      case "math_substract":
        {
          Expression A = parseExpressionXMLChildA(block, parseStatement);
          Expression B = parseExpressionXMLChildB(block, parseStatement);
          return A.operatorSubstract(B);
        }
      case "math_division":
        {
          Expression A = parseExpressionXMLChildA(block, parseStatement);
          Expression B = parseExpressionXMLChildB(block, parseStatement);
          return A.operatorDivide(B);
        }

      case "math_power":
        {
          Expression A = parseExpressionXMLChildA(block, parseStatement);
          Expression B = parseExpressionXMLChildB(block, parseStatement);
          return r("pow", mathPackage)([A, B]);
        }
      case "math_random_int":
        {
          Expression from = parseExpression(
              findBlockOfXMLChildByName(block, "FROM"), parseStatement);
          Expression to = parseExpression(
              findBlockOfXMLChildByName(block, "TO"), parseStatement);
          return r("Random", mathPackage)
              .newInstance([])
              .property("nextInt")([to.operatorSubstract(from)])
              .operatorAdd(from);
        }
      case "math_random_float":
        {
          return r("Random", mathPackage)
              .newInstance([]).property("nextDouble")([]);
        }
      case "math_on_lists":
        {
          int items = getXMLItemCount(block);
          Expression result = parseExpression(
              findBlockOfXMLChildByName(block, "NUM0"), parseStatement);
          for (int i = 1; i < items; i++) {
            // nest calls to min: min(min(min(a,b),c),d)
            result =
                r(findXMLChildOp(block) == "MIN" ? "min" : "max", mathPackage)([
              result,
              parseExpression(
                  findBlockOfXMLChildByName(block, "NUM$i"), parseStatement)
            ]);
          }
          return result;
        }
      case "math_single":
      case "math_neg":
      case "math_abs":
      case "math_round":
      case "math_ceiling":
      case "math_floor":
        {
          //TODO other ops: log, e
          String op = findXMLChildOp(block);
          Expression num = parseExpression(
              findBlockOfXMLChildByName(block, "NUM"), parseStatement);
          if (op == "NEG") {
            return num.operatorMultiply(literalNum(-1));
          } else if (op == "ROOT") {
            return r("sqrt", mathPackage)([num]);
          } else {
            late String dartFunction;
            switch (op) {
              case "ABS":
                {
                  dartFunction = "abs";
                }
                break;
              case "ROUND":
                {
                  dartFunction = "round";
                }
                break;
              case "CEILING":
                {
                  dartFunction = "ceil";
                }
                break;
              case "FLOOR":
                {
                  dartFunction = "floor";
                }
                break;
            }
            return num.property(dartFunction)([]);
          }
        }
    }
  }

  /// Parse an expression from the lists category of builtin blocks
  Expression? parseExpressionLists(String type, XmlElement block,
      Code Function(XmlElement block) parseStatement) {
    switch (type) {
      case "lists_create_empty":
        {
          return literalList([]);
        }
      case "lists_create_with":
        {
          int count =
              int.parse(block.getElement("mutation")!.getAttribute("items")!);
          var items = <Expression>[];
          for (int i = 0; i < count; i++) {
            items.add(
              parseExpression(
                  findBlockOfXMLChildByName(block, "ADD$i"), parseStatement),
            );
          }
          return literalList(items);
        }
      case "lists_length":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "LIST"), parseStatement)
              .property("length");
        }
      case "lists_is_empty":
        {
          return parseExpression(
                  findBlockOfXMLChildByName(block, "LIST"), parseStatement)
              .property("isEmpty");
        }
      case "lists_is_in":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);
          Expression item = parseExpression(
              findBlockOfXMLChildByName(block, "ITEM"), parseStatement);
          return list.property("contains")([item]);
        }
      case "lists_pick_random_item":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);
          return list.property("elementAt")([
            r("Random", mathPackage).newInstance([list.property("length")])
          ]);
        }
      case "lists_position_in":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);
          Expression item = parseExpression(
              findBlockOfXMLChildByName(block, "ITEM"), parseStatement);
          return list.property("indexOf")([item]);
        }
      case "lists_select_item":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);
          Expression num = parseExpression(
              findBlockOfXMLChildByName(block, "NUM"), parseStatement);
          return list.property("elementAt")([num]);
        }
      case "lists_copy":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);

          return list.property("asList")([]);
        }

      case "lists_is_list":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);

          return list.isA(r("Iterable"));
        }
      case "lists_reverse":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);
          return list.property("reversed");
        }
      case "lists_to_csv_row":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"),
              parseStatement); // [1].map((e) => e.toString())
          return list
              .property("map")([
                Method((m) => m
                  ..lambda = true
                  ..requiredParameters
                      .add(Parameter((p) => p..name = "element"))
                  ..body = r("element").property("toString")([]).code).closure
              ])
              .property("join")([literalString(",")]);
        }
      case "lists_from_csv_row":
        {
          Expression text = parseExpression(
              findBlockOfXMLChildByName(block, "TEXT"), parseStatement);
          return text.property("split")([literalString(",")]);
        }
      //TODO lists_to_csv_table,lists_from_csv_table, lists_lookup_in_pairs
      case "lists_join_with_separator":
        {
          Expression list = parseExpression(
              findBlockOfXMLChildByName(block, "LIST"), parseStatement);
          Expression separator = parseExpression(
              findBlockOfXMLChildByName(block, "SEPARATOR"), parseStatement);
          return list
              .property("map")([
                Method((m) => m
                  ..lambda = true
                  ..requiredParameters
                      .add(Parameter((p) => p..name = "element"))
                  ..body = r("element").property("toString")([]).code).closure
              ])
              .property("join")([separator]);
        }
    }
  }

  /// Parse an expression from the dictionaries category of builtin blocks
  Expression? parseExpressionDicts(String type, XmlElement block,
      Code Function(XmlElement block) parseStatement) {
    switch (type) {
      // NB: "pair" block also belongs to dictionaries, but is handled in
      // parseExpression
      case "dictionaries_lookup":
        {
          Expression key = parseExpression(
              findBlockOfXMLChildByName(block, "KEY"), parseStatement);
          Expression dict = parseExpression(
              findBlockOfXMLChildByName(block, "DICT"), parseStatement);
          Expression notfound = parseExpression(
              findBlockOfXMLChildByName(block, "NOTFOUND"), parseStatement);

          return dict.operatorBracketAccessor(key).ifNullThen(notfound);
        }
      case "dictionaries_get_values":
      case "dictionaries_getters":
        {
          Expression dict = parseExpression(
              findBlockOfXMLChildByName(block, "DICT"), parseStatement);
          //op can be KEYS or VALUES
          String op = findXMLChildOp(block);
          return dict.property(op.toLowerCase());
        }
      case "dictionaries_is_key_in":
        {
          Expression key = parseExpression(
              findBlockOfXMLChildByName(block, "KEY"), parseStatement);
          Expression dict = parseExpression(
              findBlockOfXMLChildByName(block, "DICT"), parseStatement);
          return dict.property("containsKey")([key]);
        }
      case "dictionaries_length":
        {
          Expression dict = parseExpression(
              findBlockOfXMLChildByName(block, "DICT"), parseStatement);
          return dict.property("length");
        }
      case "dictionaries_is_dict":
        {
          Expression dict = parseExpression(
              findBlockOfXMLChildByName(block, "DICT"), parseStatement);
          return dict.isA(r("Map"));
        }
      case "dictionaries_create_with":
        {
          int count =
              int.parse(block.getElement("mutation")!.getAttribute("items")!);
          var items = <Expression>[];
          for (int i = 0; i < count; i++) {
            items.add(parseExpression(
                findBlockOfXMLChildByName(block, "ADD$i"), parseStatement));
          }
          return r("Map").newInstanceNamed("fromEntries", [literalList(items)]);
        }
    }
  }

// Dart helpers: Color

  /// Takes an AI color String like ff0000 and returns a Dart expression for
  /// a corresponding Color object
  Expression getDartColor(String colorString) {
    // this is quite a hack, CodeExpression shouldn't be used. The problem: code_builder can't construct hex literals
    // From blockly we get a color like "#FF0000" for red; Flutter expects "0xFFFF0000" (leading FF for alpha)
    return InvokeExpression.newOf(
        r("Color"), [CodeExpression(Code("0xFF" + colorString))]);
  }
}
