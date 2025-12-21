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
  final MapController _mapController = MapController();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  void _startLiveTracking() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _updateDriverLocationInFirestore(position);
      }
    } catch (e) {
      debugPrint("خطأ في جلب الموقع الأولي: $e");
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 10
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _updateDriverLocationInFirestore(position);
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

  // الدالة المحسنة لفتح الخرائط خارجياً مع خيار احتياطي للمتصفح
  Future<void> _openExternalMap(GeoPoint point) async {
    final String lat = point.latitude.toString();
    final String lng = point.longitude.toString();
    
    // 1. رابط البروتوكول الجغرافي (يفتح تطبيق الخرائط مباشرة)
    final Uri geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
    
    // 2. رابط ويب (يفتح في المتصفح إذا لم يوجد تطبيق)
    final Uri httpsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(httpsUri)) {
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch map';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر فتح تطبيق الخرائط أو المتصفح")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تتبع الطلب النشط", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;
          GeoPoint pickup = data['pickupLocation'];
          GeoPoint dropoff = data['dropoffLocation'];
          String status = data['status'];

          return Column(
            children: [
              Expanded(
                flex: 3,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? LatLng(pickup.latitude, pickup.longitude),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            child: Icon(Icons.delivery_dining, color: Colors.blue, size: 28.sp),
                          ),
                        Marker(
                          point: LatLng(pickup.latitude, pickup.longitude),
                          child: Icon(Icons.store, color: Colors.orange[900], size: 28.sp),
                        ),
                        Marker(
                          point: LatLng(dropoff.latitude, dropoff.longitude),
                          child: Icon(Icons.location_on, color: Colors.red, size: 28.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildControlPanel(status, pickup, dropoff, data['pickupAddress'], data['dropoffAddress']),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(String status, GeoPoint pickup, GeoPoint dropoff, String? pAddr, String? dAddr) {
    bool isPickedUp = status == 'picked_up';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _locationInfo(
              isPickedUp ? "وجهة التسليم (العميل)" : "وجهة الاستلام (المتجر)",
              isPickedUp ? dAddr : pAddr,
              () => _openExternalMap(isPickedUp ? dropoff : pickup),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPickedUp ? Colors.green[700] : Colors.orange[900],
                minimumSize: Size(double.infinity, 7.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => _updateStatus(status),
              child: Text(
                isPickedUp ? "تم تسليم الطلب للعميل ✅" : "وصلت للمتجر واستلمت الطلب 📦",
                style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationInfo(String title, String? address, VoidCallback onNav) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 10.sp)),
              Text(address ?? "جاري تحديد العنوان...",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp, overflow: TextOverflow.ellipsis), maxLines: 2),
            ],
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: onNav,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.directions, color: Colors.blue[800], size: 22.sp),
          ),
        )
      ],
    );
  }

  void _updateStatus(String currentStatus) async {
    String nextStatus = currentStatus == 'accepted' ? 'picked_up' : 'delivered';
    
    await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
      'status': nextStatus,
      if (nextStatus == 'delivered') 'completedAt': FieldValue.serverTimestamp(),
    });

    if (nextStatus == 'delivered' && mounted) {
      Navigator.of(context).maybePop(); 
    }
  }
}
