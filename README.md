# xaif

Run your MIT App Inventor projects on (nearly) any operating system!

**This tool is in an early development phase, see the disclaimer below.**

## Demo
https://user-images.githubusercontent.com/58807793/147475511-b9bbba8f-970e-4491-a4dc-f7a4b0089d3b.mp4


## Prerequisites

You will only need to have Flutter installed (https://docs.flutter.dev/get-started/install).

Flutter is an open-source cross-platform app development framework. This tool is built with Flutter, but more
importantly this tool will transpile your app into an (intermediate) Flutter app, that can then be
compiled for different operating systems.

>Important: you will not need to actually write any Flutter code yourself, you just need to have Flutter installed
so this tool can use it under the hood.

>Also important: you only need to install Flutter (and possibly other dependencies) on *your* development machine.
Any executables you build can be installed/run on other devices without installing additional dependencies. (Just like you can distribute your apk).

Please follow [Flutter's installation guide](https://docs.flutter.dev/get-started/install) (depending on your computer's operating system). You will need to
complete the "Get the Flutter SDK" step.

Flutter's setup guides will include additional setup steps (e.g. "Android setup", "Web setup").
You only need to complete these steps if you want to later compile your app for the respective platforms.
(For example, if you want to compile your app into a web app, you need to complete the "Web setup" step).<br>

Make sure that Flutter is correctly set up by running `flutter doctor` in a shell.


## Download
**Please note that xaif has only undergone (limited) testing on Windows and Linux (Ubuntu). It should in theory also work on 
 macOS, but this hasn't been tested, yet.**

To get xaif, you have two options:

1. You can either clone this repository with git or download it as a zip-file from Github (green button titled "Code")
and unzip it to any location.<br>
Then open a shell in the location where you cloned/unzipped the repository and run `flutter run -d windows` (if your computer is running Windows) or `flutter run -d linux` (if your computer is running Linux).<br>
(This will require you to have followed the *additional* setup steps for your operating system in the Flutter installation
guide. So if you want to run xaif on Windows with this approach, you need to *also* follow the ["Windows setup" step](https://docs.flutter.dev/get-started/install/windows#windows-setup) in the Flutter Windows
installation guide, or the ["Linux setup" step](https://docs.flutter.dev/get-started/install/linux#linux-setup) in the Flutter Linux installation guide if you want to run xaif on Linux with this approach)

2. Alternatively, you should be able to use prebuilt binaries of xaif from the CI. They are available from the [releases page](https://github.com/m0nac0/xaif/releases) (as Assets) or from [any successful CI Workflow run](https://github.com/m0nac0/xaif/actions/workflows/main.yml?query=branch%3Amain) (as artifacts). <br>
You should be able to use these prebuilt executables to run xaif without completing the "Windows setup" or "Linux setup" step in the Flutter setup, but you still have to complete the basic Flutter setup!

## Usage Guide
1. Export your project from App Inventor as an AIA file.
2. After starting xaif, select a location for the new project directory and your AIA-file.
3. xaif will now create a new project folder in your chosen location.
Then it transpiles the code (and assets) from the AIA-file to
Flutter code and writes them to the new project directory.<br>
4. Afterwards you are presented with multiple different options
to review the generated Flutter code, run your app on different devices or build executables for different platforms
(operating systems).

The run options are a good choice to quickly test your app on different "devices" (somewhat similar to App Inventor's Companion),
while building your app results in an executable file (or directory of multiple files), like an APK for Android.

While your app is running, you can also update the project by selecting a new AIA file (new version of your app).
Any running instances of your app should update nearly instantly (for web apps, you'll need to reload the page).

After you have built an executable you can also launch it (or manually copy it from the project directory to store it).

(Under the hood, this uses Flutter's functionality for compiling and running apps.)

Please note that your operating system may at any time delete temporary files, including the project directories
created by xaif if you choose your system's temporary files directory as the location of the project directory. If you want to back up the project directory, simply copy it to another location (you can
see the location of the project directory in xaif).

Please also note that every time you launch xaif, a new project directory is created. If you want to use xaif
for different projects, it is recommended to close and reopen xaif to actually create a new project directory
(otherwise the files from the old project are overwritten).

xaif does not delete its project directory, unless you explicitly tell it to. If you want to save storage space
you should delete project directories that you don't need any longer.


### Available platforms
Depending on your computer's operating system, the choice of platforms will vary. E.g. if you are on a
Windows computer, you won't be able to compile your app for iOS.

#### Compiling an *.exe for windows
If you want to build your app for windows (build an exe-file) you may need to

a) Turn on developer mode on your Windows machine (recommended by the Flutter team)

b) OR  go to the project directory once (path is displayed in the tool), open an admin command prompt and run
`flutter build windows`

The reason is that this tool uses Flutter plugins for many components, and Flutter cannot (at this time)
build windows executables
with plugins if developer mode is not turned on (or the build has not been run as admin).

It is (as always) your responsibility to review the code generated by this tool and decide if you are
comfortable building it in an admin shell!


## Project Status

- Only single-screen apps supported
- Some special Screen1-properties not supported
    - e.g. only Material Theme is supported

### Builtin blocks

- Control: complete, except blocks related to dictionaries and multi-screen
- Logic: (mostly) complete
- Math: (mostly) complete
- Text: (mostly) complete
- Lists: complete, except lists_to_csv_table,lists_from_csv_table, lists_lookup_in_pairs
- Dictionaries: (mostly) complete, except advanced methods
- Color: (mostly) complete
- Variables: complete
- Procedures: complete

### Components (including their methods)

- UI: complete except ListPicker, WebViewer & possibly some attributes on some components.
- Layout: complete (Change: TableArrangement is scrollable)
- Media: only Camera, Camcorder, ImagePicker, Player
- Drawing/Animation: none
- Maps: none
- Sensors: only Clock (limited)
- Social: Sharing, Texting and PhoneCall (but no direct messages/calls; no intercepting of messages/calls)
- Storage: complete, except CloudDB
    - File does not have functionality for Delete, Append, LegacyMode
    - NB TinyWebDB may not work correctly in web browsers, if the used web service does not run on https
      (like the default one)
- Connectivity: only Web (no sending/saving files, no cookies, no header/timeout control, no decoding with dictionaries)
- Mindstorms: none (will not implement due to lack of Mindstorms equipment)
- Experimental: none
- Extensions: not yet supported


## Plugins / Licenses
Depending on which components your app uses, (the code generated by) xaif may use different Flutter plugins. You should make sure that you
obey all licenses of these plugins and of Flutter.
To help with that, this tool will add an "About" entry to the AppBar's
overflow menu ("three dot menu"), that opens an about dialog. That dialog contains information about this tool, about
your app and the option to open a licenses page with some information about all plugins and their licenses (generated
automatically by Flutter).

## Feedback & Contributions
If you have any feedback, or encounter any issues running your project, please let me know by [opening an issue](https://github.com/m0nac0/xaif/issues/new) or [discussion](https://github.com/m0nac0/xaif/discussions/new)!

## Disclaimer
This tool is in an early development phase and not very well tested.

It is your responsibility to check the code generated by this tool and use this tool with caution.

Please check the LICENSE file, and especially note the following parts of the LICENSE:

>15. Disclaimer of Warranty.
>
>THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
>
>16. Limitation of Liability.
>
>IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
## Security
(Where possible) it is always advisable to review code you are running, which includes code generated by this tool.

In addition to all the above, you should only use this tool with AIA-files that you trust.
I cannot exclude with certainty that it may in some cases be possible for an attacker to insert malicious Dart code into the generated Dart code,
if you use a malicious AIA-file from an attacker.

## Acknowledgements
A huge thank you to the team at MIT App Inventor, for creating, maintaining and continously improving the App Inventor, which I consider one of the greatest tools to teach programming and app development!

And similarly thank you to the Flutter team for creating their great cross-platform app development framework!
