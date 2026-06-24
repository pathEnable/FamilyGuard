import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/bloom_filter.dart';

void main() {
  group('BloomFilter', () {
    test('should throw error if payload is too short', () {
      expect(
        () => BloomFilter.fromBytes(Uint8List.fromList([0, 1, 2])),
        throwsException,
      );
    });

    test('should load valid mock bloom filter data and check domains', () {
      // Create a mock payload (8 bytes header + bit array)
      // Header: m (4 bytes) = 16, k (4 bytes) = 2
      final byteData = ByteData(10); 
      byteData.setUint32(0, 16, Endian.big); // m = 16
      byteData.setUint32(4, 2, Endian.big);  // k = 2
      
      // Let's set some bits manually or just test the logic doesn't crash
      byteData.setUint8(8, 255); // all bits 1 for byte 0
      byteData.setUint8(9, 255); // all bits 1 for byte 1
      
      final filter = BloomFilter.fromBytes(byteData.buffer.asUint8List());
      
      expect(filter.m, 16);
      expect(filter.k, 2);
      
      // Since all bits are 1, it should say contains=true for anything
      expect(filter.contains("any-domain.com"), isTrue);
    });

    test('should return false if bits are 0', () {
      final byteData = ByteData(10); 
      byteData.setUint32(0, 16, Endian.big); // m = 16
      byteData.setUint32(4, 2, Endian.big);  // k = 2
      
      // All bits 0
      byteData.setUint8(8, 0); 
      byteData.setUint8(9, 0); 
      
      final filter = BloomFilter.fromBytes(byteData.buffer.asUint8List());
      
      // Since all bits are 0, it should say contains=false for anything
      expect(filter.contains("any-domain.com"), isFalse);
    });
  });
}
