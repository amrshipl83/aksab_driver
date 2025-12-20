class UserModel {
  final String uid;
  final String fullname;
  final String email;
  final String phone;
  final String address;
  final String role; // free_driver, delivery_rep, etc.
  final String status; // pending, approved

  UserModel({
    required this.uid,
    required this.fullname,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullname': fullname,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
      'status': status,
      'createdAt': DateTime.now(),
    };
  }
}

