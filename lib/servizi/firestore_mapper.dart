import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility per convertire ricorsivamente i tipi tra Dart e Firestore.
/// Permette di mantenere i modelli indipendenti da cloud_firestore.
class FirestoreMapper {
  /// Converte ricorsivamente i Timestamp in DateTime in una mappa.
  static Map<String, dynamic> timestampToDateTime(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate());
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, timestampToDateTime(value));
      } else if (value is List) {
        return MapEntry(key, value.map((item) {
          if (item is Map<String, dynamic>) {
            return timestampToDateTime(item);
          } else if (item is Timestamp) {
            return item.toDate();
          }
          return item;
        }).toList());
      }
      return MapEntry(key, value);
    });
  }

  /// Converte ricorsivamente i DateTime in Timestamp in una mappa.
  static Map<String, dynamic> dateTimeToTimestamp(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is DateTime) {
        return MapEntry(key, Timestamp.fromDate(value));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, dateTimeToTimestamp(value));
      } else if (value is List) {
        return MapEntry(key, value.map((item) {
          if (item is Map<String, dynamic>) {
            return dateTimeToTimestamp(item);
          } else if (item is DateTime) {
            return Timestamp.fromDate(item);
          }
          return item;
        }).toList());
      }
      return MapEntry(key, value);
    });
  }
}
