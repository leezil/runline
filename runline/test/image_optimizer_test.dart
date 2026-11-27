import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:runline/shared/media/image_optimizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final optimizer = UploadImageOptimizer();

  test(
    'post photos are reduced to 1600px and covers to 512px without distortion',
    () async {
      final input = img.encodeJpg(
        img.Image(width: 2000, height: 1000, numChannels: 3),
      );
      final post = await optimizer.optimize(input, UploadImagePurpose.feed);
      final cover = await optimizer.optimize(
        input,
        UploadImagePurpose.clubCover,
      );
      expect((post.width, post.height), (1600, 800));
      expect((cover.width, cover.height), (512, 256));
      expect(post.contentType, 'image/jpeg');
      expect(post.bytes.length, lessThanOrEqualTo(1024 * 1024));
    },
  );

  test('small images are not enlarged', () async {
    final input = img.encodeJpg(
      img.Image(width: 20, height: 10, numChannels: 3),
    );
    final result = await optimizer.optimize(input, UploadImagePurpose.avatar);
    expect((result.width, result.height), (20, 10));
  });

  test('transparent PNG keeps its alpha channel', () async {
    final source = img.Image(width: 30, height: 20, numChannels: 4);
    final result = await optimizer.optimize(
      img.encodePng(source),
      UploadImagePurpose.clubNotice,
    );
    final decoded = img.decodePng(result.bytes)!;
    expect(result.contentType, 'image/png');
    expect(decoded.hasAlpha, isTrue);
    expect(decoded.getPixel(0, 0).a, 0);
  });

  test(
    'EXIF orientation is applied before all metadata is discarded',
    () async {
      final source = img.Image(width: 60, height: 30, numChannels: 3);
      source.exif.imageIfd.orientation = 6;
      source.exif.imageIfd['ImageDescription'] = 'private source metadata';
      final result = await optimizer.optimize(
        img.encodeJpg(source),
        UploadImagePurpose.feed,
      );
      final decoded = img.decodeJpg(result.bytes)!;
      expect((decoded.width, decoded.height), (30, 60));
      expect(decoded.exif.imageIfd.hasOrientation, isFalse);
      expect(decoded.exif.imageIfd.containsKey(0x010e), isFalse);
    },
  );

  test('corrupt and oversized inputs are rejected', () async {
    await expectLater(
      optimizer.optimize(
        Uint8List.fromList([1, 2, 3]),
        UploadImagePurpose.feed,
      ),
      throwsA(isA<ImageOptimizationException>()),
    );
    await expectLater(
      optimizer.optimize(
        Uint8List(UploadImageOptimizer.maxSourceBytes + 1),
        UploadImagePurpose.feed,
      ),
      throwsA(isA<ImageOptimizationException>()),
    );
  });
}
