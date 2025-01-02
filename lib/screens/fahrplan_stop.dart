import 'package:fahrplan/models/fahrplan/stop.dart';
import 'package:fahrplan/services/stops_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FahrplanStopPage extends StatefulWidget {
  const FahrplanStopPage({super.key});

  @override
  FahrplanStopPageState createState() => FahrplanStopPageState();
}

class FahrplanStopPageState extends State<FahrplanStopPage> {
  late LazyBox<FahrplanStopItem> _fahrplanStopBox;
  StopsManager stopsManager = StopsManager();

  @override
  void initState() {
    super.initState();
    _fahrplanStopBox = Hive.lazyBox<FahrplanStopItem>('fahrplanStopBox');
  }

  Future<void> _sortBox() async {
    final List<FahrplanStopItem> items = [];
    for (int i = 0; i < _fahrplanStopBox.length; i++) {
      final item = await _fahrplanStopBox.getAt(i);
      if (item != null) {
        items.add(item);
      }
    }

    items.sort((a, b) => a.time.compareTo(b.time));
    await _fahrplanStopBox.clear();
    await _fahrplanStopBox.addAll(items);

    stopsManager.reload();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) {
        String title = '';
        DateTime time = DateTime.now();
        return AlertDialog(
          title: Text('Add Stop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Title'),
                onChanged: (value) {
                  title = value;
                },
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        time = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Text('Pick Date and Time'),
              ),
              SizedBox(height: 10),
              Text(
                'Selected: ${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final newItem = FahrplanStopItem(title: title, time: time);
                _fahrplanStopBox.add(newItem);
                await _sortBox();
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editItem(int index) async {
    final item = await _fahrplanStopBox.getAt(index);
    if (item == null) return;

    showDialog(
      context: context,
      builder: (context) {
        String title = item.title;
        DateTime time = item.time;
        return AlertDialog(
          title: Text('Edit Stop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Title'),
                controller: TextEditingController(text: title),
                onChanged: (value) {
                  title = value;
                },
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: time,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(time),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        time = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: Text('Pick Date and Time'),
              ),
              SizedBox(height: 10),
              Text(
                'Selected: ${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                item.title = title;
                item.time = time;
                await _fahrplanStopBox.putAt(index, item);
                await _sortBox();
                setState(() {});
                Navigator.of(context).pop();
              },
              child: Text('Update'),
            ),
          ],
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
          content: Text('Are you sure you want to delete this stop?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _fahrplanStopBox.deleteAt(index);
                _sortBox();
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

  Future<List<FahrplanStopItem>> _getItems() async {
    final List<FahrplanStopItem> items = [];
    for (int i = 0; i < _fahrplanStopBox.length; i++) {
      final item = await _fahrplanStopBox.getAt(i);
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fahrplan Stops'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addItem,
          ),
        ],
      ),
      body: FutureBuilder<List<FahrplanStopItem>>(
        future: _getItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No stops available'));
          } else {
            final items = snapshot.data!;
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                      '${item.time.year}-${item.time.month.toString().padLeft(2, '0')}-${item.time.day.toString().padLeft(2, '0')} ${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}'),
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
          }
        },
      ),
    );
  }
}
