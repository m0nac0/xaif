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
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../compiler/aia_to_dart_compiler.dart';

// TODO-List:
//  - let user pick project path (and enforce that its empty)
//  - Further: config file; listen to device changes
//  - Show an error dialog if a process exits with non-zero code

/// A desktop GUI for the AIA to Flutter project transpiler, with functionality
/// to view the generated Dart code and run/build the Flutter project
class AIAAccepter extends StatefulWidget {
  const AIAAccepter({Key? key}) : super(key: key);

  @override
  _AIAAccepterState createState() => _AIAAccepterState();
}

class _AIAAccepterState extends State<AIAAccepter> {
  static const dirPrefix = "xaif_project";
  static const snackbarDuration = Duration(seconds: 30);

  /// The intermediate flutter code
  String code = "";

  // Set e.g. to "powershell" to use powershell instead of cmd on windows
  final String? shell = null; // = "powershell";

  /// "working" directory where the flutter project is created
  Directory? dir;

  // Maps deviceIds/build targets to a corresponding shell process (if one
  // is running)
  var runningFlutterProcesses = <String, Process?>{};
  var buildingFlutterProcesses = <String, Process?>{};

  // Launching is only supported for Windows, so we don't need a list/map
  Process? launchBuiltExeProcess;

  // Whether the flutter project was already generated
  bool hasSource = false;
  bool hasWindowsExecutable = false;
  bool showFlutterSource = false;
  List<String> deviceIds = [];

  // Necessary to restart apps running on device "web-server"
  // (the only device for which we use the flutter daemon)
  int daemonCommandID = 0;
  String? runningFlutterWebAppId;

  // Some of these targets may not actually work, e.g. if a toolchain is missing
  static final buildTargets = [
    //BuildTarget.aar,
    BuildTarget.apk,
    BuildTarget.appbundle,
    BuildTarget.web,
    if (Platform.isWindows) BuildTarget.windows,
    if (Platform.isLinux) BuildTarget.linux,
  ];

  // The directory selected by the user to create the project directory in
  int selectedDir = 1;
  final dirPathSystemTemp = Directory.systemTemp.absolute.path;
  final dirPathAtExecutable = Platform.resolvedExecutable.substring(
          0, Platform.resolvedExecutable.lastIndexOf(Platform.pathSeparator)) +
      Platform.pathSeparator +
      "xaif_projects";

  @override
  void initState() {
    super.initState();
    updateAvailableDevices();
  }

  /// Update the list of available devices (according to `flutter devices`)
  void updateAvailableDevices() async {
    var result = await runWithOptionalShell(
        "flutter", //shell,
        [
          //"/c",
          //"flutter",
          "devices",
          "--machine",
          "--show-web-server-device",
        ],
        runInShell: true,
        shell: shell);
    List json = jsonDecode(result.stdout.toString());
    deviceIds =
        json.map((device) => device["id"] as String?).whereNotNull().toList();
  }

