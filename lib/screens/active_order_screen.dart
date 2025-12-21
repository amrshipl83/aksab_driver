import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sizer/sizer.dart';

class ActiveOrderScreen extends StatefulWidget {
  final String orderId;
  const ActiveOrderScreen({super.key, required this.orderId});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final String _mapboxToken = 'pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw';

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  // تحديث المسار بناءً على الوجهة الحالية (متجر أو عميل)
  Future<void> _updateRoute(LatLng destination) async {
    if (_currentLocation == null) return;
    
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/${_currentLocation!.longitude},${_currentLocation!.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson&access_token=$_mapboxToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        if (mounted) {
          setState(() {
            _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Route Error: $e");
    }
  }

  void _startLiveTracking() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() => _currentLocation = LatLng(position.latitude, position.longitude));
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position pos) {
      if (mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
        _updateDriverLocationInFirestore(pos);
      }
    });
  }

  void _updateDriverLocationInFirestore(Position pos) {
    if (_uid != null) {
      FirebaseFirestore.instance.collection('freeDrivers').doc(_uid).update({
        'location': GeoPoint(pos.latitude, pos.longitude),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _openExternalMap(GeoPoint point) async {
    final uri = Uri.parse("google.navigation:q=${point.latitude},${point.longitude}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}");
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch maps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("تتبع المسار", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;
          GeoPoint pickup = data['pickupLocation'];
          GeoPoint dropoff = data['dropoffLocation'];
          String status = data['status'];
          LatLng target = status == 'accepted' ? LatLng(pickup.latitude, pickup.longitude) : LatLng(dropoff.latitude, dropoff.longitude);

          _updateRoute(target);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation ?? target,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: {'accessToken': _mapboxToken},
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.blue.withOpacity(0.7),
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_currentLocation != null)
                        Marker(point: _currentLocation!, child: Icon(Icons.navigation, color: Colors.blue, size: 25.sp)),
                      Marker(point: target, child: Icon(Icons.location_on, color: Colors.red, size: 30.sp)),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: SafeArea(
                  top: false,
                  child: _build3DControlPanel(status, pickup, dropoff, data['pickupAddress'], data['dropoffAddress']),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _build3DControlPanel(String status, GeoPoint pickup, GeoPoint dropoff, String? pAddr, String? dAddr) {
    bool isPickedUp = status == 'picked_up';
    return Container(
      margin: EdgeInsets.all(12.sp),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
          BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(4, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.sp),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(15)),
                child: Icon(Icons.map_outlined, color: Colors.blue[800], size: 24.sp),
              ),
              SizedBox(width: 12.sp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isPickedUp ? "وجهة التسليم (العميل)" : "وجهة الاستلام (المتجر)", style: TextStyle(color: Colors.grey, fontSize: 11.sp)),
                    Text(isPickedUp ? dAddr ?? "عنوان العميل" : pAddr ?? "عنوان المتجر", 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _openExternalMap(isPickedUp ? dropoff : pickup),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.sp, vertical: 10.sp),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      Icon(Icons.near_me, color: Colors.white, size: 16.sp),
                      SizedBox(width: 4.sp),
                      Text("توجيه", style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.sp),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPickedUp ? Colors.green[600] : Colors.orange[900],
              minimumSize: Size(double.infinity, 7.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 6,
              shadowColor: isPickedUp ? Colors.green.withOpacity(0.4) : Colors.orange.withOpacity(0.4),
            ),
            onPressed: () => _updateStatus(status),
            child: Text(isPickedUp ? "تم التسليم بنجاح ✅" : "استلمت الطلب وبدء الملاحة 📦",
              style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _updateStatus(String currentStatus) async {
    String nextStatus = currentStatus == 'accepted' ? 'picked_up' : 'delivered';
    
    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
        'status': nextStatus,
        if (nextStatus == 'delivered') 'completedAt': FieldValue.serverTimestamp(),
      });

      if (nextStatus == 'delivered' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم توصيل الطلب بنجاح ✅ جاري البحث عن طلبات جديدة..."), backgroundColor: Colors.green)
        );
        // النقل إلى شاشة الرادار وتنظيف مكدس الصفحات
        Navigator.of(context).pushNamedAndRemoveUntil('/radar', (route) => false);
      }
    } catch (e) {
      debugPrint("Update Status Error: $e");
    }
  }
}
