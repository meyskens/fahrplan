import 'package:fahrplan/models/fahrplan/waypoint.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FahrplanWaypointPage extends StatefulWidget {
  const FahrplanWaypointPage({super.key});

  @override
  FahrplanWaypointPageState createState() => FahrplanWaypointPageState();
}

class FahrplanWaypointPageState extends State<FahrplanWaypointPage> {
  late Box<FahrplanWaypoint> _fahrplanWaypointBox;

  @override
  void initState() {
    super.initState();
    _fahrplanWaypointBox = Hive.box<FahrplanWaypoint>('fahrplanWaypointBox');
  }

  Future<void> _sortBox() async {
    final items = _fahrplanWaypointBox.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    await _fahrplanWaypointBox.clear();
    await _fahrplanWaypointBox.addAll(items);
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddItemDialog(
          onAdd: (description, startTime) {
            final newItem = FahrplanWaypoint(
                description: description, startTime: startTime);
            _fahrplanWaypointBox.add(newItem);
            _sortBox();
            setState(() {});
          },
        );
      },
    );
  }

  void _editItem(int index) {
    final item = _fahrplanWaypointBox.getAt(index);
    showDialog(
      context: context,
      builder: (context) {
        return _AddItemDialog(
          item: item,
          onAdd: (description, startTime) {
            final newItem = FahrplanWaypoint(
                description: description, startTime: startTime);
            _fahrplanWaypointBox.putAt(index, newItem);
            _sortBox();
            setState(() {});
          },
        );
      },
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this waypoint?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _fahrplanWaypointBox.deleteAt(index);
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

  String _formatDateTime(DateTime dateTime) {
    dateTime = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timePart =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (itemDate == today) {
      return 'Today $timePart';
    } else if (itemDate == today.add(Duration(days: 1))) {
      return 'Tomorrow $timePart';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} $timePart';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fahrplan Waypoints'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addItem,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _fahrplanWaypointBox.listenable(),
        builder: (context, Box<FahrplanWaypoint> box, _) {
          final items = box.values.toList();

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.description),
                subtitle: Text(_formatDateTime(item.startTime)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => _editItem(index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteItem(index),
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

class _AddItemDialog extends StatefulWidget {
  final Function(String, DateTime) onAdd;
  final FahrplanWaypoint? item;

  const _AddItemDialog({required this.onAdd, this.item});

  @override
  _AddItemDialogState createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  TextEditingController descriptionController = TextEditingController();
  late DateTime selectedDateTime;

  @override
  void initState() {
    super.initState();
    descriptionController.text = widget.item?.description ?? '';
    selectedDateTime = widget.item?.startTime ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Waypoint' : 'Edit Waypoint'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(labelText: 'Description'),
            controller: descriptionController,
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Date: ${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year}',
                ),
              ),
              IconButton(
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDateTime = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        selectedDateTime.hour,
                        selectedDateTime.minute,
                      );
                    });
                  }
                },
                icon: Icon(Icons.calendar_today),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Time: ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                ),
              ),
              IconButton(
                onPressed: () async {
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: selectedDateTime.hour,
                      minute: selectedDateTime.minute,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDateTime = DateTime(
                        selectedDateTime.year,
                        selectedDateTime.month,
                        selectedDateTime.day,
                        picked.hour,
                        picked.minute,
                      );
                    });
                  }
                },
                icon: Icon(Icons.access_time),
              ),
            ],
          ),
        ],
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
            widget.onAdd(descriptionController.text, selectedDateTime);
            Navigator.of(context).pop();
          },
          child: widget.item == null ? Text('Add') : Text('Save'),
        ),
      ],
    );
  }
}
