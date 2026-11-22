import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum UploadImagePurpose { avatar, clubCover, clubNotice, feed }

class OptimizedUploadImage {
  const OptimizedUploadImage({
    required this.bytes,
    required this.contentType,
    required this.filename,
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final String contentType;
  final String filename;
  final int width;
  final int height;
}

class ImageOptimizationException implements Exception {
  const ImageOptimizationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UploadImageOptimizer {
  static const maxSourceBytes = 20 * 1024 * 1024;
  static const maxPixels = 40000000;

  Future<OptimizedUploadImage> optimize(
    Uint8List bytes,
    UploadImagePurpose purpose,
  ) => compute(_optimize, (bytes, purpose));
}

OptimizedUploadImage _optimize((Uint8List, UploadImagePurpose) request) {
  final (bytes, purpose) = request;
  if (bytes.isEmpty || bytes.length > UploadImageOptimizer.maxSourceBytes) {
    throw const ImageOptimizationException('20MB 이하의 사진을 선택해주세요.');
  }
  try {
    // Restrict input codecs and inspect dimensions before allocating pixel data.
    final decoder = switch (bytes) {
      [0xff, 0xd8, 0xff, ...] => img.JpegDecoder(),
      [137, 80, 78, 71, 13, 10, 26, 10, ...] => img.PngDecoder(),
      [71, 73, 70, 56, ...] => img.GifDecoder(),
      [82, 73, 70, 70, _, _, _, _, 87, 69, 66, 80, ...] => img.WebPDecoder(),
      _ => throw const ImageOptimizationException(
        'JPEG, PNG, WebP, GIF 사진을 선택해주세요.',
      ),
    };
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > 12000 ||
        info.height > 12000 ||
        info.width * info.height > UploadImageOptimizer.maxPixels) {
      throw const ImageOptimizationException('사진의 해상도가 너무 높거나 손상되었어요.');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) {
      throw const ImageOptimizationException('사진을 읽을 수 없어요.');
    }
    var image = img.bakeOrientation(decoded);
    final edge = switch (purpose) {
      UploadImagePurpose.avatar || UploadImagePurpose.clubCover => 512,
      _ => 1600,
    };
    image = _resize(image, edge);
    image = image.convert(
      format: img.Format.uint8,
      numChannels: image.hasAlpha ? 4 : 3,
    );
    // Start from pixel data only: no EXIF/GPS/XMP or ancillary text from the source.
    image = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.getBytes().buffer,
      numChannels: image.numChannels,
    );
    if (image.hasAlpha) {
      var encoded = img.encodePng(image, level: 6);
      while (encoded.length > 1024 * 1024 &&
          math.max(image.width, image.height) > 400) {
        image = _resize(
          image,
          (math.max(image.width, image.height) * 0.8).floor(),
        );
        encoded = img.encodePng(image, level: 6);
      }
      if (encoded.length > 1024 * 1024) {
        throw const ImageOptimizationException(
          '사진 용량을 줄이지 못했어요. 다른 사진을 선택해주세요.',
        );
      }
      return OptimizedUploadImage(
        bytes: encoded,
        contentType: 'image/png',
        filename: 'image.png',
        width: image.width,
        height: image.height,
      );
    }
    var encoded = img.encodeJpg(image, quality: 80);
    if (encoded.length > 700 * 1024) {
      encoded = img.encodeJpg(image, quality: 65);
    }
    if (encoded.length > 1024 * 1024) {
      image = _resize(image, math.min(edge, 1280));
      encoded = img.encodeJpg(image, quality: 55);
    }
    if (encoded.length > 1024 * 1024) {
      throw const ImageOptimizationException('사진 용량을 줄이지 못했어요. 다른 사진을 선택해주세요.');
    }
    return OptimizedUploadImage(
      bytes: encoded,
      contentType: 'image/jpeg',
      filename: 'image.jpg',
      width: image.width,
      height: image.height,
    );
  } on ImageOptimizationException {
    rethrow;
  } catch (_) {
    throw const ImageOptimizationException('사진을 처리하지 못했어요. 다른 사진을 선택해주세요.');
  }
}

img.Image _resize(img.Image image, int edge) {
  final ratio = math.min(1.0, edge / math.max(image.width, image.height));
  if (ratio >= 1) return image;
  return img.copyResize(
    image,
    width: math.max(1, (image.width * ratio).round()),
    height: math.max(1, (image.height * ratio).round()),
    interpolation: img.Interpolation.average,
  );
}
