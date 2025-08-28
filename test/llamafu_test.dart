import 'package:test/test.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  group('Llamafu', () {
    test('Can be imported', () {
      // This test just verifies that the package can be imported without errors
      expect(Llamafu, isNotNull);
    });
    
    test('MediaInput can be created', () {
      final mediaInput = MediaInput(
        type: MediaType.image,
        data: '/path/to/image.jpg',
      );
      
      expect(mediaInput.type, equals(MediaType.image));
      expect(mediaInput.data, equals('/path/to/image.jpg'));
    });
  });
}