  @override
  Widget build(BuildContext context) {
    const spacer = SizedBox(height: 10);

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              if (dir == null)
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      spacer,
                      const Text(
                        "Create new project directory in: ",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      spacer,
                      RadioListTile<int>(
                        value: 0,
                        groupValue: selectedDir,
                        title: Text(dirPathSystemTemp),
                        onChanged: (value) {
                          setState(() {
                            selectedDir = value!;
                          });
                        },
                      ),
                      RadioListTile<int>(
                        value: 1,
                        groupValue: selectedDir,
                        title: Text(dirPathAtExecutable),
                        onChanged: (value) {
                          setState(() {
                            selectedDir = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              if (dir == null) const Divider(),
              spacer,
              SizedBox(
                  width: 400,
                  height: code.split("\n").length > 2 ? 50 : 200,
                  child: ElevatedButton(
                    child: Text(
                      "Select AIA file " + (dir != null ? "to update" : ""),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => pickAndHandleAIAFile(context),
                  )),
              spacer,
              if (dir != null)
                Column(
                  children: [
                    SelectableText(
                        "Intermediate (Flutter) code is in ${dir!.absolute.path}"),
                    spacer,
                    ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(primary: Colors.redAccent),
                        onPressed: () async {
                          if (dir!.absolute.path
                              .startsWith(Directory.systemTemp.absolute.path)) {
                            await dir!.delete(recursive: true);
                            exit(0);
                          }
                        },
                        child: Text("Delete ${dir!.absolute.path} and exit")),
                    spacer,
                    ElevatedButton(
                        onPressed: () => openInExplorer(dir!.absolute.path),
                        child: Text("Show ${dir!.absolute.path} in explorer")),
                  ],
                ),
              spacer,
              if (hasSource)
                ...deviceIds.map((id) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: runningFlutterProcesses[id] != null
                              ? null
                              : () => runFlutterApp(id),
                          child: Text("Run app on $id"),
                        ),
                        ElevatedButton(
                          onPressed: runningFlutterProcesses[id] == null
                              ? null
                              : () {
                                  runningFlutterProcesses[id]
                                      ?.stdin
                                      .writeln("q");
                                  runningFlutterProcesses[id]?.kill();
                                  setState(() {
                                    runningFlutterProcesses[id] = null;
                                  });
                                },
                          child: Text("Stop app on $id"),
                        ),
                      ],
                    )),
              spacer,
              if (hasSource)
                ...buildTargets.map((e) {
                  var target = e.id;
                  var description = e.description;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: buildingFlutterProcesses[target] == null
                            ? () => buildFlutterApp(e)
                            : null,
                        child: Text("Build app for $description"),
                      ),
                      ElevatedButton(
                        onPressed: buildingFlutterProcesses[target] == null
                            ? null
                            : () {
                                buildingFlutterProcesses[target]?.kill();
                                setState(() {
                                  buildingFlutterProcesses[target] = null;
                                });
                              },
                        child: Text("Stop build for $description"),
                      ),
                      if (target == "windows")
                        ElevatedButton(
                          onPressed: hasWindowsExecutable
                              ? () => launchBuiltFlutterWindowsApp(
                                  BuildTarget.windows)
                              : null,
                          child: Text("Launch built app for $description"),
                        ),
                    ],
                  );
                }),
              spacer,
              if (code.isNotEmpty && !hasSource)
                const Text(
                    "Generating intermediate (Flutter) code, this may take a short while"),
              spacer,
              if (code.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          showFlutterSource = !showFlutterSource;
                        });
                      },
                      child: Text((showFlutterSource ? 'Hide' : 'Show') +
                          " Flutter source code"),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: code)),
                      child: const Text("Copy (Flutter) source code"),
                    ),
                  ],
                ),
              spacer,
              if (showFlutterSource)
                Flexible(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Scrollbar(
                      isAlwaysShown: true,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          SelectableText(code.isEmpty
                              ? "Select an AIA file to launch the app and see the source code here!"
                              : code),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens a file picker for the user to pick an AIA file. Then it
  /// transpiles the app to a Flutter project.
  Future<void> pickAndHandleAIAFile(BuildContext context) async {
    FilePicker.platform.pickFiles(withData: true).then(
      (filePickerResult) async {
        var fileBytes = filePickerResult?.files.first.bytes;
        if (fileBytes == null) {
          return;
        }
        final archive = ZipDecoder().decodeBytes(fileBytes);
        print(archive.files.map((e) => e.name).toList());
        final scm = String.fromCharCodes(archive.files
            .firstWhere((element) => element.name.endsWith(".scm"))
            .content);
        final blockly = String.fromCharCodes(archive.files
            .firstWhere((element) => element.name.endsWith(".bky"))
            .content);

        var compilationResult = AIAToDartCompiler().toCode(blockly, scm);
        setState(() {
          code = compilationResult.dartCode;
        });
        ensureDirectory().then((directory) async {
          if (!hasSource) {
            await createSubdirectoryAndAssets(directory, archive);
          }
          await File(directory.absolute.path +
                  "${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart")
              .writeAsString(code, flush: true);
          await File(directory.absolute.path +
                  "${Platform.pathSeparator}pubspec.yaml")
              .writeAsString(compilationResult.pubspec, flush: true);

          if (!hasSource) {
            await runFlutterCreate(directory);
          }

          restartRunningApps(context);
        });
      },
    );
  }

  /// Ensures that the lib/ and assets/ directories exist, and copies assets
  /// from the AIA file to the assets directory.
  Future<void> createSubdirectoryAndAssets(
      Directory directory, Archive archive) async {
    await Directory(directory.absolute.path + "${Platform.pathSeparator}lib")
        .create();
    await Directory(directory.absolute.path + "${Platform.pathSeparator}assets")
        .create();
    archive.files
        .where((file) => file.isFile && file.name.startsWith("assets/"))
        .forEach((file) {
      try {
        final f = File(
            "${directory.absolute.path}${Platform.pathSeparator}assets${Platform.pathSeparator}${file.name.replaceFirst("assets/", "")}");
        //f.parent.createSync(recursive: true);
        f.writeAsBytesSync(file.content as List<int>);
      } catch (e) {
        print(e);
      }
    });
  }

  /// Runs `flutter create .` in the project directory
  Future<void> runFlutterCreate(Directory directory) async {
    Process flutterInitProcess = await startWithOptionalShell(
      "flutter", //shell,
      [
        //"/c",
        //"flutter",
        "create",
        ".",
        "--project-name=$dirPrefix",
      ],
      runInShell: true,
      workingDirectory: directory.absolute.path,
      shell: shell,
    );
    attachProcessOutputListeners(flutterInitProcess, "Init project: ");
    // wait for init to finish
    await flutterInitProcess.exitCode;
    setState(() {
      hasSource = true;
    });
  }

  /// Hot restarts (=updates) all running instances of the Flutter app.
  /// For apps running on web-server, it also shows a Snackbar telling the user
  /// to reload the website.
  void restartRunningApps(BuildContext context) {
    for (var entry in runningFlutterProcesses.entries) {
      if (entry.value != null) {
        if (entry.key == "web-server" && runningFlutterWebAppId != null) {
          var msg = jsonEncode({
            "id": daemonCommandID,
            "method": "app.restart",
            "params": {"appId": runningFlutterWebAppId}
          });
          //attachProcessOutputListeners(process);
          entry.value?.stdin.writeln("[$msg]");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  "Web app restarted. Please reload the page in the browser!")));
        } else {
          entry.value?.stdin.writeln("r");
        }
      }
    }
  }

  /// Builds an executable for the given target platform from the flutter project
  Future<void> buildFlutterApp(BuildTarget target) async {
    var id = target.id;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Building app for $id. This may take a short while.")));
    buildingFlutterProcesses[id] = await startWithOptionalShell(
      "flutter", //shell,
      [
        //"/c",
        //"flutter",
        "build",
        id,
      ],
      workingDirectory: dir!.absolute.path,
      runInShell: true,
      shell: shell,
    );
    setState(() {
      buildingFlutterProcesses[id] = buildingFlutterProcesses[id];
    });
    attachProcessOutputListeners(buildingFlutterProcesses[id], "Build $id: ");
    buildingFlutterProcesses[id]?.exitCode.then((code) {
      if (code == 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: snackbarDuration,
            content: Text("Build for $id successful"),
            action: target.outputDirectory != null
                ? SnackBarAction(
                    label: "Show folder",
                    onPressed: () => openInExplorer(target.outputDirectory!),
                  )
                : null));
        if (id == "windows") {
          hasWindowsExecutable = true;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Build for $id failed"),
        ));
      }
      setState(() {
        buildingFlutterProcesses[id] = null;
      });
      print("Build for $id finished");
    });
  }

  /// Runs the flutter project on the device with a certain id
  Future<void> runFlutterApp(String id) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Starting app on $id. This may take a short while.")));
    var process = await startWithOptionalShell(
        "flutter", //shell,
        [
          //"/c",
          //"flutter",
          "run",
          "-d",
          id,
          if (id == "web-server") "--machine",
        ],
        runInShell: true,
        workingDirectory: dir!.absolute.path,
        shell: shell);
    setState(() {
      runningFlutterProcesses[id] = process;
    });
    var stdoutMulti = process.stdout.asBroadcastStream();
    if (id == "web-server") {
      stdoutMulti.listen((bytes) {
        // For the web server we are using machine readable output because
        // we need to get the url (for other web devices the browser should be
        // launched automatically)
        // TODO Nonetheless it might be a good idea to switch completely to the daemon in the future
        var string = String.fromCharCodes(bytes);
        string.split(RegExp(r'\r?\n')).forEach((line) {
          if (line.isEmpty || !line.startsWith("[") || !line.endsWith("]")) {
            return;
          }
          line = line.substring(1, line.lastIndexOf("]"));
          print(line);
          var json = jsonDecode(line);
          if (json["event"] == "app.webLaunchUrl") {
            String url = json["params"]["url"];
            // bool launched = json["params"]["launched"];
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(seconds: 30),
              content: RichText(
                text: TextSpan(
                  text: 'Web app launched at $url',
                  style: const TextStyle(color: Colors.blue),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      launch(url);
                    },
                ),
              ),
              action: SnackBarAction(
                label: "Open",
                onPressed: () {
                  launch(url);
                },
              ),
            ));
          } else if (json["event"] == "app.started") {
            runningFlutterWebAppId = json["params"]["appId"];
          }
        });
      });
    }

    attachStreamsOutputListeners(stdoutMulti, process.stderr, "Run $id: ");
    // exitCode is a Future that terminates when the process has finished
    process.exitCode.then((_) {
      setState(() {
        runningFlutterProcesses[id] = null;
      });
      print("Application finished on $id");
    });
  }

  /// Launch a built flutter windows app (.exe)
  // TODO X-Platform
  void launchBuiltFlutterWindowsApp(BuildTarget target) {
    if (target.id != "windows" || target.outputDirectory == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Starting built windows app.")));
    var executablePath = dir!.absolute.path +
        Platform.pathSeparator +
        target.outputDirectory! +
        Platform.pathSeparator +
        dir!.absolute.path.split(Platform.pathSeparator).last +
        ".exe";
    print(executablePath);
    File(executablePath).exists().then((exists) async {
      if (exists) {
        launchBuiltExeProcess = await startWithOptionalShell(
          executablePath, [],
          // runInShell: true,
          //workingDirectory: dir.absolute.path,
        );
        setState(() {
          launchBuiltExeProcess = launchBuiltExeProcess;
        });
        attachProcessOutputListeners(launchBuiltExeProcess, "Run windows: ");
        launchBuiltExeProcess?.exitCode.then((_) {
          setState(() {
            launchBuiltExeProcess = null;
          });
          print("Launched built application finished");
        });
      } else {
        print("Prebuilt executable not found");
      }
    });
  }

  /// Redirects the output from streams to stdout, with an optional prefix
  void attachStreamsOutputListeners(
      Stream<List<int>> pstdout, Stream<List<int>> pstderr,
      [String prefix = ""]) {
    pstdout.forEach((element) => stdout.add([...prefix.codeUnits, ...element]));
    pstderr.forEach((element) => stderr.add([...prefix.codeUnits, ...element]));
  }

  /// Redirects the output from a process to stdout, with an optional prefix
  void attachProcessOutputListeners(Process? process, [String prefix = ""]) {
    if (process != null) {
      attachStreamsOutputListeners(process.stdout, process.stderr, prefix);
    }
  }

  /// Ensures that the working / project directory exists and returns it
  Future<Directory> ensureDirectory() async {
    if (dir == null) {
      dir = await (await Directory(
                  selectedDir == 1 ? dirPathAtExecutable : dirPathSystemTemp)
              .create())
          .createTemp(dirPrefix);
      setState(() {
        dir = dir;
      });
      return dir!;
    } else {
      return dir!;
    }
  }

  /// Wrapper for Process.start. If shell != null, changes the executable to shell,
  /// prepends executable to the arguments and ignores runInShell. That way, its possible to e.g.
  /// use powershell instead of Flutter's default (cmd) on windows.
  static Future<Process> startWithOptionalShell(
      String executable, List<String> arguments,
      {String? workingDirectory, bool runInShell = false, String? shell}) {
    if (shell != null) {
      return Process.start(shell, [executable, ...arguments],
          workingDirectory: workingDirectory);
    } else {
      return Process.start(executable, arguments,
          runInShell: runInShell, workingDirectory: workingDirectory);
    }
  }

  /// Wrapper for Process.run. If shell != null, changes the executable to shell,
  /// prepends executable to the arguments and ignores runInShell. That way, its possible to e.g.
  /// use powershell instead of Flutter's default (cmd) on windows.
  static Future<ProcessResult> runWithOptionalShell(
      String executable, List<String> arguments,
      {String? workingDirectory, bool runInShell = false, String? shell}) {
    if (shell != null) {
      return Process.run(shell, [executable, ...arguments],
          workingDirectory: workingDirectory);
    } else {
      return Process.run(executable, arguments,
          runInShell: runInShell, workingDirectory: workingDirectory);
    }
  }

  void openInExplorer(String fileOrDir, {String? shell}) {
    if (Platform.isWindows) {
      runWithOptionalShell("start",
          [Uri.directory(fileOrDir).toFilePath(windows: Platform.isWindows)],
          runInShell: true, shell: shell, workingDirectory: dir!.absolute.path);
    } else if (Platform.isMacOS) {
      // runWithOptionalShell("open", [fileOrDir], runInShell: true,
      //     shell: shell, workingDirectory: dir?.absolute.path);
    } else if (Platform.isLinux) {
      runWithOptionalShell("xdg-open", [fileOrDir],
          runInShell: true, shell: shell, workingDirectory: dir?.absolute.path);
    }
  }
}

class BuildTarget {
  const BuildTarget._(this.id, this.description, this.outputDirectory);

  final String id;
  final String description;
  final String? outputDirectory;

  static const aar = BuildTarget._("aar", "Android (aar)", null);
  static const apk =
      BuildTarget._("apk", "Android (apk)", "build/app/outputs/apk/release");
  static const appbundle = BuildTarget._(
      "appbundle", "Android (appbundle)", "build/app/outputs/bundle/release");
  static const web = BuildTarget._("web", "web", "build/web");
  static const windows = BuildTarget._(
    "windows",
    "windows (exe)",
    "build/windows/runner/Release",
  );
  static const linux = BuildTarget._(
    "linux",
    "linux",
    "build/linux/x64/release/bundle",
  );
}
