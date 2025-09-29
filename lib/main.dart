import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  runApp(MaterialApp(
    home: RoutinePage(),
    debugShowCheckedModeBanner: false,
  ));
}

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  final List<String> days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
  ];

  List<String> times = ['8:30am-10:00am'];
  Map<String, List<RoutineCellData>> routine = {
    '8:30am-10:00am': List.generate(5, (_) => RoutineCellData('', '')),
  };

  final List<String> allTimes = [
    '8:30am-10:00am',
    '10:10am-11:40am',
    '11:50am-1:20pm',
    '1:30pm-3:00pm',
    '3:10pm-4:40pm',
    '4:50pm-6:20pm',
    '4:50pm-6:50pm',
    '4:50pm-7:50pm',
    'Custom',
  ];

  final double dayColWidth = 120;
  final double timeColWidth = 150;
  final double cellMargin = 4;

  final GlobalKey _routineKey = GlobalKey();

  void _showAddTimeDialog() async {
    List<String> availableTimes = [
      ...allTimes.where((t) => t == 'Custom' || !times.contains(t))
    ];
    String selectedTime = availableTimes[0];
    String customTime = '';
    String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Add Time Slot'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedTime,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down),
                  items: availableTimes.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(t),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedTime = val!;
                    });
                  },
                ),
                if (selectedTime == 'Custom')
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Custom Time',
                      ),
                      onChanged: (val) {
                        customTime = val;
                      },
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  String timeToAdd = selectedTime == 'Custom'
                      ? customTime.trim()
                      : selectedTime;
                  if (timeToAdd.isEmpty || times.contains(timeToAdd)) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context, timeToAdd);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.blue,
                ),
                child: Text('Add'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result.isNotEmpty && !times.contains(result)) {
      setState(() {
        times.add(result);
        routine[result] =
            List.generate(days.length, (_) => RoutineCellData('', ''));
      });
    }
  }

  void _showRemoveTimeDialog() async {
    if (times.isEmpty) return;
    List<String> uniqueTimes = times.toSet().toList();
    String selectedTime = uniqueTimes[0];
    bool removed = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Remove Time Slot'),
            content: DropdownButton<String>(
              value: selectedTime,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down),
              items: uniqueTimes.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedTime = val!;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    times.removeWhere((tt) => tt == selectedTime);
                    routine.remove(selectedTime);
                    removed = true;
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.red,
                ),
                child: Text('Remove'),
              ),
            ],
          ),
        );
      },
    );
    if (removed) setState(() {});
  }

  void _showEditCellDialog(int dayIdx, String time) async {
    final cell = routine[time]![dayIdx];
    String course = cell.course;
    String room = cell.room;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Edit Class'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Course Name',
                  ),
                  controller: TextEditingController(text: course),
                  onChanged: (val) {
                    course = val;
                  },
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Room Number',
                  ),
                  controller: TextEditingController(text: room),
                  onChanged: (val) {
                    room = val;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    routine[time]![dayIdx] = RoutineCellData(course, room);
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.blue,
                ),
                child: Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    setState(() {});
  }

  Future<void> _saveRoutineToDownloads() async {
    try {
      RenderRepaintBoundary boundary =
      _routineKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        throw Exception('Downloads folder not found');
      }
      final filePath = '${downloadsDir.path}/routine_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Routine saved to Downloads: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  void _showSaveOptions() async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height - 100,
        16,
        16,
      ),
      items: [
        PopupMenuItem(
          value: 'save1',
          child: Text('Save 1'),
        ),
        PopupMenuItem(
          value: 'save2',
          child: Text('Save 2'),
        ),
      ],
    );
    if (selected == 'save1') {
      await _saveRoutineToDownloads();
    } else if (selected == 'save2') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('you choosed save 2')),
      );
    }
  }

  void _showAddOptions() async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height - 100,
        16,
        16,
      ),
      items: [
        PopupMenuItem(
          value: 'manual',
          child: Text('manual course'),
        ),
        PopupMenuItem(
          value: 'auto',
          child: Text('Auto Course'),
        ),
        PopupMenuItem(
          value: 'faculty',
          child: Text('faculty'),
        ),
      ],
    );
    if (selected == 'manual') {
      _showAddTimeDialog();
    } else if (selected == 'auto') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto Course')),
      );
    } else if (selected == 'faculty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('faculty')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalTimeColWidth = times.length * (timeColWidth + cellMargin);
    final double tableWidth = dayColWidth + totalTimeColWidth;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Routine',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.blue[900],
        elevation: 4,
        centerTitle: true,
      ),
      body: Container(
        color: Color(0xFF263238),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double minWidth = constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth > minWidth ? tableWidth : minWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: RepaintBoundary(
                    key: _routineKey,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[900],
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: dayColWidth,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: Text(
                                  'Day',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    letterSpacing: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              ...times.map((t) => Container(
                                width: timeColWidth,
                                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                alignment: Alignment.center,
                                margin: EdgeInsets.symmetric(horizontal: cellMargin / 2),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              )),
                            ],
                          ),
                        ),
                        ...days.asMap().entries.map((entry) {
                          final i = entry.key;
                          final bool isEven = i % 2 == 0;
                          return Container(
                            decoration: BoxDecoration(
                              color: isEven ? Colors.blueGrey[800] : Colors.blueGrey[700],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: dayColWidth,
                                  height: 60,
                                  alignment: Alignment.center,
                                  child: Text(
                                    days[i],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                ...times.map((t) {
                                  final cell = routine[t]![i];
                                  return GestureDetector(
                                    onTap: () => _showEditCellDialog(i, t),
                                    child: Container(
                                      width: timeColWidth,
                                      height: 60,
                                      alignment: Alignment.center,
                                      margin: EdgeInsets.symmetric(horizontal: cellMargin / 2, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey[900],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blueGrey[600]!),
                                      ),
                                      child: RoutineCell(cell),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 8.0),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'remove',
                onPressed: _showRemoveTimeDialog,
                backgroundColor: Colors.red[700],
                child: Icon(Icons.remove, color: Colors.white),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'add',
                onPressed: _showAddOptions,
                backgroundColor: Colors.blue[900],
                child: Icon(Icons.add, color: Colors.white),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                heroTag: 'save',
                onPressed: _showSaveOptions,
                backgroundColor: Colors.green[700],
                child: Icon(Icons.arrow_downward, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineCellData {
  final String course;
  final String room;
  RoutineCellData(this.course, this.room);
}

class RoutineCell extends StatelessWidget {
  final RoutineCellData data;
  const RoutineCell(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = (data.course.trim().isEmpty && data.room.trim().isEmpty);
    if (isEmpty) {
      return Text(
        '-',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 15,
        ),
        textAlign: TextAlign.center,
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          data.course,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (data.room.trim().isNotEmpty)
          Text(
            data.room,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }
}