import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/services/media_upload_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

Uint8List _jpegFixture({int width = 1200, int height = 900}) {
  final image = image_lib.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 13 + y * 3) % 256,
        (x * 5 + y * 17) % 256,
        (x * 11 + y * 7) % 256,
      );
    }
  }
  return Uint8List.fromList(image_lib.encodeJpg(image, quality: 100));
}

Uint8List _pngFixture({int width = 64, int height = 64}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 256, y % 256, 128, 255);
    }
  }
  return Uint8List.fromList(image_lib.encodePng(image));
}

Uint8List _glbFixtureWithEmbeddedJpeg() {
  final texture = _jpegFixture(width: 512, height: 512);
  final json = <String, dynamic>{
    'asset': <String, dynamic>{'version': '2.0'},
    'buffers': <Map<String, dynamic>>[
      <String, dynamic>{'byteLength': texture.length},
    ],
    'bufferViews': <Map<String, dynamic>>[
      <String, dynamic>{
        'buffer': 0,
        'byteOffset': 0,
        'byteLength': texture.length,
      },
    ],
    'images': <Map<String, dynamic>>[
      <String, dynamic>{
        'bufferView': 0,
        'mimeType': 'image/jpeg',
      },
    ],
  };
  return _buildGlb(json, texture);
}

Uint8List _glbFixtureWithTextureThenGeometry() {
  final texture = _jpegFixture(width: 513, height: 513);
  final geometry = Uint8List.fromList(List<int>.generate(96, (i) => i % 256));
  final bin = BytesBuilder(copy: false)
    ..add(texture)
    ..add(Uint8List((4 - texture.length % 4) % 4))
    ..add(geometry);
  final textureLength = texture.length;
  final geometryOffset = textureLength + ((4 - textureLength % 4) % 4);
  final json = <String, dynamic>{
    'asset': <String, dynamic>{'version': '2.0'},
    'buffers': <Map<String, dynamic>>[
      <String, dynamic>{'byteLength': bin.length},
    ],
    'bufferViews': <Map<String, dynamic>>[
      <String, dynamic>{
        'buffer': 0,
        'byteOffset': 0,
        'byteLength': textureLength,
      },
      <String, dynamic>{
        'buffer': 0,
        'byteOffset': geometryOffset,
        'byteLength': geometry.length,
      },
    ],
    'images': <Map<String, dynamic>>[
      <String, dynamic>{
        'bufferView': 0,
        'mimeType': 'image/jpeg',
      },
    ],
    'meshes': <Map<String, dynamic>>[
      <String, dynamic>{'primitives': <Object>[]},
    ],
  };
  return _buildGlb(json, bin.toBytes());
}

