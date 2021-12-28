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
import 'dart:math';

import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';

import 'aia_compiler_constants.dart';
import 'parsing_state.dart';
import 'util_parser.dart';

class ComponentParser {
  ComponentParser(this.state);

  ParsingState state;

  /// Parse a component (from the SCM/JSON definition)
  /// Returns null for invisible components
  Expression? parseComponent(
      var component, bool unconstrainedWidth, bool unconstrainedHeight) {
    final String type = component["\$Type"];
    final String componentName = component["\$Name"];

    // contains the dart names of all properties of this component
    // Currently: componentName_propertyName
    Map<String, String> propsDartNames =
        getDartPropertiesForComponent(type, componentName);

    // Returns AI's default values for properties (from aia_compiler_constants.dart)
    // We need to manually store these, as AI will just leave out a property if
    // is has the default value
    Map<String, Expression?> defaultValues =
        getDefaultValuesForComponent(type, componentName);

    //TODO getDartExpressionForProperty has side effects! See comment on fields
    // We prob. should prefill a list with all dart expressions for all properties
    // That way we ensure that its called for every property and can access it easily

    // The list of event handlers for this component. Only contains events
    // which the user wants to handle. If the user didn't use the event
    // handling block for an event in AI, we completely ignore the event
    // (and do not, e.g. add an unnecessary empty event handling method)
    final Map<String, Expression?> eventHandlers = events[type] == null
        ? {}
        : getDartEventHandlers(events[type]!, componentName);
    switch (type) {
      case "Button":
        {
          return getDartExpressionForButton(
              propsDartNames,
              component,
              defaultValues,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "DatePicker":
        {
          //TODO refactor?: create a setField / setFieldInitialValue method??
          // Usually, if a property is never read or set in AI blocks, we don't
          // create a variable in dart but instead insert it's constant value directly
          // in the component definition.
          // But in some cases like this, we need to ensure that a dart variable
          // is created. Usually, because we create dart code that accesses this
          // variable. Here, we always assign the picking result to a var named
          // componentName_Date, so there needs to be such a variable, even if
          // the user never uses it.
          // Also see ParsingState#ensureFieldExists
          state.fields[propsDartNames["Date"]!] =
              r("DateTime").newInstanceNamed("now", []);

          state.addMethod(componentName, "launchPicker",
              getDatePickerLaunchMethod(componentName));
          eventHandlers["Click"] = wrapCodeWithEmptyLambda(
              r(state.methods[componentName]!["launchPicker"]!.name!)
                  .call([r("context")]));

          return getDartExpressionForButton(
              propsDartNames,
              component,
              defaultValues,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight,
              disableLongPress: true);
        }
      case "TimePicker":
        {
          state.fields[propsDartNames["Time"]!] =
              r("TimeOfDay").newInstanceNamed("now", []);

          state.addMethod(componentName, "launchPicker",
              getTimePickerLaunchMethod(componentName));

          eventHandlers["Click"] = wrapCodeWithEmptyLambda(
              r(state.methods[componentName]!["launchPicker"]!.name!)
                  .call([r("context")]));
          return getDartExpressionForButton(
              propsDartNames,
              component,
              defaultValues,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight,
              disableLongPress: true);
        }
      case "ImagePicker":
        {
          state.fields[propsDartNames["Selection"]!] = literalString("");

          state.addMethod(
              componentName, "Open", getImagePickerLaunchMethod(componentName));
          eventHandlers["Click"] = wrapCodeWithEmptyLambda(
              r(state.methods[componentName]!["Open"]!.name!)
                  .call([r("context")]));

          return getDartExpressionForButton(
              propsDartNames,
              component,
              defaultValues,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight,
              disableLongPress: true);
        }
      case "Label":
        {
          return maybeVisible(
              propsDartNames,
              component,
              defaultValues,
              getSizedComponentDartExpression(
                  propsDartNames,
                  component,
                  defaultValues,
                  getDartExpressionForTextComponent(materialPackage,
                      propsDartNames, component, defaultValues),
                  unconstrainedWidth,
                  unconstrainedHeight));
        }
      case "Switch":
      case "CheckBox":
        {
          return getSwitchOrCheckboxDartExpression(
              propsDartNames,
              type,
              defaultValues,
              component,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "TextBox":
        {
          return getTextfieldDartExpression(
              componentName,
              propsDartNames,
              component,
              defaultValues,
              unconstrainedWidth,
              unconstrainedHeight);
        }

      case "PasswordTextBox":
        {
          return getTextfieldDartExpression(componentName, propsDartNames,
              component, defaultValues, unconstrainedWidth, unconstrainedHeight,
              obscureText: true);
        }
      case "Slider":
        {
          return getSliderDartExpression(
              propsDartNames,
              component,
              defaultValues,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "Spinner":
        {
          return getSpinnerDartExpression(
              propsDartNames,
              component,
              defaultValues,
              eventHandlers,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "ListView":
        {
          return getListViewDartExpression(propsDartNames, component,
              defaultValues, unconstrainedWidth, unconstrainedHeight);
        }
      case "Image":
        {
          return getImageDartExpression(propsDartNames, component,
              defaultValues, unconstrainedWidth, unconstrainedHeight);
        }
      case "HorizontalArrangement":
        {
          return getDartExpressionForHorizontalArrangementComponent(
              component,
              propsDartNames,
              defaultValues,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "VerticalArrangement":
        {
          return getDartExpressionForVerticalArrangementComponent(
              component,
              propsDartNames,
              defaultValues,
              unconstrainedWidth,
              unconstrainedHeight);
        }

      case "HorizontalScrollArrangement":
      case "VerticalScrollArrangement":
        {
          return getDartExpressionForScrollArrangementComponent(
              component,
              propsDartNames,
              defaultValues,
              type,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "TableArrangement":
        {
          return getDartExpressionForTableArrangementComponent(
              component,
              propsDartNames,
              defaultValues,
              unconstrainedWidth,
              unconstrainedHeight);
        }
      case "Clock":
        {
          return null;
        }
      case "Player":
        {
          // Source: no effect when changed while playing (same in AI???)
          getDartExpressionForProperty(propsDartNames, "Source",
              getComponentStringProperty(component, "Source"), defaultValues);

          // Always create an AudioPlayer object
          var initialSource = literalString("assets/").operatorAdd(
              getComponentStringProperty(component, "Source") ??
                  literalString(""));
          // We have an internal source variable, that can only be accessed through
          // getters and setters (setter updates the player's source)
          state.fields[getPropertyDartName(componentName, "SourceInternal")] =
              initialSource;

          state.fields[componentName + "_Player"] =
              r("AudioPlayer", justAudioPackage)
                  .newInstance([]).property(".setAsset")([initialSource]);
          // We remap these properties to the AudioPlayer's properties
          state.gettersSetters.add(Method((m) => m
            ..type = MethodType.getter
            ..name = getPropertyDartName(componentName, "IsPlaying")
            ..returns = r("bool")
            ..body = r(getPropertyDartName(componentName, "Player"))
                .property("playing")
                .code
            ..lambda = true));

          state.gettersSetters.add(Method((m) => m
            ..type = MethodType.getter
            ..name = getPropertyDartName(componentName, "Loop")
            ..returns = r("bool")
            ..body = r(getPropertyDartName(componentName, "Player"))
                .property("loopMode")
                .equalTo(r("LoopMode.one"))
                .code
            ..lambda = true));
          // Intercept the property setter and redirect to AudioPlayer
          state.gettersSetters.add(Method((m) => m
            ..type = MethodType.setter
            ..name = getPropertyDartName(componentName, "Loop")
            ..requiredParameters.add(Parameter((p) => p..name = "value"))
            ..body = r(getPropertyDartName(componentName, "Player"))
                .property("setLoopMode")
                ([r("value").conditional(r("LoopMode.one"), r("LoopMode.off"))])
                .code
            ..lambda = true));

          state.gettersSetters.add(Method((m) => m
            ..type = MethodType.getter
            ..name = getPropertyDartName(componentName, "Source")
            ..returns = r("String")
            ..body =
                r(getPropertyDartName(componentName, "SourceInternal")).code
            ..lambda = true));
          state.gettersSetters.add(Method((m) => m
            ..type = MethodType.setter
            ..name = getPropertyDartName(componentName, "Source")
            ..requiredParameters.add(Parameter((p) => p..name = "value"))
            ..body = Block.of([
              r(getPropertyDartName(componentName, "SourceInternal"))
                  .assign(literalString("assets/").operatorAdd(r("value")))
                  .statement,
              r(getPropertyDartName(componentName, "Player"))
                  .property("setAsset")
                  ([r(getPropertyDartName(componentName, "SourceInternal"))])
                  .statement
            ])));
          //AI volume is 0-100; just_audio volume is: 1.0 normal
          state.usesEnsureNum = true;
          state.gettersSetters.add(Method((m) => m
            ..type = MethodType.setter
            ..name = getPropertyDartName(componentName, "Volume")
            ..requiredParameters.add(Parameter((p) => p..name = "value"))
            ..body = r(getPropertyDartName(componentName, "Player"))
                .property("setVolume")([
                  r("ensureNum")([r("value")]).operatorDivide(literalNum(100.0))
                ])
                .code
            ..lambda = true));
        }
        break;
      case "Web":
        {
          getDartExpressionForProperty(propsDartNames, "Url",
              getComponentStringProperty(component, "Url"), defaultValues);
          //invisible components
          return null;
        }
      case "PhoneCall":
        {
          getDartExpressionForProperty(
              propsDartNames,
              "PhoneNumber",
              getComponentStringProperty(component, "PhoneNumber"),
              defaultValues);
        }
        break;
      case "Texting":
        {
          getDartExpressionForProperty(
              propsDartNames,
              "PhoneNumber",
              getComponentStringProperty(component, "PhoneNumber"),
              defaultValues);
          getDartExpressionForProperty(propsDartNames, "Message",
              getComponentStringProperty(component, "Message"), defaultValues);
        }
        break;
      case "TinyWebDB":
        {
          getDartExpressionForProperty(
              propsDartNames,
              "ServiceUrl",
              getComponentStringProperty(component, "ServiceUrl"),
              defaultValues);
        }
        break;
      default:
        {
          return r("Container").newInstance([]);
        }
    }
  }

  Expression getDartExpressionForTableArrangementComponent(
      component,
      Map<String, String> dartProperties,
      Map<String, Expression?> defaultValues,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    // TODO: GridView isn't right (because scrollable), we need to use for-loops and create nested rows / columns
    Iterable children = component["\$Components"];
    int rows = children.isEmpty
        ? 0
        : children.map((e) => int.parse(e["Row"])).reduce(max) + 1;
    var childrenComponents = //TODO check constraints
        children
            .map((c) =>
                parseComponent(c, unconstrainedWidth, unconstrainedHeight))
            .whereNotNull();
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("GridView").newInstanceNamed("count", [], {
              "crossAxisCount": literalNum(rows),
              "children": literalList(childrenComponents),
              "shrinkWrap": ltrue,
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Expression getDartExpressionForScrollArrangementComponent(
      component,
      Map<String, String> dartProperties,
      Map<String, Expression?> defaultValues,
      String type,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    Iterable children = component["\$Components"];
    var childrenComponents = //TODO check constraints
        children
            .map((c) =>
                parseComponent(c, unconstrainedWidth, unconstrainedHeight))
            .whereNotNull();
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("ListView").newInstance([], {
              "scrollDirection": r("Axis." +
                  (type.contains("Horizontal") ? "horizontal" : "vertical")),
              "shrinkWrap": ltrue,
              "children": literalList(childrenComponents)
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Expression getDartExpressionForVerticalArrangementComponent(
      component,
      Map<String, String> dartProperties,
      Map<String, Expression?> defaultValues,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    Iterable children = component["\$Components"] ?? [];
    var childrenComponents = children
        .map((c) => parseComponent(c, unconstrainedWidth, true))
        .whereNotNull();
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        // r("Flexible")([], {
        //"child":
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            //TODO IntrinsicWidth/-Height are relatively expensive;
            // possible optimization: only use them if we have any child that may
            // have a width(/height) of fill_parent when we have don't have a fixed size
            r("IntrinsicWidth")([], {
              "child": r("Column").newInstance([], {
                "mainAxisAlignment": r("numToMainAxisAlignment")([
                  getDartExpressionForProperty(
                      dartProperties,
                      "AlignVertical",
                      getComponentNumProperty(component, "AlignVertical"),
                      defaultValues)
                ]),
                "crossAxisAlignment": r("numToCrossAxisAlignment")([
                  getDartExpressionForProperty(
                      dartProperties,
                      "AlignHorizontal",
                      getComponentNumProperty(component, "AlignHorizontal"),
                      defaultValues)
                ]),
                "children": literalList(childrenComponents)
              }),
            }),
            unconstrainedWidth,
            unconstrainedHeight)

        //})
        );
  }

  Expression getDartExpressionForHorizontalArrangementComponent(
      component,
      Map<String, String> dartProperties,
      Map<String, Expression?> defaultValues,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    Iterable children = component["\$Components"] ?? [];
    var childrenComponents = children
        .map((c) => parseComponent(c, true, unconstrainedHeight))
        .whereNotNull();
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        //r("Flexible")([], {
        //  "child":
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("IntrinsicHeight")([], {
              "child": r("Row").newInstance([], {
                "mainAxisAlignment": r("numToMainAxisAlignment")([
                  getDartExpressionForProperty(
                      dartProperties,
                      "AlignHorizontal",
                      getComponentNumProperty(component, "AlignHorizontal"),
                      defaultValues)
                ]),
                "crossAxisAlignment": r("numToCrossAxisAlignment")([
                  getDartExpressionForProperty(
                      dartProperties,
                      "AlignVertical",
                      getComponentNumProperty(component, "AlignVertical"),
                      defaultValues)
                ]),
                "children": literalList(childrenComponents)
              }),
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

// Helpers for parseComponent
  Map<String, String> getDartPropertiesForComponent(
      String type, String componentName) {
    if (properties[type] == null) {
      return {};
    } else {
      return {
        for (var prop in properties[type]!.keys)
          prop: getPropertyDartName(componentName, prop)
      };
    }
  }

  Expression maybeVisible(
    dartProperties,
    component,
    defaultValues,
    Expression ex,
  ) {
    return optimizedConditional(
        getDartExpressionForProperty(dartProperties, "Visible",
            getComponentBoolProperty(component, "Visible"), defaultValues),
        ex,
        r("Container").newInstance([]));
  }

// Specific components
  InvokeExpression getDartExpressionForTextComponent(
      String materialPackage,
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues) {
    return InvokeExpression.newOf(r("Text", materialPackage), [
      getDartExpressionForProperty(dartProperties, "Text",
          getComponentStringProperty(component, "Text"), defaultValues)
    ], {
      "textAlign": optimizedConditional(
          optimizedLiteralEqual(
              getDartExpressionForProperty(
                  dartProperties,
                  "TextAlignment",
                  getComponentNumProperty(component, "TextAlignment"),
                  defaultValues),
              literalNum(0)),
          r("TextAlign.left"),
          optimizedConditional(
              optimizedLiteralEqual(
                  getDartExpressionForProperty(
                      dartProperties,
                      "TextAlignment",
                      getComponentNumProperty(component, "TextAlignment"),
                      defaultValues),
                  literalNum(1)),
              r("TextAlign.center"),
              r("TextAlign.right"))),
      "style": InvokeExpression.newOf(r("TextStyle", materialPackage), [], {
        "color": getDartExpressionForProperty(
            dartProperties,
            "TextColor",
            component["TextColor"] != null
                ? getComponentColorProperty(component, "TextColor")
                : null,
            defaultValues),
        "backgroundColor": getDartExpressionForProperty(
            dartProperties,
            "BackgroundColor",
            getComponentColorProperty(component, "BackgroundColor"),
            defaultValues),
        "fontWeight": getDartExpressionForProperty(
            dartProperties,
            "FontBold",
            component["FontBold"] == "True" ? r("FontWeight.bold") : null,
            defaultValues),
        "fontStyle": getDartExpressionForProperty(
            dartProperties,
            "FontItalic",
            component["FontItalic"] == "True" ? r("FontStyle.italic") : null,
            defaultValues),
        "fontSize": getDartExpressionForProperty(dartProperties, "FontSize",
            getComponentNumProperty(component, "FontSize"), defaultValues),
      }),
    });
  }

  Expression getDartExpressionForButton(
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      Map<String, Expression?> eventHandlers,
      bool unconstrainedWidth,
      bool unconstrainedHeight,
      {bool disableLongPress = false}) {
    var hasImage = getComponentStringProperty(component, "Image") != null;
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            InvokeExpression.newOf(r("ElevatedButton", materialPackage), [], {
              "onPressed": getDartExpressionForEnablableListener(
                dartProperties,
                component,
                defaultValues,
                //no-op because flutter would disable the button if this was null
                eventHandlers["Click"] ?? getNoOpMethodExpression(),
              ),
              "onLongPress": disableLongPress
                  ? literalNull
                  : (eventHandlers["LongClick"] ?? getNoOpMethodExpression()),
              "child": hasImage
                  ? getImageDartExpression(
                      dartProperties,
                      component,
                      defaultValues,
                      unconstrainedWidth,
                      unconstrainedHeight,
                      true)
                  : getDartExpressionForTextComponent(materialPackage,
                      dartProperties, component, defaultValues),
              "style": r("ElevatedButton.styleFrom", materialPackage)([], {
                if (hasImage) "padding": r("EdgeInsets.all")([literalNum(0)]),
                "shape": component["Shape"] ==
                        "1" // Designer only property, can't change at runtime
                    ? //1 is Rounded
                    r("RoundedRectangleBorder").newInstance([], {
                        "borderRadius": r("BorderRadius")
                            .newInstanceNamed("circular", [literalNum(30)])
                      })
                    : literalNull,
                "primary": getDartExpressionForProperty(
                    dartProperties,
                    "BackgroundColor",
                    getComponentColorProperty(component, "BackgroundColor"),
                    {dartProperties["BackgroundColor"]!: r("Colors.grey")}),
              }),
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Expression getTextfieldDartExpression(
      String componentName,
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      bool unconstrainedWidth,
      bool unconstrainedHeight,
      {bool obscureText = false}) {
    state.fields[componentName + "_Controller"] =
        r("TextEditingController").newInstance([]);
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("TextField").newInstance([], {
              "controller": r(componentName + "_Controller"),
              "style":
                  InvokeExpression.newOf(r("TextStyle", materialPackage), [], {
                "color": getDartExpressionForProperty(
                    dartProperties,
                    "TextColor",
                    getComponentColorProperty(component, "TextColor"),
                    defaultValues),
                "backgroundColor": getDartExpressionForProperty(
                    dartProperties,
                    "BackgroundColor",
                    getComponentColorProperty(component, "BackgroundColor"),
                    defaultValues),
                "fontWeight": getDartExpressionForProperty(
                    dartProperties,
                    "FontBold",
                    component["FontBold"] == "True"
                        ? r("FontWeight.bold")
                        : null,
                    defaultValues),
                "fontStyle": getDartExpressionForProperty(
                    dartProperties,
                    "FontItalic",
                    component["FontItalic"] == "True"
                        ? r("FontStyle.italic")
                        : null,
                    defaultValues),
                "fontSize": getDartExpressionForProperty(
                    dartProperties,
                    "FontSize",
                    getComponentNumProperty(component, "FontSize"),
                    defaultValues),
              }),
              "decoration": r("InputDecoration").newInstance([], {
                "hintText": getDartExpressionForProperty(
                    dartProperties,
                    "Hint",
                    getComponentStringProperty(component, "Hint"),
                    defaultValues)
              }),
              "keyboardType": optimizedConditional(
                  getDartExpressionForProperty(
                      dartProperties,
                      "NumbersOnly",
                      getComponentBoolProperty(component, "NumbersOnly"),
                      defaultValues),
                  r("TextInputType.number"),
                  r("TextInputType.text")),
              "maxLines": optimizedConditional(
                  getDartExpressionForProperty(
                      dartProperties,
                      "MultiLine",
                      getComponentBoolProperty(component, "MultiLine"),
                      defaultValues),
                  literalNull,
                  literalNum(1)), // null for unlimited lines, 1 otherwise
              "readOnly": getDartExpressionForProperty(
                  dartProperties,
                  "ReadOnly",
                  getComponentBoolProperty(component, "ReadOnly"),
                  defaultValues),
              if (obscureText) "obscureText": ltrue,
            }),
            unconstrainedWidth,
            unconstrainedHeight,
            expandForAutomatic: true));
  }

  Expression getSpinnerDartExpression(
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      Map<String, Expression?> eventHandlers,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    state.fields[dartProperties["Elements"]!] = getDartExpressionForProperty(
        dartProperties,
        "Elements",
        component["ElementsFromString"] == null
            ? null
            : literalList(
                component["ElementsFromString"].toString().split(",")),
        defaultValues);
    state.fields[dartProperties["Selection"]!] = getDartExpressionForProperty(
        dartProperties,
        "Selection",
        getComponentStringProperty(component, "Selection"),
        defaultValues);
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("DropdownButton").newInstance([], {
              "value": r(dartProperties["Selection"]!),
              "onChanged": Method((b) => b
                ..requiredParameters.add(Parameter((c) => c
                  ..name = "newValue"
                  ..type = r("String")))
                ..body = Block.of([
                  r("setState")([
                    Method((d) => d
                      ..body = r(dartProperties["Selection"]!)
                          .assign(r("newValue"))
                          .statement).closure
                  ]).statement,
                  // Update our checked-variable

                  safeCallEventHandler(
                      eventHandlers["AfterSelecting"], [r("newValue")])
                ])).closure,
              "items": r(dartProperties["Elements"]!)
                  .property("map")([
                    Method((m) => m
                      ..requiredParameters.add(Parameter((p) => p
                        ..name = "value"
                        ..type = r("String")))
                      ..body = r("DropdownMenuItem")
                          .newInstance([], {
                            "value": r("value"),
                            "child": r("Text").newInstance([r("value")])
                          })
                          .returned
                          .statement).closure
                  ])
                  .property("toList")([])
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Expression getSliderDartExpression(
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      Map<String, Expression?> eventHandlers,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    state.fields[dartProperties["ThumbPosition"]!] =
        getDartExpressionForProperty(dartProperties, "ThumbPosition",
            getComponentNumProperty(component, "ThumbPosition"), defaultValues);
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("Slider").newInstance([], {
              "min": getDartExpressionForProperty(
                  dartProperties,
                  "MinValue",
                  getComponentNumProperty(component, "MinValue"),
                  defaultValues),
              "max": getDartExpressionForProperty(
                  dartProperties,
                  "MaxValue",
                  getComponentNumProperty(component, "MixValue"),
                  defaultValues),
              "value": getDartExpressionForProperty(
                      dartProperties,
                      "ThumbPosition",
                      getComponentNumProperty(component, "ThumbPosition"),
                      defaultValues)
                  .asA(r("double")),
              "onChanged": Method((b) => b
                ..requiredParameters.add(Parameter((c) => c
                  ..name = "newValue"
                  ..type = r("double")))
                ..body = Block.of([
                  r("setState")([
                    Method((d) => d
                      ..body = r(dartProperties["ThumbPosition"]!)
                          .assign(r("newValue"))
                          .statement).closure
                  ]).statement,
                  safeCallEventHandler(
                      eventHandlers["PositionChanged"], [r("newValue")])
                ])).closure
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Expression getSwitchOrCheckboxDartExpression(
      Map<String, String> dartProperties,
      String type,
      Map<String, Expression?> defaultValues,
      component,
      Map<String, Expression?> eventHandlers,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    //Force the property to be a variable (otherwise it would be a hardcoded literal value if not referenced in blocks),
    //but this is a special case, because we need it to be a variable to control UI output
    // (Also see similar comment above or at ParsingState.fields)
    state.fields[dartProperties["Checked"]!] = lfalse;

    var children = [
      r(type == "Switch" ? "Switch" : "Checkbox").newInstance([], {
        "value": getDartExpressionForProperty(
            dartProperties, "Checked", lfalse, defaultValues),
        "onChanged": getDartExpressionForEnablableListener(
            dartProperties,
            component,
            defaultValues,
            Method((b) => b
              ..requiredParameters.add(Parameter((c) => c
                ..name = "newValue"
                ..type = r("bool")))
              ..body = Block.of([
                r("setState")([
                  Method((d) => d
                    ..body = r(dartProperties["Checked"]!)
                        .assign(r(dartProperties["Checked"]!).negate())
                        .statement).closure
                ]).statement,
                // Update our checked-variable
                safeCallEventHandler(eventHandlers["Changed"]),
                // Call the event handler, may be no-op
              ])).closure)
      }),
      getDartExpressionForTextComponent(
          materialPackage, dartProperties, component, defaultValues)
    ];
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            InvokeExpression.newOf(r("Row"), [], {
              "mainAxisSize": r("MainAxisSize.min"),
              "children":
                  //Switch and Checkbox have the text on different sides
                  literalList(type == "Switch" ? children.reversed : children),
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Expression getImageDartExpression(
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      bool unconstrainedWidth,
      bool unconstrainedHeight,
      [useImage = false]) {
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("Image").newInstance([], {
              "fit": r("BoxFit.contain"),
              "image": optimizedConditional(
                  getDartExpressionForProperty(
                          dartProperties,
                          useImage ? "Image" : "Picture",
                          getComponentStringProperty(
                              component, useImage ? "Image" : "Picture"),
                          defaultValues)
                      .property("startsWith")([
                    r("RegExp").newInstance(
                        [literalString("https?:\\/\\/", raw: true)])
                  ]),
                  r("NetworkImage").newInstance([
                    getDartExpressionForProperty(
                        dartProperties,
                        useImage ? "Image" : "Picture",
                        getComponentStringProperty(
                            component, useImage ? "Image" : "Picture"),
                        defaultValues)
                  ]),
                  r("AssetImage").newInstance([
                    literalString("assets/").operatorAdd(
                        getDartExpressionForProperty(
                            dartProperties,
                            useImage ? "Image" : "Picture",
                            getComponentStringProperty(
                                component, useImage ? "Image" : "Picture"),
                            // outdated: Prefix path from scm with "//", because
                            // filenames from scm always refer to assets, but miss the //
                            // handleFilePath(literalString("//").operatorAdd(
                            //     getComponentStringProperty(
                            //         component, "Picture"))),
                            defaultValues))
                  ]))
            }),
            unconstrainedWidth,
            unconstrainedHeight,
            expandForAutomatic: true));
  }

  Expression getListViewDartExpression(
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      bool unconstrainedWidth,
      bool unconstrainedHeight) {
    state.fields[dartProperties["Elements"]!] = getDartExpressionForProperty(
        dartProperties,
        "Elements",
        component["ElementsFromString"] == null
            ? null
            : literalList(
                component["ElementsFromString"].toString().split(",")),
        defaultValues);
    state.fields[dartProperties["Selection"]!] = getDartExpressionForProperty(
        dartProperties,
        "Selection",
        getComponentStringProperty(component, "Selection"),
        defaultValues);
    return maybeVisible(
        dartProperties,
        component,
        defaultValues,
        getSizedComponentDartExpression(
            dartProperties,
            component,
            defaultValues,
            r("ListView").newInstanceNamed("separated", [], {
              "shrinkWrap": ltrue,
              "itemCount": r(dartProperties["Elements"]!).property("length"),
              "itemBuilder": Method((m) => m
                ..lambda = true
                ..requiredParameters.add(Parameter((p) => p..name = "_"))
                ..requiredParameters.add(Parameter((p) => p
                  ..name = "i"
                  ..type = r("int")))
                ..body = r("ListTile").newInstance([], {
                  "title": r("Text").newInstance([
                    r(dartProperties["Elements"]!)
                        .property("elementAt")([r("i")])
                  ])
                }).code).closure,
              "separatorBuilder": Method((m) => m
                ..lambda = true
                ..requiredParameters.add(Parameter((p) => p..name = "_1"))
                ..requiredParameters.add(Parameter((p) => p..name = "_2"))
                ..body = r("Divider").newInstance([]).code).closure,
            }),
            unconstrainedWidth,
            unconstrainedHeight));
  }

  Method getDatePickerLaunchMethod(String componentName) {
    return Method((b) => b
      ..name = componentName + "_launchPicker"
      ..requiredParameters.add(Parameter((p) => p
        ..name = "context"
        ..type = r("BuildContext")))
      ..body = r("showDatePicker")([], {
        "context": r("context"),
        "initialDate": r(componentName + "_Date"),
        "firstDate": r("DateTime.fromMillisecondsSinceEpoch")([literalNum(0)]),
        "lastDate": r("DateTime").newInstanceNamed(
            "utc", [literalNum(2100), literalNum(1), literalNum(1)])
      })
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p
                ..name = "value"
                ..type = r("DateTime")))
              ..body = Block.of([
                // Prevent exception if picking was canceled
                const Code("if(value==null){return;}"),
                r(componentName + "_Date").assign(r("value")).statement,
                safeCallEventHandler(
                    getDartEventHandler(state, componentName, "AfterDateSet"))
              ])).closure
          ])
          .statement);
  }

  Method getTimePickerLaunchMethod(String componentName) {
    return Method((b) => b
      ..name = componentName + "_launchPicker"
      ..requiredParameters.add(Parameter((p) => p
        ..name = "context"
        ..type = r("BuildContext")))
      ..body = r("showTimePicker")([], {
        "context": r("context"),
        "initialTime": r(componentName + "_Time"),
      })
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p
                ..name = "value"
                ..type = r("TimeOfDay")))
              ..body = Block.of([
                // Prevent exception if picking was canceled
                const Code("if(value==null){return;}"),
                r(componentName + "_Time").assign(r("value")).statement,
                safeCallEventHandler(
                    getDartEventHandler(state, componentName, "AfterTimeSet"))
              ])).closure,
          ])
          .statement);
  }

  Method getImagePickerLaunchMethod(String componentName) {
    return Method((b) => b
      ..name = componentName + "_Open"
      ..requiredParameters.add(Parameter((p) => p
        ..name = "context"
        ..type = r("BuildContext")))
      ..body = r("ImagePicker", imagePickerPackage)
          .newInstance([])
          .property("pickImage")([], {"source": r("ImageSource.gallery")})
          .property("then")([
            Method((b) => b
              ..requiredParameters.add(Parameter((p) => p
                ..name = "value"
                ..type = r("XFile")))
              ..body = Block.of([
                r(componentName + "_Selection")
                    .assign(r("value.path"))
                    .statement,
                safeCallEventHandler(
                    getDartEventHandler(state, componentName, "AfterPicking"))
              ])).closure
          ])
          .statement);
  }

  /// Creates a dart expression that wraps a component in a SizedBox, with
  /// width and height set accordingly.
  Expression getSizedComponentDartExpression(
      Map<String, String> dartProperties,
      dynamic component,
      Map<String, dynamic> defaultValues,
      Expression child,
      bool unconstrainedWidth,
      bool unconstrainedHeight,
      {expandForAutomatic = false}) {
    Expression width = getDartExpressionForProperty(dartProperties, "Width",
        getComponentNumProperty(component, "Width"), defaultValues);
    Expression height = getDartExpressionForProperty(dartProperties, "Height",
        getComponentNumProperty(component, "Height"), defaultValues);
    // -1: automatic, -2: fill parent (confirmed here: https://community.appinventor.mit.edu/t/how-to-set-width-of-horizontal-and-vertical-layouts-to-fill-parent-via-blocks/14514/2)

    // Logic: width == -2 ? double.infinity : (width == -1) ? null : width)
    // for fill parent: infinite size; for automatic: null size; else: user-specified size

    var sizedBox = r("SizedBox")([], {
      "child": child,
      //Possible optimization: leave out the property if it would be null
      "width": optimizedConditional(
          optimizedLiteralEqual(width, literalNum(-2)),
          r("double.infinity"),
          optimizedConditional(optimizedLiteralEqual(width, literalNum(-1)),
              literalNull, width)),
      "height": optimizedConditional(
          optimizedLiteralEqual(height, literalNum(-2)),
          r("double.infinity"),
          optimizedConditional(optimizedLiteralEqual(height, literalNum(-1)),
              literalNull, height))
    });

    if (unconstrainedWidth) {
      if (expandForAutomatic &&
          width is LiteralExpression &&
          (width.literal == "-2" || width.literal == "-1")) {
        return r("Expanded")([], {
          "child": sizedBox,
        });
      }
    }

    if (unconstrainedHeight) {
      if (expandForAutomatic &&
          height is LiteralExpression &&
          (height.literal == "-2" || height.literal == "-1")) {
        return r("Expanded")([], {
          "child": sizedBox,
        });
      }
    }

    return
        // optimizedConditional(
        //   optimizedLiteralEqual(width, literalNum(-2)),
        //.or(optimizedLiteralEqual(height, literalNum(-2))),
        r("SizedBox")([], {
      "child": child,
      //Possible optimization: leave out the property if it would be null
      "width": optimizedConditional(
          optimizedLiteralEqual(width, literalNum(-2)),
          unconstrainedWidth ? literalNull : r("double.infinity"),
          optimizedConditional(optimizedLiteralEqual(width, literalNum(-1)),
              literalNull, width)),
      "height": optimizedConditional(
          optimizedLiteralEqual(height, literalNum(-2)),
          unconstrainedHeight ? literalNull : r("double.infinity"),
          optimizedConditional(optimizedLiteralEqual(height, literalNum(-1)),
              literalNull, height))
    })
        //,sizedBox)
        ;
    // } else {
    //   return sizedBox;
    // }
  }

  // Helpers for getting properties
  Expression? getComponentStringProperty(component, String prop) {
    return component[prop] != null ? literalString(component[prop]) : null;
  }

  Expression? getComponentBoolProperty(component, String prop) {
    return component[prop] == "True"
        ? ltrue
        : (component[prop] == "False" ? lfalse : null);
  }

  Expression? getComponentColorProperty(component, String prop) {
    //quite the hack with CodeExpression (see other use)
    return component[prop] != null
        ? InvokeExpression.newOf(r("Color"),
            [CodeExpression(Code("0xFF" + component[prop].substring(2)))])
        : null;
  }

  Expression? getComponentNumProperty(component, String prop) {
    return component[prop] != null
        ? literalNum(num.parse(component[prop]))
        : null;
  }

  // Wrapper for components
  /// Used when: a component can be disabled in AI ("Enabled"-property), and to disable
  /// it is necessary to pass null to a flutter event handler property
  /// This returns either just the regular event listener (if the component is always enabled)
  /// or a conditional. pseudo-code: Enabled-property ?  event listener : null
  Expression getDartExpressionForEnablableListener(
      Map<String, String> dartProperties,
      component,
      Map<String, Expression?> defaultValues,
      Expression eventHandler) {
    return state.fields.containsKey(dartProperties["Enabled"])
        ? getDartExpressionForProperty(dartProperties, "Enabled",
                getComponentBoolProperty(component, "Enabled"), defaultValues)
            .conditional(eventHandler, literalNull)
        : eventHandler;
  }

  Map<String, Expression?> getDefaultValuesForComponent(
      String type, String componentName) {
    if (properties[type] == null) {
      return {};
    } else {
      return {
        for (var prop in properties[type]!.keys)
          getPropertyDartName(componentName, prop): properties[type]![prop]
      };
    }
  }

  /// Returns a map from all event names defined for a component's type
  /// to either
  ///
  /// a) a Reference to the corresponding dart method, if the user has defined
  /// an event handler for this event
  ///
  /// or b) null if the user hasn't defined an event handler for this event.
  Map<String, Expression?> getDartEventHandlers(
      List<Event> componentEvents, String componentName) {
    return {
      for (var event in componentEvents)
        event.name: getDartEventHandler(state, componentName, event.name)
    };
  }

  /// If a property is never read or written in the blocks, this returns the
  /// properties constant value (set by the user in SCM, or if not set by the
  /// user AI's default value for this property).
  /// If the property is ever read or written in the blocks, this returns a
  /// Reference to the corresponding dart variable for this property AND
  /// sets the correct initial value for this dart variable.
  /// NB: This has side effects (see above)! It may be useful to call this method
  /// even if its result isn't needed.
  Expression getDartExpressionForProperty(Map<String, String> dartProperties,
      String property, dynamic scmValue, Map<String, dynamic> defaultValues) {
    // the name of the dart variable we use for this property (like "Button1_Text")
    var propertyDartName = dartProperties[property]!;
    // scmValue: The value specified in the scm file for this property (null if default,
    // because AI will just leave out any properties with default values)
    // Taking into account the default values
    var fallbackValue = scmValue ?? defaultValues[propertyDartName]!;

    final result = state.fields.containsKey(propertyDartName)
        ? r(propertyDartName)
        : fallbackValue;

    if (state.fields.containsKey(propertyDartName)) {
      state.fields[propertyDartName] = fallbackValue;
    }

    return result;
  }

  Expression getNoOpMethodExpression() {
    return Method((b) => b
      ..lambda = false
      ..body = Block.of([])).closure;
  }
}
