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
class PubspecBuilder {
  static const lineEnding = "\r\n";

  /// List of packages that may be imported
  static const allowedPackages = [
    //packages supported by the Dart/Flutter team
    "http",
    "cross_file",
    "shared_preferences",
    "url_launcher",
    "image_picker",
    //Third-party packages
    "share_plus"
  ];

  /// Generates the content of a valid pubspec.yaml file with the passed
  /// packages as dependencies.
  /// Packages are filtered against the allowlist (see allowedPackages).
  static String getPubspec(Iterable<String> packages) {
    return [
      //TODO use actual app name (and about text?)
      "name: xaif_project",
      "description: A Flutter app created with xaif",
      "publish_to: 'none' # Remove this line if you wish to publish to pub.dev",
      "version: 1.0.0",
      "environment:",
      "  sdk: '>=2.7.0 <3.0.0'",
      "dependencies:",
      "  flutter:",
      "    sdk: flutter",
      ...packages
          .where((package) => allowedPackages.contains(package))
          .map((package) => "  " + package + ":"),
      "flutter:",
      "  assets:",
      "    - assets/",
      "  uses-material-design: true"
    ].fold(
        "", (previousValue, element) => previousValue + lineEnding + element);
  }
}
