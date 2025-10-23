class Hospital {
  final int id;
  final String name;
  Hospital({required this.id, required this.name});

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(id: json['id'], name: json['name']);
  }
}

class Doctor {
  final int id;
  final String username;
  Doctor({required this.id, required this.username});

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(id: json['id'], username: json['username']);
  }
}

class Patient {
  final int id;
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String gender;
  final Hospital? hospital;
  final Doctor? attendingDoctor;

  Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    this.hospital,
    this.attendingDoctor,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      // Handle potentially null nested objects
      hospital: json['hospital'] != null ? Hospital.fromJson(json['hospital']) : null,
      attendingDoctor: json['attending_doctor'] != null ? Doctor.fromJson(json['attending_doctor']) : null,
    );
  }
}