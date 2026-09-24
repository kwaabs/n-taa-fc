import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/dio_client.dart';
import 'server_config.dart';

const _dismissedVersionCodeKey = 'update_dismissed_version_code';

class AndroidReleaseInfo {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String? sha256;
  final int? sizeBytes;
  final String? releasedAt;

  const AndroidReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    this.sha256,
    this.sizeBytes,
    this.releasedAt,
  });

  factory AndroidReleaseInfo.fromJson(Map<String, dynamic> json) {
    return AndroidReleaseInfo(
      versionName: json['versionName'] as String? ?? '',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      sha256: json['sha256'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      releasedAt: json['releasedAt'] as String?,
    );
  }
}

class AppUpdateCheckResult {
  final AndroidReleaseInfo remote;
  final int localVersionCode;
  final String localVersionName;
  final bool updateAvailable;

  const AppUpdateCheckResult({
    required this.remote,
    required this.localVersionCode,
    required this.localVersionName,
    required this.updateAvailable,
  });
}

Future<AppUpdateCheckResult?> fetchAndroidUpdate(Dio dio) async {
  final info = await PackageInfo.fromPlatform();
  final localCode = int.tryParse(info.buildNumber) ?? 0;

  final res = await dio.get('/api/v1/app/android/latest');
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) {
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      message: 'Failed to check for updates (${res.statusCode})',
    );
  }

  final data = res.data is Map && res.data['data'] != null
      ? res.data['data'] as Map<String, dynamic>
      : res.data as Map<String, dynamic>;
  final remote = AndroidReleaseInfo.fromJson(data);

  return AppUpdateCheckResult(
    remote: remote,
    localVersionCode: localCode,
    localVersionName: info.version,
    updateAvailable: remote.versionCode > localCode,
  );
}

Future<bool> wasUpdateDismissed(int versionCode) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_dismissedVersionCodeKey) == versionCode;
}

Future<void> dismissUpdate(int versionCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_dismissedVersionCodeKey, versionCode);
}

Future<void> openApkDownload(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not open download URL');
  }
}

Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdateCheckResult result, {
  required bool allowDismiss,
}) async {
  final remote = result.remote;
  await showDialog<void>(
    context: context,
    barrierDismissible: allowDismiss,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'A newer Field Collector is available.\n\n'
          'Installed: ${result.localVersionName} (${result.localVersionCode})\n'
          'Latest: ${remote.versionName} (${remote.versionCode})',
        ),
        actions: [
          if (allowDismiss)
            TextButton(
              onPressed: () async {
                await dismissUpdate(remote.versionCode);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () async {
              try {
                await openApkDownload(remote.downloadUrl);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Download'),
          ),
        ],
      );
    },
  );
}

/// Soft update prompt after login when a newer APK is published.
class AppUpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  const AppUpdateGate({super.key, required this.child});

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  var _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked || kIsWeb) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    final dio = ref.read(dioProvider);
    final config = ref.read(serverConfigProvider).value;
    if (dio == null || config == null || !mounted) return;

    try {
      final result = await fetchAndroidUpdate(dio);
      if (result == null || !result.updateAvailable || !mounted) return;
      if (await wasUpdateDismissed(result.remote.versionCode)) return;
      if (!mounted) return;
      await showUpdateDialog(context, result, allowDismiss: true);
    } catch (_) {
      // Soft check — ignore network / missing release.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
