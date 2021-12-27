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
import 'package:xaif/compiler/util_parser.dart';

/// Contains constant data on AI-components' different properties and events

Map<String, Expression> get labelProperties => {
      "Text": literalString(""),
      "FontBold": refer("FontWeight.normal"),
      "FontItalic": refer("FontStyle.normal"),
      "TextColor": refer("Colors.black"),
      "FontSize": literalNum(14),
      "BackgroundColor": refer("Colors.transparent"),
      "TextAlignment": literalNum(1),
      ...visibleProperties
    };

Map<String, Expression> get visibleProperties => {
      "Visible": literalTrue,
    };

Map<String, Expression> get sizeProperties => {
      "Width": SIZE_AUTOMATIC,
      "Height": SIZE_AUTOMATIC,
    };

Map<String, Expression> get buttonProperties => {
      "BackgroundColor": refer("Colors.grey"),
      "Image": refer(""),
    };

Map<String, Map<String, Expression>> properties = {
  "Button": {
    "Enabled": literalTrue,
    ...labelProperties,
    ...sizeProperties,
    ...buttonProperties,
  },
  "CheckBox": {
    "Checked": literalFalse,
    "Enabled": literalTrue,
    ...labelProperties,
    ...sizeProperties,
  },
  "Switch": {
    "Checked": literalFalse,
    "Enabled": literalTrue,
    ...labelProperties,
    ...sizeProperties,
  },
  "Label": labelProperties..addAll(sizeProperties),
  "TextBox": {
    "Hint": literalString(""),
    "MultiLine": literalFalse,
    "NumbersOnly": literalFalse,
    "ReadOnly": literalFalse,
    ...labelProperties,
    ...sizeProperties,
  },
  "PasswordTextBox": {
    "Hint": literalString(""),
    "MultiLine": literalFalse,
    "NumbersOnly": literalFalse,
    "ReadOnly": literalFalse,
    ...labelProperties,
    ...sizeProperties,
  },
  "Image": {
    "Picture": literalString(""),
    ...visibleProperties,
    ...sizeProperties,
  },
  "ImagePicker": {
    "Selection": literalString(""),
    ...labelProperties,
    ...sizeProperties,
  }..addAll(buttonProperties),
  "HorizontalArrangement": {
    ...visibleProperties,
    "AlignVertical": literalNum(1),
    "AlignHorizontal": literalNum(1),
    ...sizeProperties,
  },
  "VerticalArrangement": {
    ...visibleProperties,
    "AlignHorizontal": literalNum(1),
    "AlignVertical": literalNum(1),
    ...sizeProperties,
  },
  "VerticalScrollArrangement": visibleProperties..addAll(sizeProperties),
  "HorizontalScrollArrangement": visibleProperties..addAll(sizeProperties),
  "TableArrangement": visibleProperties..addAll(sizeProperties),
  "DatePicker": {
    "Enabled": literalTrue,
    "Date": refer("DateTime").newInstanceNamed("now", []),
    ...labelProperties,
    ...sizeProperties,
  }..addAll(buttonProperties),
  "TimePicker": {
    "Enabled": literalTrue,
    "Time": refer("DateTime").newInstanceNamed("now", []),
    ...labelProperties,
    ...sizeProperties,
  }..addAll(buttonProperties),
  "Slider": {
    "MinValue": literalNum(10.0),
    "MaxValue": literalNum(50.0),
    "ThumbPosition": literalNum(30.0).asA(refer("double")),
    ...visibleProperties,
    ...sizeProperties,
  },
  "Spinner": {
    "Elements": literalList(<String>[]),
    "Selection": literalString(""),
    ...visibleProperties,
    ...sizeProperties,
  },
  "ListView": {
    "Elements": literalList(<String>[]),
    "Selection": literalString(""),
    ...visibleProperties,
    ...sizeProperties,
  },
  "Player": {
    "IsPlaying": lfalse,
    "Loop": lfalse,
    "Source": literalString(""),
    "Volume": literalNum(50),
  },
  "PhoneCall": {"PhoneNumber": literalString("")},
  "Texting": {
    "PhoneNumber": literalString(""),
    "Message": literalString(""),
  },
  "TinyWebDB": {
    "ServiceUrl": literalString("http://tinywebdb.appinventor.mit.edu")
  },
  "Web": {
    "Url": literalString(""),
  },
};

Map<String, List<Event>> events = {
  "Button": [Event("Click"), Event("LongClick")],
  "CheckBox": [Event("Changed")],
  "Switch": [Event("Changed")],
  "TextBox": [Event("Changed")],
  "Notifier": [
    Event("AfterTextInput", {"response": refer("String")}),
    Event("AfterChoosing", {"choice": refer("String")})
  ],
  "Slider": [
    Event("PositionChanged", {"thumbPosition": refer("num")}),
  ],
  "Spinner": [
    Event("AfterSelecting", {"selection": refer("String")}),
  ],
  "ListView": [
    Event("AfterPicking"),
  ],
  "Player": [
    Event("Completed"),
  ],
  "File": [
    Event("AfterFileSaved", {"fileName": refer("String")}),
    Event("GotText", {"text": refer("String")}),
  ],
  "Camera": [
    Event("AfterPicture", {"image": refer("String")}),
  ],
  "Camcorder": [
    Event("AfterRecording", {"clip": refer("String")}),
  ],
  "TinyWebDB": [
    Event("ValueStored"),
    Event("GotValue",
        {"tagFromWebDB": refer("String"), "valueFromWebDB": refer("dynamic")}),
  ],
  "Web": [
    Event("GotFile", {
      "url": r("String"),
      "responseCode": r("double"),
      "responseType": r("String"),
      "fileName": r("String")
    }),
    Event("GotText", {
      "url": r("String"),
      "responseCode": r("int"),
      "responseType": r("String"),
      "responseContent": r("String")
    }),
    Event("TimedOut", {
      "url": r("String"),
    }),
  ],

  // Not yet implemented:
  "BarcodeScanner": [
    Event("AfterScan", {"result": refer("String")})
  ],
};

class Event {
  String name;
  Map<String, Reference> arguments = {};

  Event(this.name, [this.arguments = const {}]);
}

//ignore: non_constant_identifier_names
final SIZE_FILL_PARENT = literalNum(-2);
//ignore: non_constant_identifier_names
final SIZE_AUTOMATIC = literalNum(-1);
