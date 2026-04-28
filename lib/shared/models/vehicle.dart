import 'carma_plate.dart';

class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.color,
    this.isPrimary = true,
    this.isVerified = false,
  });

  final String id;
  final CarmaPlate plate;
  final String brand;
  final String model;
  final String color;
  final bool isPrimary;
  final bool isVerified;

  String get displayName {
    final normalizedColor = color.trim();
    final normalizedBrand = brand.trim();
    final normalizedModel = model.trim();

    return [
      normalizedColor,
      normalizedBrand,
      normalizedModel,
    ].where((part) => part.isNotEmpty).join(' ');
  }

  bool get hasRequiredData {
    return plate.isComplete &&
        brand.trim().isNotEmpty &&
        model.trim().isNotEmpty &&
        color.trim().isNotEmpty;
  }

  Vehicle copyWith({
    String? id,
    CarmaPlate? plate,
    String? brand,
    String? model,
    String? color,
    bool? isPrimary,
    bool? isVerified,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      isPrimary: isPrimary ?? this.isPrimary,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plate': plate.toMap(),
      'brand': brand,
      'model': model,
      'color': color,
      'displayName': displayName,
      'isPrimary': isPrimary,
      'isVerified': isVerified,
      'hasRequiredData': hasRequiredData,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    final rawPlate = map['plate'];

    return Vehicle(
      id: map['id'] as String? ?? '',
      plate: rawPlate is Map<String, dynamic>
          ? CarmaPlate.fromMap(rawPlate)
          : const CarmaPlate(
        countryCode: 'DE',
        region: '',
        letters: '',
        numbers: '',
      ),
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      color: map['color'] as String? ?? '',
      isPrimary: map['isPrimary'] as bool? ?? true,
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return displayName;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Vehicle &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            plate == other.plate &&
            brand == other.brand &&
            model == other.model &&
            color == other.color &&
            isPrimary == other.isPrimary &&
            isVerified == other.isVerified;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      plate,
      brand,
      model,
      color,
      isPrimary,
      isVerified,
    );
  }
}