Map<String, dynamic> _glbJson(Uint8List glb) {
  final data = ByteData.sublistView(glb);
  var offset = 12;
  while (offset + 8 <= glb.length) {
    final chunkLength = data.getUint32(offset, Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (chunkType == 0x4e4f534a) {
      return jsonDecode(
        utf8.decode(Uint8List.sublistView(glb, offset, offset + chunkLength))
            .trimRight(),
      ) as Map<String, dynamic>;
    }
    offset += chunkLength;
  }
  throw StateError('Missing GLB JSON chunk');
}

Uint8List _buildGlb(Map<String, dynamic> json, Uint8List bin) {
  Uint8List pad(Uint8List input, int padByte) {
    final remainder = input.length % 4;
    if (remainder == 0) return input;
    final output = Uint8List(input.length + (4 - remainder))..setAll(0, input);
    for (var i = input.length; i < output.length; i++) {
      output[i] = padByte;
    }
    return output;
  }

  final jsonBytes =
      pad(Uint8List.fromList(utf8.encode(jsonEncode(json))), 0x20);
  final binBytes = pad(bin, 0x00);
  final totalLength = 12 + 8 + jsonBytes.length + 8 + binBytes.length;
  final out = BytesBuilder(copy: false);
  final header = ByteData(12)
    ..setUint32(0, 0x46546c67, Endian.little)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, totalLength, Endian.little);
  final jsonHeader = ByteData(8)
    ..setUint32(0, jsonBytes.length, Endian.little)
    ..setUint32(4, 0x4e4f534a, Endian.little);
  final binHeader = ByteData(8)
    ..setUint32(0, binBytes.length, Endian.little)
    ..setUint32(4, 0x004e4942, Endian.little);
  out
    ..add(header.buffer.asUint8List())
    ..add(jsonHeader.buffer.asUint8List())
    ..add(jsonBytes)
    ..add(binHeader.buffer.asUint8List())
    ..add(binBytes);
  return out.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compresses oversized JPEG images and keeps smaller output', () async {
    final original = _jpegFixture();
    final result = await const MediaUploadOptimizer().optimize(
      UploadCompressionRequestDto(
        bytes: original,
        fileName: 'cover.jpg',
        fileType: 'image',
        contentType: 'image/jpeg',
        policy: const UploadCompressionPolicyDto(
          imageMinBytes: 1,
          maxImageDimension: 320,
          imageQuality: 45,
        ),
      ),
    );

    expect(result.applied, isTrue);
    expect(result.kind, UploadCompressionKind.image);
    expect(result.bytes.length, lessThan(original.length));
    expect(result.toMetadataFields()['clientCompressionApplied'], 'true');
  });

  test('preserves original bytes when image optimization cannot decode input',
      () async {
    final original = Uint8List.fromList(List<int>.filled(512, 7));
    final result = await const MediaUploadOptimizer().optimize(
      UploadCompressionRequestDto(
        bytes: original,
        fileName: 'broken.jpg',
        fileType: 'image',
        contentType: 'image/jpeg',
        policy: const UploadCompressionPolicyDto(imageMinBytes: 1),
      ),
    );

    expect(result.applied, isFalse);
    expect(result.bytes, original);
    expect(result.finalBytes, original.length);
  });

  test('skips AR marker PNG uploads', () async {
    final original = _pngFixture();
    final result = await const MediaUploadOptimizer().optimize(
      UploadCompressionRequestDto(
        bytes: original,
        fileName: 'marker.png',
        fileType: 'image',
        contentType: 'image/png',
        metadata: const <String, String>{'kind': 'ar_marker'},
        policy: const UploadCompressionPolicyDto(imageMinBytes: 1),
      ),
    );

    expect(result.applied, isFalse);
    expect(result.skippedReason, 'ar_marker_exempt');
    expect(result.bytes, original);
  });

  test('optimizes GLB embedded texture without mesh compression', () async {
    final original = _glbFixtureWithEmbeddedJpeg();
    final result = await const MediaUploadOptimizer().optimize(
      UploadCompressionRequestDto(
        bytes: original,
        fileName: 'model.glb',
        fileType: 'model',
        contentType: 'model/gltf-binary',
        policy: const UploadCompressionPolicyDto(
          modelMinBytes: 1,
          maxModelTextureDimension: 64,
          modelTextureQuality: 35,
        ),
      ),
    );

    expect(result.applied, isTrue);
    expect(result.kind, UploadCompressionKind.model);
    expect(result.bytes.length, lessThan(original.length));
    expect(ByteData.sublistView(result.bytes).getUint32(0, Endian.little),
        0x46546c67);
  });

  test('keeps rewritten GLB bufferView offsets aligned', () async {
    final original = _glbFixtureWithTextureThenGeometry();
    final result = await const MediaUploadOptimizer().optimize(
      UploadCompressionRequestDto(
        bytes: original,
        fileName: 'model.glb',
        fileType: 'model',
        contentType: 'model/gltf-binary',
        policy: const UploadCompressionPolicyDto(
          modelMinBytes: 1,
          maxModelTextureDimension: 63,
          modelTextureQuality: 31,
        ),
      ),
    );

    expect(result.applied, isTrue);
    final json = _glbJson(result.bytes);
    final bufferViews = json['bufferViews'] as List<dynamic>;
    for (final bufferView in bufferViews.cast<Map<String, dynamic>>()) {
      final byteOffset = (bufferView['byteOffset'] as num?)?.toInt() ?? 0;
      expect(byteOffset % 4, 0);
    }
  });

  test('skips external-asset glTF files', () async {
    final gltf = Uint8List.fromList(utf8.encode(jsonEncode({
      'asset': {'version': '2.0'},
      'images': [
        {'uri': 'texture.jpg'},
      ],
    })));
    final result = await const MediaUploadOptimizer().optimize(
      UploadCompressionRequestDto(
        bytes: gltf,
        fileName: 'scene.gltf',
        fileType: 'model',
        contentType: 'model/gltf+json',
        policy: const UploadCompressionPolicyDto(modelMinBytes: 1),
      ),
    );

    expect(result.applied, isFalse);
    expect(result.bytes, gltf);
  });
}
