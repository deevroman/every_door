// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:every_door/helpers/quick_actions.dart';
import 'package:every_door/models/plugin.dart';
import 'package:every_door/providers/edpr.dart';
import 'package:every_door/providers/plugin_repo.dart';
import 'package:every_door/screens/settings/install_plugin.dart';
import 'package:every_door/widgets/plugin_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;

class PluginRepositoryPage extends ConsumerStatefulWidget {
  final bool updatesOnly;

  const PluginRepositoryPage({super.key, this.updatesOnly = false});

  @override
  ConsumerState<PluginRepositoryPage> createState() =>
      _PluginRepositoryPageState();
}

class _PluginRepositoryPageState extends ConsumerState<PluginRepositoryPage> {
  late final TextEditingController _controller;
  String _filter = '';
  bool _experimental = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final AsyncValue<List<RemotePlugin>> plugins = ref.watch(edprProvider);

    final Map<String, Plugin> installed = Map.fromEntries(
        ref.read(pluginRepositoryProvider).map((p) => MapEntry(p.id, p)));

    List<Widget> items;
    if (plugins.isLoading) {
      items = [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator()],
        ),
        Text('Loading plugin list...'),
      ];
    } else if (plugins.hasError) {
      items = [
        Text('Error loading plugins: ${plugins.error}'),
      ];
    } else {
      final list = List<RemotePlugin>.of(plugins.value ?? []);
      if (_filter.isNotEmpty) {
        final f = _filter.toLowerCase();
        list.removeWhere((p) =>
            !p.name.toLowerCase().contains(f) &&
            !p.id.toLowerCase().contains(f));
      }
      if (!_experimental) list.removeWhere((p) => p.experimental);
      list.sort((a, b) => b.downloads.compareTo(a.downloads));
      items = list.where((p) {
        final installedPlugin = installed[p.id];
        if (installedPlugin == null) return !widget.updatesOnly;
        return p.version.fresherThan(installedPlugin.version) ||
            (p.url != null &&
                installedPlugin.url != null &&
                p.url.toString() != installedPlugin.url.toString()) ||
            (installedPlugin.installedAt != null &&
                p.updated
                    .toUtc()
                    .isAfter(installedPlugin.installedAt!.toUtc()));
      }).map((p) {
        final downloadUrl = p.url;
        final installUri = downloadUrl == null
            ? null
            : Uri.https(
                'plugins.every-door.app',
                '/i/${p.id}',
                {
                  'url': downloadUrl.toString(),
                  'version': p.version.toString(),
                  'update': 'true',
                },
              );
        return PluginCard(
          plugin: p,
          actionText: installUri == null
              ? null
              : installed.containsKey(p.id)
                  ? loc.pluginsUpdate.toUpperCase()
                  : loc.pluginsInstall.toUpperCase(),
          onAction: installUri == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InstallPluginPage(installUri),
                    ),
                  );
                },
        );
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.updatesOnly ? loc.pluginsUpdate : loc.pluginsRepository),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: () {
              installPluginFromQrCode(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(edprProvider);
        },
        child: ListView(
          children: [
            if (plugins.valueOrNull?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: loc.pluginsSearch,
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _controller.clear();
                                      _filter = '';
                                    });
                                  },
                                ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filter = value.trim();
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.construction),
                      color: _experimental ? Colors.black : Colors.grey,
                      tooltip: 'Include experimental builds',
                      onPressed: () {
                        setState(() {
                          _experimental = !_experimental;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ...items,
            SizedBox(height: 100.0),
          ],
        ),
      ),
    );
  }
}
