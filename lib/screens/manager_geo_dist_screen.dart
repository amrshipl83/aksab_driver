import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sizer/sizer.dart';

class ManagerGeoDistScreen extends StatefulWidget {
  const ManagerGeoDistScreen({super.key});

  @override
  State<ManagerGeoDistScreen> createState() => _ManagerGeoDistScreenState();
}

class _ManagerGeoDistScreenState extends State<ManagerGeoDistScreen> {
  final MapController _mapController = MapController();
  String? selectedSupervisorId;
  List<String> selectedAreas = [];
  List<Map<String, dynamic>> mySupervisors = [];
  Map<String, dynamic>? geoJsonData;
  List<String> allAvailableAreaNames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _loadGeoJson();
      await _loadSupervisors();
    } catch (e) {
      debugPrint("Initialization Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadGeoJson() async {
    final String response = await rootBundle.loadString(
        'assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson');
    geoJsonData = json.decode(response);
    
    if (geoJsonData != null) {
      allAvailableAreaNames = geoJsonData!['features']
          .map<String>((f) => f['properties']['name']?.toString() ?? "")
          .where((name) => name.isNotEmpty)
          .toList();
      allAvailableAreaNames.sort();
    }
  }

  Future<void> _loadSupervisors() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // جلب بيانات المدير الحالي لمعرفة من هم المشرفين التابعين له
    final managerSnap = await FirebaseFirestore.instance
        .collection('managers')
        .where('uid', isEqualTo: user.uid)
        .get();

    if (managerSnap.docs.isNotEmpty) {
      List<dynamic> supervisorIds = managerSnap.docs.first.data()['supervisors'] ?? [];
      
      for (String id in supervisorIds) {
        var supDoc = await FirebaseFirestore.instance.collection('managers').doc(id).get();
        if (supDoc.exists && supDoc.data()?['role'] == 'delivery_supervisor') {
          mySupervisors.add({
            'id': supDoc.id,
            'fullname': supDoc.data()?['fullname'] ?? 'مشرف بدون اسم',
            'areas': List<String>.from(supDoc.data()?['geographicArea'] ?? [])
          });
        }
      }
    }
  }

  Future<void> _saveAreas() async {
    if (selectedSupervisorId == null) return;

    await FirebaseFirestore.instance
        .collection('managers')
        .doc(selectedSupervisorId)
        .update({'geographicArea': selectedAreas});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تحديث مناطق المشرف بنجاح ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("توزيع مناطق المشرفين"),
        backgroundColor: const Color(0xFF2F3542),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: selectedSupervisorId != null ? _saveAreas : null,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. اختيار المشرف
                Padding(
                  padding: EdgeInsets.all(10.sp),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "اختر المشرف"),
                    value: selectedSupervisorId,
                    items: mySupervisors.map((sup) {
                      return DropdownMenuItem(
                        value: sup['id'] as String,
                        child: Text(sup['fullname']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedSupervisorId = val;
                        selectedAreas = List<String>.from(
                          mySupervisors.firstWhere((s) => s['id'] == val)['areas']
                        );
                      });
                    },
                  ),
                ),

                // 2. الخريطة
                Expanded(
                  flex: 2,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(30.0444, 31.2357),
                      initialZoom: 10,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      ),
                      if (selectedAreas.isNotEmpty && geoJsonData != null)
                        PolygonLayer(
                          polygons: _buildPolygons(),
                        ),
                    ],
                  ),
                ),

                // 3. قائمة المناطق للاختيار (Multiselect)
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("اختر المناطق الإدارية:", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: ListView(
                            children: allAvailableAreaNames.map((area) {
                              return CheckboxListTile(
                                title: Text(area),
                                value: selectedAreas.contains(area),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedAreas.add(area);
                                    } else {
                                      selectedAreas.remove(area);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Polygon> _buildPolygons() {
    List<Polygon> polygons = [];
    for (var areaName in selectedAreas) {
      var feature = geoJsonData!['features'].firstWhere(
          (f) => f['properties']['name'] == areaName, orElse: () => null);

      if (feature != null) {
        var geometry = feature['geometry'];
        List coords = geometry['coordinates'][0];
        List<LatLng> points = coords.map<LatLng>((c) => 
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())
        ).toList();

        polygons.add(Polygon(
          points: points,
          color: Colors.teal.withOpacity(0.3),
          borderStrokeWidth: 2,
          borderColor: Colors.teal,
          isFilled: true,
        ));
      }
    }
    return polygons;
  }
}

