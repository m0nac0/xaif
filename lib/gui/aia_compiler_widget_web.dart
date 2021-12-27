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
//ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../compiler/aia_to_dart_compiler.dart';

class AIAAccepter extends StatefulWidget {
  const AIAAccepter({Key? key}) : super(key: key);

  @override
  _AIAAccepterState createState() => _AIAAccepterState();
}

class _AIAAccepterState extends State<AIAAccepter> {
  // DropzoneViewController controller;
  String code = "Select a *.aia file to get started!";
  Widget iframeWidget = Container();
  int number = 0;

  bool hasConfirmed = false;

  @override
  void initState() {
    super.initState();
  }

  void reloadIFrame(String code) {
    if (kIsWeb) {
      IFrameElement _iframeElement = IFrameElement();
      _iframeElement.height = '800';
      _iframeElement.width = '800';
      _iframeElement.src = getIFrameSrc(code);
      _iframeElement.style.border = 'none';
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'iframeElement' + (number).toString(),
        (int viewId) => _iframeElement,
      );
      setState(() {
        iframeWidget = SizedBox(
          width: 850,
          height: 850,
          child: HtmlElementView(
            key: UniqueKey(),
            viewType: 'iframeElement' + number.toString(),
          ),
        );
        number++;
      });
    }
  }

  String getIFrameSrc(String code) {
    //ignore: prefer_adjacent_string_concatenation
    return "data:text/html;charset=utf-8," + //class="language-run-dartpad:theme-light:mode-flutter:width-800:height-800:run-true:split-1"
        r'''<html><head><script type="text/javascript" src="https://dartpad.dev/inject_embed.dart.js" defer></script></head><body><pre><code class="language-run-dartpad:theme-light:mode-flutter:width-800:height-800:run-true:split-1">
      ''' +
        //FIXME: linebreaks are getting lost, therefore we filter comments as a workaround
        //HtmlEscape(HtmlEscapeMode.element).convert(code.replaceAll("\n", "<br>")) +
        code
            .split("\n")
            .where((e) => !e.trim().startsWith("//"))
            .map((e) => const HtmlEscape(HtmlEscapeMode.element).convert(e))
            .fold("",
                (previousValue, element) => previousValue + "\n" + element) +
        '''</code></pre></body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    if (hasConfirmed) {
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 20,
                ),
                const Text(
                    "You are running xaif as a web app. This only supports a "
                    "limited subset of components and should only be used as a "
                    "quick demo. Please run xaif with `flutter run -d windows` or"
                    "`flutter run -d linux` to use all of its capabilities.\n"
                    "Important note: this demo will send the generated intermediate "
                    "Flutter code to dartpad.dev servers. It is recommended not to use this "
                    "with any sensitive data / projects."),
                Container(
                  height: 20,
                ),
                Container(
                    width: 400,
                    height: 400,
                    decoration:
                        BoxDecoration(border: Border.all(color: Colors.green)),
                    child: ElevatedButton(
                      child: const Text("Select AIA file"),
                      onPressed: () {
                        FilePicker.platform.pickFiles().then(
                          (value) async {
                            final archive = ZipDecoder()
                                .decodeBytes(value!.files.first.bytes!);
                            print(archive.files.map((e) => e.name).toList());
                            final scm = String.fromCharCodes(archive.files
                                .firstWhere(
                                    (element) => element.name.endsWith(".scm"))
                                .content);
                            final blockly = String.fromCharCodes(archive.files
                                .firstWhere(
                                    (element) => element.name.endsWith(".bky"))
                                .content);

                            setState(() {
                              code = AIAToDartCompiler()
                                  .toCode(blockly, scm)
                                  .dartCode;
                            });
                            reloadIFrame(code);
                          },
                        );
                      },
                    )),
                Container(height: 20),
                ElevatedButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  child: const Text("Copy Flutter code to clipboard"),
                ),
                Container(height: 20),
                const Text("Flutter code:"),
                Container(height: 20),
                Flexible(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Scrollbar(
                      isAlwaysShown: true,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          SelectableText(code),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          iframeWidget,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 20,
          ),
          const Text("You are running xaif as a web app. This only supports a "
              "limited subset of components and should only be used as a "
              "quick demo. Please run xaif with `flutter run -d windows` or"
              "`flutter run -d linux` to use all of its capabilities.\n"
              "Important note: this demo will send the generated intermediate "
              "Flutter code to dartpad.dev servers. It is recommended not to use this "
              "with any sensitive data / projects."),
          Container(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    reloadIFrame('''
    void main(){
      print('hello world');
    }''');
                    setState(() {
                      hasConfirmed = true;
                    });
                  },
                  child: const Text("OK"))
            ],
          )
        ],
      );
    }
  }
}
