import 'package:fahrplan/models/fahrplan/webview.dart';
import 'package:fahrplan/services/bluetooth_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FahrplanWebViewPage extends StatefulWidget {
  const FahrplanWebViewPage({super.key});

  @override
  FahrplanWebViewPageState createState() => FahrplanWebViewPageState();
}

class FahrplanWebViewPageState extends State<FahrplanWebViewPage> {
  late Box<FahrplanWebView> _webViewBox;

  @override
  void initState() {
    super.initState();
    _webViewBox = Hive.box<FahrplanWebView>('fahrplanWebViewBox');
  }

  void _addWebView() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddWebViewDialog(
          onAdd: (webView) async {
            debugPrint('Adding web view: $webView');
            await _webViewBox.add(webView);
            setState(() {});
          },
        );
      },
    );
  }

  void _editWebView(int index) {
    final webView = _webViewBox.getAt(index);
    if (webView == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return _AddWebViewDialog(
          onAdd: (webView) async {
            await _webViewBox.putAt(index, webView);
            setState(() {});
          },
          item: webView,
        );
      },
    );
  }

  void _deleteWebView(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this web view?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final webView = _webViewBox.getAt(index);
                if (webView != null) {
                  webView.hide(); // Stop refresh timer
                }
                _webViewBox.deleteAt(index);
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _toggleWebView(int index) {
    final webView = _webViewBox.getAt(index);
    if (webView == null) return;

    if (webView.isShown) {
      webView.hide();
    } else {
      webView.show();
    }

    _webViewBox.putAt(index, webView);
    setState(() {});
    final bt = BluetoothManager();
    bt.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Web Views'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addWebView,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _webViewBox.listenable(),
        builder: (context, Box<FahrplanWebView> box, _) {
          final webViews = box.values.toList();

          if (webViews.isEmpty) {
            return Center(
              child: Text('No web views yet. Tap + to add one.'),
            );
          }

          return ListView.builder(
            itemCount: webViews.length,
            itemBuilder: (context, index) {
              final webView = webViews[index];
              return ListTile(
                title: Text(webView.name),
                subtitle: Text(
                  '${webView.url}\nRefresh: ${webView.refreshInterval.displayName}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: webView.isShown
                          ? Icon(Icons.stop, color: Colors.red)
                          : Icon(Icons.play_arrow, color: Colors.green),
                      onPressed: () => _toggleWebView(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _editWebView(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteWebView(index),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddWebViewDialog extends StatefulWidget {
  final Function(FahrplanWebView) onAdd;
  final FahrplanWebView? item;

  const _AddWebViewDialog({required this.onAdd, this.item});

  @override
  _AddWebViewDialogState createState() => _AddWebViewDialogState();
}

class _AddWebViewDialogState extends State<_AddWebViewDialog> {
  TextEditingController nameController = TextEditingController();
  TextEditingController urlController = TextEditingController();
  RefreshInterval selectedInterval = RefreshInterval.thirtySeconds;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.item?.name ?? '';
    urlController.text = widget.item?.url ?? '';
    selectedInterval =
        widget.item?.refreshInterval ?? RefreshInterval.thirtySeconds;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.item == null ? Text('Add Web View') : Text('Edit Web View'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Name'),
              controller: nameController,
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(labelText: 'URL'),
              controller: urlController,
            ),
            SizedBox(height: 20),
            Text('Refresh Interval'),
            DropdownButton<RefreshInterval>(
              value: selectedInterval,
              isExpanded: true,
              items: RefreshInterval.values.map((RefreshInterval interval) {
                return DropdownMenuItem<RefreshInterval>(
                  value: interval,
                  child: Text(interval.displayName),
                );
              }).toList(),
              onChanged: (RefreshInterval? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedInterval = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (nameController.text.isEmpty || urlController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please fill in all fields')),
              );
              return;
            }

            if (widget.item == null) {
              final newWebView = FahrplanWebView(
                name: nameController.text,
                url: urlController.text,
                refreshIntervalSeconds: selectedInterval.seconds,
              );
              widget.onAdd(newWebView);
            } else {
              widget.item!.name = nameController.text;
              widget.item!.url = urlController.text;
              widget.item!.setRefreshInterval(selectedInterval);
              widget.onAdd(widget.item!);
            }
            Navigator.of(context).pop();
          },
          child: widget.item == null ? Text('Add') : Text('Save'),
        ),
      ],
    );
  }
}
