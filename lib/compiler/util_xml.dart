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
import 'package:xml/xml.dart';

/// Contains utility methods related to walking the blockly XML files

int getXMLItemCount(XmlElement block) =>
    int.parse(block.getElement("mutation")!.getAttribute("items")!);

String findXMLChildOp(XmlElement block) =>
    findXMLChildByName(block, "OP", "field").innerText;

String getComponentType(XmlElement mutation) {
  return mutation.getAttribute("component_type")!;
}

String getInstanceName(XmlElement mutation) =>
    mutation.getAttribute("instance_name")!;

// XML HELPERS
XmlElement findXMLChildByName(XmlElement block, String name,
    [String elementTag = "value"]) {
  return block.findElements(elementTag).firstWhere((e) =>
      e.attributes.any(((p0) => p0.name.local == "name" && p0.value == name)));
}

XmlElement findBlockOfXMLChildByName(XmlElement block, String name,
    [String elementTag = "value"]) {
  return block
      .findElements(elementTag)
      .firstWhere((e) => e.attributes
          .any(((p0) => p0.name.local == "name" && p0.value == name)))
      .getElement("block")!;
}
