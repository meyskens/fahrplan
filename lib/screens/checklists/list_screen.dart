import 'package:fahrplan/models/fahrplan/checklist.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChecklistItemsScreen extends StatefulWidget {
  final int index;
  final FahrplanChecklist checklist;

  const ChecklistItemsScreen(
      {super.key, required this.index, required this.checklist});

  @override
  ChecklistItemsScreenState createState() => ChecklistItemsScreenState();
}

class ChecklistItemsScreenState extends State<ChecklistItemsScreen> {
  late Box<FahrplanChecklist> _checklistBox;

  @override
  void initState() {
    super.initState();
    _checklistBox = Hive.box<FahrplanChecklist>('fahrplanChecklistBox');
  }

  void _addItem() {
    if (widget.checklist.items.length >= 16) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('You can only have up to 16 items in a checklist.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        return _AddItemDialog(
          onAdd: (item) async {
            widget.checklist.items.add(item);
            await _checklistBox.putAt(widget.index, widget.checklist);
            setState(() {});
          },
        );
      },
    );
  }

  void _editItem(int index) {
    final item = widget.checklist.items[index];

    showDialog(
      context: context,
      builder: (context) {
        return _AddItemDialog(
          onAdd: (item) async {
            widget.checklist.items[index] = item;
            await _checklistBox.putAt(widget.index, widget.checklist);
            setState(() {});
          },
          item: item,
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
          content: Text('Are you sure you want to delete this item?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                widget.checklist.items.removeAt(index);
                await _checklistBox.putAt(widget.index, widget.checklist);
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

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = widget.checklist.items.removeAt(oldIndex);
      widget.checklist.items.insert(newIndex, item);
      _checklistBox.putAt(widget.index, widget.checklist);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.checklist.name),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addItem,
          ),
        ],
      ),
      body: ReorderableListView(
        onReorder: _onReorder,
        children: [
          for (int index = 0; index < widget.checklist.items.length; index++)
            ListTile(
              key: ValueKey(widget.checklist.items[index]),
              title: Text(widget.checklist.items[index].title),
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
            ),
        ],
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final Function(FahrplanCheckListItem) onAdd;
  final FahrplanCheckListItem? item;

  const _AddItemDialog({required this.onAdd, this.item});

  @override
  _AddItemDialogState createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  TextEditingController titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    titleController.text = widget.item?.title ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.item == null ? Text('Add Item') : Text('Edit Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(labelText: 'Title'),
            controller: titleController,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (widget.item == null) {
              widget.onAdd(FahrplanCheckListItem(title: titleController.text));
            } else {
              widget.item!.title = titleController.text;
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
