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

import 'parsing_state.dart';

/// Contains utility methods and constants needed by different classes related to
/// parsing/transpiling

//Shortcuts
const Reference Function(String symbol, [String? url]) r = refer;
const ltrue = literalTrue;
const lfalse = literalFalse;

//Packages
const materialPackage = "package:flutter/material.dart";
const mathPackage = "dart:math";
const convertPackage = "dart:convert";

// packages supported by Dart/Flutter team
const httpPackage = "package:http/http.dart";
const xfilePackage = "package:cross_file/cross_file.dart";
const sharedPrefsPackage = "package:shared_preferences/shared_preferences.dart";
const urlLauncherPackage = "package:url_launcher/url_launcher.dart";
const imagePickerPackage = "package:image_picker/image_picker.dart";

//Third party packages
// WHEN USING NEW PACKAGE: add to template; check license etc. const justAudioPackage = "package:just_audio/just_audio.dart";
const sharePlusPackage = "package:share_plus/share_plus.dart";

/// An optimized version of conditional() that returns just whenTrue or whenFalse, if condition
/// is ltrue or lfalse (that means, the condition always has a constant value and can
/// never change at runtime). Otherwise it returns a regular conditional, i.e. <condition> ? whenTrue : whenFalse
Expression optimizedConditional(
    Expression condition, Expression whenTrue, Expression whenFalse) {
  if (condition == ltrue) {
    return whenTrue;
  } else if (condition == lfalse) {
    return whenFalse;
  } else {
    return condition.conditional(whenTrue, whenFalse);
  }
}

/// An optimized version of Expression.equalTo(), which returns just literalTrue/literalFalse if a and b are both literals.
/// Otherwise it returns `a.equalTo(b)`
/// NB: This only works if the literal values are exactly equal,
/// e.g. this would return false for 10 and 10.0
Expression optimizedLiteralEqual(Expression a, Expression b) {
  if (a is LiteralExpression && b is LiteralExpression) {
    return literalBool(a.literal == b.literal);
  } else {
    return a.equalTo(b);
  }
}

/// The dart name of an AI variable
String getVarName(String originalName) {
  return "var_$originalName";
}

/// The dart name of an AI method
String getMethodName(String originalName) {
  return "method_$originalName";
}

/// Safely invoke an event handler. If the handler is null (because the user
/// doesn't want to handle the event),
/// an empty code is returned, otherwise the handler is invoked (optionally with
/// arguments)
Code safeCallEventHandler(Expression? eventHandler,
    [List<Expression> args = const []]) {
  return eventHandler?.call(args).statement ?? const Code("");
}

/// eventName without "on"
/// null means that the user does not want to handle the event
/// it is often useful to invoke the result of this method with
/// safeCallEventHandler
Expression? getDartEventHandler(
    ParsingState state, String componentName, String eventName) {
  if (state.methods[componentName] != null &&
      state.methods[componentName]![eventName] != null) {
    return r(state.methods[componentName]![eventName]!.name!);
  } else {
    return null; //getNoOpMethodExpression();
  }
}

/// Turns e.g. `print("hi")` into `()=>print("hi")`
/// Useful because e.g. Button(onPressed: print("hi")) is invalid,
/// but Button(onPressed: ()=>print("hi")) is valid Dart code
Expression wrapCodeWithEmptyLambda(Expression code) {
  return Method((m) => m
    ..lambda = true
    ..body = code.code).closure;
}
