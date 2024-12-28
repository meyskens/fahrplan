import 'package:fahrplan/models/fahrplan/fahrplan_dashboard.dart';
import 'package:fahrplan/models/g1/note.dart';
import 'package:flutter/material.dart';

class CurrentFahrplan extends StatefulWidget {
  const CurrentFahrplan({super.key});

  @override
  State<CurrentFahrplan> createState() => _CurrentFahrplanState();
}

class _CurrentFahrplanState extends State<CurrentFahrplan> {
  FahrplanDashboard fahrplanDashboard = FahrplanDashboard();

  List<Note> _dashboardItems = [];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    _dashboardItems = await fahrplanDashboard.generateDashboardItems();
    _selectedIndex = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const Text('Current Fahrplan'),
          const Divider(),
          _dashboardItems.isNotEmpty
              ? Text(_dashboardItems[_selectedIndex].text)
              : Text("No items found"),
          const Divider(),
          // add next and previous buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _selectedIndex > 0
                    ? () {
                        setState(() {
                          _selectedIndex--;
                        });
                      }
                    : null,
                child: const Icon(Icons.arrow_back),
              ),
              ElevatedButton(
                onPressed: (_selectedIndex < _dashboardItems.length - 1)
                    ? () => {
                          setState(() {
                            _selectedIndex++;
                          })
                        }
                    : null,
                child: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
