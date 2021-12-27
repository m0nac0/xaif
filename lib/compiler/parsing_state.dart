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

/// The (intermediate) state of parsing an AIA-file and transpiling it to
/// Dart.
class ParsingState {
  Map<String, Map<String, Method>> methods = {};
  List<Method> gettersSetters = [];
  String appName = "";
  String screenName = "";
  String aboutMessage = "";
  var usesSharedPreferences = false;
  bool usesSafeStringAddition = false;
  bool usesEnsureNum = false;

  // First all blocks are processed. We put an entry with value null for
  // all component-attribute-variables they need. E.g. if the user has a
  // PhoneCall1.MakePhoneCall block, that puts a <"PhoneCall1_PhoneNumber",null>
  // entry into fields. Therefore when parsing the components, we know that
  // we can't just ignore the PhoneNumber attribute, but that it's actually used.
  //
  // Usually, if a property is never used in AI blocks, we don't create
  // a variable in dart but instead insert it's constant value directly
  // in the component definition
  // (There are some exceptions where the code for parsing components enforces
  // the existence of a dart variable of a certain name by inserting it into this
  // map).
  Map<String, Expression?> fields = {"latestContext": literalNull};

  void addMethod(String instanceName, String eventName, Method method) {
    if (methods[instanceName] == null) {
      methods[instanceName] = {};
    }
    methods[instanceName]![eventName] = method;
  }

  /// See docs for fields
  void ensureFieldExists(String name) {
    fields.putIfAbsent(name, () => null);
  }
}
