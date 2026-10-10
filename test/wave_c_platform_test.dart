// Wave C - store/security configuration, asserted from the checked-in files so a
// regression in the manifests / plists fails CI (MASVS-STORAGE, -NETWORK;
// App Store export compliance + privacy manifest; Play backup policy).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('Android', () {
    final main = _read('android/app/src/main/AndroidManifest.xml');
    final debug = _read('android/app/src/debug/AndroidManifest.xml');
    final profile = _read('android/app/src/profile/AndroidManifest.xml');
    final mainNsc = _read('android/app/src/main/res/xml/network_security_config.xml');
    final debugNsc = _read('android/app/src/debug/res/xml/network_security_config.xml');

    test('UX-M64 backup is off and extraction rules exclude everything', () {
      expect(main, contains('android:allowBackup="false"'));
      expect(main, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
      final rules = _read('android/app/src/main/res/xml/data_extraction_rules.xml');
      for (final scope in ['cloud-backup', 'device-transfer']) {
        expect(rules, contains('<$scope>'));
      }
      for (final d in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(RegExp('exclude domain="$d"').allMatches(rules).length, 2, reason: d);
      }
    });

    test('release network policy: no cleartext anywhere in main', () {
      expect(main, contains('android:networkSecurityConfig="@xml/network_security_config"'));
      expect(main, contains('android:usesCleartextTraffic="false"'));
      expect(main, isNot(contains('usesCleartextTraffic="true"')));
      expect(mainNsc, contains('<base-config cleartextTrafficPermitted="false"'));
      expect(mainNsc, isNot(contains('cleartextTrafficPermitted="true"')));
      expect(mainNsc, isNot(contains('<domain-config')));
      expect(mainNsc, isNot(contains('src="user"')), reason: 'user CAs are not trusted');
    });

    test('debug source set permits cleartext for the local lab hosts ONLY', () {
      expect(debug, isNot(contains('usesCleartextTraffic="true"')));
      final domains = RegExp(r'<domain[^>]*>([^<]+)</domain>').allMatches(debugNsc).map((m) => m.group(1)).toSet();
      expect(domains, {'127.0.0.1', 'localhost', '10.0.2.2'});
      expect(debugNsc, contains('<base-config cleartextTrafficPermitted="false"'));
      expect(RegExp('<domain-config cleartextTrafficPermitted="true"').allMatches(debugNsc), hasLength(1));
    });

    test('only the needed permissions; only the launcher activity is exported', () {
      final perms = RegExp(r'uses-permission android:name="([^"]+)"').allMatches(main).map((m) => m.group(1)).toSet();
      expect(perms, {
        'android.permission.INTERNET',
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
      });
      final exported = RegExp(r'android:exported="true"').allMatches(main).length;
      expect(exported, 1, reason: 'MainActivity (launcher) is the only exported component');
      expect(profile, isNot(contains('cleartext')));
    });
  });

  group('iOS', () {
    final plist = _read('ios/Runner/Info.plist');
    final privacy = _read('ios/Runner/PrivacyInfo.xcprivacy');

    test('export compliance: ITSAppUsesNonExemptEncryption = false', () {
      expect(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>').hasMatch(plist), isTrue);
    });

    test('ATS is not weakened', () {
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
      expect(plist, isNot(contains('NSExceptionAllowsInsecureHTTPLoads')));
    });

    test('Vietnamese usage strings for location, camera and photos', () {
      for (final k in ['NSLocationWhenInUseUsageDescription', 'NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription']) {
        final m = RegExp('<key>$k</key>\\s*<string>([^<]+)</string>').firstMatch(plist);
        expect(m, isNotNull, reason: k);
        expect(m!.group(1), matches(RegExp(r'[À-ỹ]')), reason: '$k is written in Vietnamese');
      }
      expect(plist, isNot(contains('NSLocationAlwaysUsageDescription')), reason: 'foreground only');
    });

    test('privacy manifest: collected data is linked, never tracking; no payment data', () {
      expect(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(privacy), isTrue);
      final types = RegExp(r'<string>NSPrivacyCollectedDataType(\w+)</string>').allMatches(privacy).map((m) => m.group(1)!).where((t) => !t.startsWith('Purpose')).toSet();
      expect(types, containsAll(['Name', 'EmailAddress', 'PhoneNumber', 'PreciseLocation', 'PhotosorVideos', 'UserID']));
      expect(types, isNot(contains('PaymentInfo')));
      final n = types.length;
      expect(RegExp(r'<key>NSPrivacyCollectedDataTypeLinked</key>\s*<true/>').allMatches(privacy), hasLength(n));
      expect(RegExp(r'<key>NSPrivacyCollectedDataTypeTracking</key>\s*<false/>').allMatches(privacy), hasLength(n));
      expect(privacy, isNot(contains('NSPrivacyCollectedDataTypeTracking</key>\n\t\t\t<true')));
      expect(privacy, contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'));
    });
  });
}
