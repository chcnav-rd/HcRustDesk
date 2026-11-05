import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';

const String kSourceRepositoryUrl = 'https://github.com/chcnav-rd/HcRustDesk';
const String kLicenseUrl =
    'https://github.com/chcnav-rd/HcRustDesk/blob/main/LICENCE';
const String kModifiedVersionNotice =
    'This is a modified version of RustDesk. Modified on 2026-11-05.';
const String kAgplNotice =
    'Licensed under the GNU Affero General Public License. There is no warranty. You may redistribute it under this license.';
const String kViewLicense = 'View the license';

/// Opens the public repository that holds the corresponding source.
Future<void> openSourceRepository() {
  return launchUrl(
    Uri.parse(kSourceRepositoryUrl),
    mode: LaunchMode.externalApplication,
  );
}

/// Opens the GNU Affero General Public License text.
Future<void> openLicense() {
  return launchUrl(
    Uri.parse(kLicenseUrl),
    mode: LaunchMode.externalApplication,
  );
}

/// Shows the modification notice, AGPL terms, and links to the source and license.
class AgplNotice extends StatelessWidget {
  final Color? color;
  final bool showCopyright;

  const AgplNotice({Key? key, this.color, this.showCopyright = true})
      : super(key: key);

  /// Builds the modification notice, license statement, and source links.
  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(color: color, fontSize: 13);
    final linkStyle = textStyle.copyWith(decoration: TextDecoration.underline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCopyright)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Copyright © ${DateTime.now().year} Purslane Tech Pte. Ltd.',
              style: textStyle,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(translate(kModifiedVersionNotice), style: textStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(translate(kAgplNotice), style: textStyle),
        ),
        InkWell(
          onTap: () {
            openSourceRepository();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(translate('Source code'), style: linkStyle),
          ),
        ),
        InkWell(
          onTap: () {
            openLicense();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(translate(kViewLicense), style: linkStyle),
          ),
        ),
      ],
    );
  }
}
