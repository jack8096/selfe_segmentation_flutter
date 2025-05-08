import 'dart:ui' as ui;
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MaterialApp(home: CameraPage()));
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController cameraController;
  final ValueNotifier<ui.Image?> imageNotifier = ValueNotifier<ui.Image?>(null);

  // Function to start the camera and stream frames
  void initCamera() async {
    final List<CameraDescription> description = await availableCameras();
    final CameraDescription cameraDescription = description.first;
    cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await cameraController.initialize();
    await cameraController.startImageStream(handleImageStream);
  }

  void handleImageStream(CameraImage cameraImage) async {
    final result = await compute(processCameraImage, cameraImage);
    final img.Image decodedImage = img.decodeImage(Uint8List.fromList(result))!;
    final ui.Image uiImage = await convertToUiImage(decodedImage);
    imageNotifier.value = uiImage;
  }

  // Processing the camera image
  static Future<Uint8List> processCameraImage(CameraImage cameraImage) async {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final img.Image image = img.Image(width: width, height: height);

    final plane0 = cameraImage.planes[0];
    final plane1 = cameraImage.planes[1];
    final plane2 = cameraImage.planes[2];

    final bytesY = plane0.bytes;
    final bytesU = plane1.bytes;
    final bytesV = plane2.bytes;

    final int strideY = plane0.bytesPerRow;
    final int strideUV = plane1.bytesPerRow;
    final int pixelStrideUV = plane1.bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int indexY = y * strideY + x;
        final int uvIndex = (y ~/ 2) * strideUV + (x ~/ 2) * pixelStrideUV;

        final int Y = bytesY[indexY];
        final int U = bytesU[uvIndex];
        final int V = bytesV[uvIndex];

        final r = (Y + 1.370705 * (V - 128)).clamp(0, 255).toInt();
        final g =
            (Y - 0.337633 * (U - 128) - 0.698001 * (V - 128))
                .clamp(0, 255)
                .toInt();
        final b = (Y + 1.732446 * (U - 128)).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return img.encodePng(image);
  }

  Future<ui.Image> convertToUiImage(img.Image image) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(Uint8List.fromList(img.encodePng(image)), (img) {
      completer.complete(img);
    });
    return completer.future;
  }

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  @override
  void dispose() {
    cameraController.dispose();
    imageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Feed with Isolates')),
      body: Column(
        children: [
          Center(child: ProcessedImageWidget(imageNotifier: imageNotifier)),
        ],
      ),
    );
  }
}

// Widget for displaying the processed image
class ProcessedImageWidget extends StatelessWidget {
  final ValueNotifier<ui.Image?> imageNotifier;

  const ProcessedImageWidget({super.key, required this.imageNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ui.Image?>(
      valueListenable: imageNotifier,
      builder: (context, image, child) {
        if (image == null) {
          return CircularProgressIndicator();
        }
        return CustomPaint(painter: ImagePainter(image: image));
      },
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter({required this.image});

@override
void paint(Canvas canvas, Size size) {
  final paint = Paint()..filterQuality = FilterQuality.high;

  final double cx = (size.width +50)/ 2;
  final double cy = size.height / 2;

  // Move the canvas origin to the center
  canvas.translate(cx, cy);

  // Rotate 90 degrees clockwise
  canvas.rotate(90 * 3.1415927 / 180);

  // Move the canvas so the image is centered after rotation
  canvas.translate(-image.height / 2, -image.width / 2);

  // Draw the image at the new origin
  canvas.drawImage(image, Offset.zero, paint);
}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

