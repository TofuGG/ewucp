import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final GlobalKey _saveFabKey = GlobalKey();
  final List<String> days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
  ];

  List<String> times = [];
  Map<String, List<RoutineCellData>> routine = {};

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

  @override
  void initState() {
    super.initState();
    _loadRoutineData();
  }

  Future<void> _saveRoutineToPdf() async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: pw.EdgeInsets.all(4),
                    child: pw.Text('Day/Time', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  ...times.map((t) => pw.Container(
                    padding: pw.EdgeInsets.all(4),
                    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  )),
                ],
              ),
              ...days.asMap().entries.map((entry) {
                final dayIdx = entry.key;
                final day = entry.value;
                return pw.TableRow(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(day, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    ...times.map((time) {
                      final cell = routine[time]![dayIdx];
                      String cellText = '';
                      if (cell.course.isNotEmpty) {
                        cellText = cell.course;
                        if (cell.room.isNotEmpty) cellText += '\n${cell.room}';
                        if (cell.friends.isNotEmpty) cellText += '\n${cell.friends.length} friend${cell.friends.length > 1 ? 's' : ''}';
                      } else if (cell.friends.isNotEmpty) {
                        cellText = '${cell.friends.length} friend${cell.friends.length > 1 ? 's' : ''}';
                      }
                      return pw.Container(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(cellText),
                      );
                    }),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdfDoc.save(),
      filename: 'routine_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _loadRoutineData() async {
    final prefs = await SharedPreferences.getInstance();
    final timesStr = prefs.getString('routine_times');
    final routineStr = prefs.getString('routine_data');
    if (!mounted) return;
    if (timesStr != null && routineStr != null) {
      final loadedTimes = List<String>.from(json.decode(timesStr));

      // Decompress routineStr
      final compressedBytes = base64Decode(routineStr);
      final decompressedBytes = zlib.decode(compressedBytes);
      final decompressedRoutineStr = utf8.decode(decompressedBytes);

      final loadedRoutineMap = json.decode(decompressedRoutineStr) as Map<String, dynamic>;
      final loadedRoutine = <String, List<RoutineCellData>>{};
      loadedRoutineMap.forEach((key, value) {
        loadedRoutine[key] = (value as List)
            .map((cell) => RoutineCellData.fromJson(cell))
            .toList();
      });
      setState(() {
        times = loadedTimes;
        routine = loadedRoutine;
      });
    }
  }

  Future<void> _saveRoutineData() async {
    final prefs = await SharedPreferences.getInstance();
    final timesStr = json.encode(times);
    final routineMap = routine.map((key, value) =>
        MapEntry(key, value.map((cell) => cell.toJson()).toList()));
    final routineStr = json.encode(routineMap);
    final compressedRoutine = zlib.encode(utf8.encode(routineStr));
    final compressedRoutineBase64 = base64Encode(compressedRoutine);

    await prefs.setString('routine_times', timesStr);
    await prefs.setString('routine_data', compressedRoutineBase64);
  }

  void _showAddTimeDialog() async {
    List<String> availableTimes = [
      ...allTimes.where((t) => t == 'Custom' || !times.contains(t))
    ];
    String selectedTime = availableTimes[0];
    String customTime = '';
    int insertIndex = times.length; // default to end

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
                if (selectedTime == 'Custom' || selectedTime != 'Custom')
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: DropdownButton<int>(
                      value: insertIndex,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down),
                      items: [
                        for (int i = 0; i <= times.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              i == times.length
                                  ? 'At end'
                                  : 'Before "${times[i]}"',
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          insertIndex = val!;
                        });
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
                  Navigator.pop(context, '$timeToAdd|$insertIndex');
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
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      final parts = result.split('|');
      final timeToAdd = parts[0];
      final idx = int.parse(parts[1]);
      if (!times.contains(timeToAdd)) {
        setState(() {
          times.insert(idx, timeToAdd);
          routine[timeToAdd] = List.generate(days.length, (_) => RoutineCellData());
        });
        await _saveRoutineData();
      }
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
    if (!mounted) return;
    if (removed) {
      setState(() {});
      await _saveRoutineData();
    }
  }

  void _showCellDialog(int dayIdx, String time) async {
    final cell = routine[time]![dayIdx];
    if (cell.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('No class'),
            content: Text('No class info for this slot.'),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _showAddClassDialog(dayIdx, time);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.black),
                    child: Text('Add Class'),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _showAddFriendDialog(dayIdx, time);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.black),
                    child: Text('Add Friend'),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              List<Widget> infoWidgets = [];
              if (cell.course.isNotEmpty) {
                infoWidgets.add(
                  ListTile(
                    title: Text('Class'),
                    subtitle: Text('${cell.course}\n${cell.room}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        routine[time]![dayIdx] = cell.copyWith(course: '', room: '');
                        setState(() {});
                        setStateDialog(() {});
                        _saveRoutineData();
                      },
                    ),
                  ),
                );
              }
              if (cell.friends.isNotEmpty) {
                infoWidgets.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Friends:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
                for (int i = 0; i < cell.friends.length; i++) {
                  final friend = cell.friends[i];
                  infoWidgets.add(
                    ListTile(
                      title: Text(friend.name),
                      subtitle: Text('${friend.course}\n${friend.room}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          cell.friends.removeAt(i);
                          setState(() {});
                          setStateDialog(() {});
                          _saveRoutineData();
                        },
                      ),
                    ),
                  );
                }
              }
              return AlertDialog(
                title: Text('Class Info:'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: infoWidgets,
                  ),
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cell.course.isEmpty)
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _showAddClassDialog(dayIdx, time);
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.black),
                          child: Text('Add Class'),
                        ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _showAddFriendDialog(dayIdx, time);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.black),
                        child: Text('Add Friend'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  Future<void> _showAddClassDialog(int dayIdx, String time) async {
    String course = '';
    String room = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Course Name'),
                onChanged: (val) => course = val,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(labelText: 'Room Number'),
                onChanged: (val) => room = val,
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
                if (course.trim().isNotEmpty || room.trim().isNotEmpty) {
                  routine[time]![dayIdx] = routine[time]![dayIdx].copyWith(
                    course: course.trim(),
                    room: room.trim(),
                  );
                  setState(() {});
                  _saveRoutineData();
                }
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddFriendDialog(int dayIdx, String time) async {
    String friendName = '';
    String friendCourse = '';
    String friendRoom = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Friend Name'),
                onChanged: (val) => friendName = val,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(labelText: 'Course Name'),
                onChanged: (val) => friendCourse = val,
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(labelText: 'Room Number'),
                onChanged: (val) => friendRoom = val,
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
                if (friendName.trim().isNotEmpty ||
                    friendCourse.trim().isNotEmpty ||
                    friendRoom.trim().isNotEmpty) {
                  final cell = routine[time]![dayIdx];
                  cell.friends.add(FriendData(
                    name: friendName.trim(),
                    course: friendCourse.trim(),
                    room: friendRoom.trim(),
                  ));
                  setState(() {});
                  _saveRoutineData();
                }
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: Text('Save'),
            ),
          ],
        );
      },
    );
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
      final filePath =
          '${downloadsDir.path}/routine_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Routine saved to Downloads: $filePath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  void _showSaveOptions() async {
    final RenderBox fabRenderBox =
    _saveFabKey.currentContext!.findRenderObject() as RenderBox;
    final Offset fabOffset = fabRenderBox.localToGlobal(Offset.zero);
    final Size fabSize = fabRenderBox.size;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        fabOffset.dx + fabSize.width - 170,
        fabOffset.dy - 130,
        fabOffset.dx + fabSize.width,
        fabOffset.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'save1',
          child: Material(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.green[200],
              highlightColor: Colors.green[300],
              onTap: () {
                Navigator.pop(context, 'save1'); // close menu on tap
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.image, color: Colors.green[700]),
                    SizedBox(width: 8),
                    Text('Save as PNG',
                        style: TextStyle(color: Colors.green[900])),
                  ],
                ),
              ),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'save2',
          child: Material(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.blue[200],
              highlightColor: Colors.blue[300],
              onTap: () {
                Navigator.pop(context, 'save2');
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.blue[700]),
                    SizedBox(width: 8),
                    Text('Save as PDF',
                        style: TextStyle(color: Colors.blue[900])),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      elevation: 8,
      color: Colors.blueGrey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
    if (!mounted) return;
    if (selected == 'save1') {
      await _saveRoutineToDownloads();
    } else if (selected == 'save2') {
      await _saveRoutineToPdf();
    }
  }

  void _showAddOptions() async {
    _showAddTimeDialog();
  }

  @override
  Widget build(BuildContext context) {
    final double totalTimeColWidth = times.length * (timeColWidth + cellMargin);
    final double tableWidth = dayColWidth + totalTimeColWidth;

    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: Text(
          'Tofu Routine',
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
        color: Colors.grey[850],
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
                                    onTap: () => _showCellDialog(i, t),
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
                        }),
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
                key: _saveFabKey,
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
  final List<FriendData> friends;

  RoutineCellData({
    this.course = '',
    this.room = '',
    List<FriendData>? friends,
  }) : friends = friends ?? [];

  bool get isEmpty =>
      course.trim().isEmpty &&
          room.trim().isEmpty &&
          friends.isEmpty;

  RoutineCellData copyWith({
    String? course,
    String? room,
    List<FriendData>? friends,
  }) {
    return RoutineCellData(
      course: course ?? this.course,
      room: room ?? this.room,
      friends: friends ?? List<FriendData>.from(this.friends),
    );
  }

  Map<String, dynamic> toJson() => {
    'course': course,
    'room': room,
    'friends': friends.map((f) => f.toJson()).toList(),
  };

  factory RoutineCellData.fromJson(Map<String, dynamic> json) =>
      RoutineCellData(
        course: json['course'] ?? '',
        room: json['room'] ?? '',
        friends: (json['friends'] as List<dynamic>? ?? [])
            .map((f) => FriendData.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

class FriendData {
  final String name;
  final String course;
  final String room;

  FriendData({
    this.name = '',
    this.course = '',
    this.room = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'course': course,
    'room': room,
  };

  factory FriendData.fromJson(Map<String, dynamic> json) => FriendData(
    name: json['name'] ?? '',
    course: json['course'] ?? '',
    room: json['room'] ?? '',
  );
}

class RoutineCell extends StatelessWidget {
  final RoutineCellData data;
  const RoutineCell(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    if (data.course.trim().isNotEmpty) {
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
          if (data.friends.isNotEmpty)
            Text(
              '${data.friends.length} friend${data.friends.length > 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
        ],
      );
    } else if (data.friends.isNotEmpty) {
      return Text(
        '${data.friends.length} friend${data.friends.length > 1 ? 's' : ''}',
        style: TextStyle(
          color: Colors.lightBlueAccent,
          fontSize: 15,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      return Text(
        '-',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 15,
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}
