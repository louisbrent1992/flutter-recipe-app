import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dynamic_ui_provider.dart';
import '../models/dynamic_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  IconData _iconFromName(String name) {
    switch (name) {
      case 'link':
        return Icons.link_rounded;
      case 'sparkles':
        return Icons.auto_awesome_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'import':
        return Icons.file_download_rounded;
      default:
        return Icons.bolt_rounded;
    }
  }

  Future<void> _handleUrl(BuildContext context, String url) async {
    String? appRouteRaw;
    final trimmed = url.trim();
    if (trimmed.startsWith('app://')) {
      appRouteRaw = trimmed.substring('app://'.length);
    } else if (trimmed.startsWith('/')) {
      appRouteRaw = trimmed.substring(1);
    } else if (!trimmed.contains('://') && (trimmed.contains('?') || trimmed.contains('/'))) {
      appRouteRaw = trimmed;
    }

    if (appRouteRaw != null) {
      final uri = Uri.parse(appRouteRaw);
      final routePath = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
      final args = uri.queryParameters.isNotEmpty ? uri.queryParameters : null;
      // ignore: use_build_context_synchronously
      Navigator.pushNamed(context, routePath, arguments: args);
      return;
    }

    final uri = Uri.parse(trimmed);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicUiProvider>(
      builder: (context, dyn, _) {
        List<QuickActionConfig> actions = const [];
        try {
          final cfg = dyn.config;
          if (cfg != null && cfg.quickActions is List<QuickActionConfig>) {
            actions = cfg.quickActions;
          }
        } catch (_) {
          actions = const [];
        }
        if (actions.isEmpty) return const SizedBox.shrink();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: actions.map((a) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(_iconFromName(a.icon), size: 18),
                  label: Text(a.text),
                  onPressed: () => _handleUrl(context, a.url),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}


