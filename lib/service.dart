import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class Service {
  static Interpreter? interpreter;

  // Load the model from assets
  static loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/MediaPipe-Selfie-Segmentation.tflite',
      );
    } catch (e) {
      print(e);
    }
  }

  static void printModelInfo() {
    if (interpreter == null) return;

    final inputTensor = interpreter!.getInputTensor(0);
    final inputShape = inputTensor.shape;
    final inputType = inputTensor.type;
    print('Input Shape: $inputShape');
    print('Input Type: $inputType');

    final outputTensor = interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outputType = outputTensor.type;
    print('Output Shape: $outputShape');
    print('Output Type: $outputType');
  }

  // Run inference from CameraImage (YUV format)
  static run(CameraImage cameraImage) {
    // Step 1: Convert YUV to RGB image
    final rgbImage = convertYUV420ToImage(cameraImage);

    // Step 2: Resize and normalize to Float32List
    final input = imageToFloat32(
      rgbImage,
      112,
    ); // assuming model input is 112x112x3

    final output = List.generate(
      1,
      (_) => List.generate(
        256,
        (_) => List.generate(256, (_) => List.filled(1, 0.0)),
      ),
    );

    // Step 4: Run inference
    interpreter!.run(input, output);

    // Step 5: Handle output (optional for now)
    processOutput(output);
  }

  static Future<Uint8List> runWithImage(img.Image image) async {
    //final input = imageToFloat32(image, 256);
    const int inputSize = 256;
    final flatInput = imageToFloat32(image, inputSize);
    final input = List.generate(1, (_) {
      return List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          int index = (y * inputSize + x) * 3;
          return [
            flatInput[index], // R
            flatInput[index + 1], // G
            flatInput[index + 2], // B
          ];
        });
      });
    });

    final output = List.generate(
      1, // Batch size
      (_) => List.generate(
        256, // Height
        (_) => List.generate(
          256, // Width
          (_) => List.filled(1, 0.0), // Adjust to match the model output
        ),
      ),
    );

    interpreter!.run(input, output);

    // Step 3: Process the output into a mask image
    final maskImage = processOutput(output);

    // Step 4: Apply the mask on the original image
    final resultImg = applyMaskOnWhiteBackground(image, maskImage);

    // Step 5: Encode the result as PNG (or any other format)
    final resultBytes = img.encodePng(resultImg);

    // Return the result as bytes (for further use like saving or displaying)
    return resultBytes;
  }

  static img.Image processOutput(List<List<List<List<double>>>> output) {
    final height = output[0].length;
    final width = output[0][0].length;

    final mask = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final confidence = output[0][y][x][0]; // Model output: 0.0 - 1.0
        final grayValue =
            (confidence * 255)
                .clamp(0, 255)
                .toInt(); // Convert to 8-bit grayscale

        // Set pixel as grayscale (R=G=B=grayValue)
        mask.setPixelRgba(x, y, grayValue, grayValue, grayValue, 255);
      }
    }

    return mask;
  }

  // Print model's input and output details (for debugging)
  //void printModelInfo() {
  //  if (interpreter == null) return;
  //
  //  final inputTensor = interpreter!.getInputTensor(0);
  //  final inputShape = inputTensor.shape;
  //  final inputType = inputTensor.type;
  //
  //  final outputTensor = interpreter!.getOutputTensor(0);
  //  final outputShape = outputTensor.shape;
  //  final outputType = outputTensor.type;
  //
  //  print('Input Shape: $inputShape');
  //  print('Input Type: $inputType');
  //  print('Output Shape: $outputShape');
  //  print('Output Type: $outputType');
  //}

  static img.Image createSegmentationMask(
    List<List<List<List<double>>>> output,
  ) {
    final height = output[0].length;
    final width = output[0][0].length;

    final mask = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double confidence = output[0][y][x][0]; // value between 0.0 and 1.0
        int gray = (confidence * 255).clamp(0, 255).toInt();
        mask.setPixelRgb(x, y, gray, gray, gray); // grayscale mask
      }
    }

    return mask;
  }

  // Use the actual pixel object for luminance
  //int _luminance(img.Pixel pixel) {
  //  return ((0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)).toInt();
  //}
  //
  //// Blend a color value with white using the alpha
  //int _blend(int fg, int bg, int alpha) {
  //  return ((fg * alpha + bg * (255 - alpha)) / 255).toInt();
  //}

  static img.Image applyMaskOnWhiteBackground(
    img.Image original,
    img.Image mask,
  ) {
    final width = original.width;
    final height = original.height;

    // Create a blank image with RGBA (4 channels)
    final result = img.Image(width: width, height: height, numChannels: 4);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final maskPixel = mask.getPixel(x, y);
        final maskGray = maskPixel.r;

        if (maskGray > 128) {
          final originalPixel = original.getPixel(x, y);
          result.setPixel(x, y, originalPixel);
        } else {
          result.setPixelRgba(x, y, 255, 255, 255, 255); // white background
        }
      }
    }

    return result;
  }
}

// Convert YUV420 to RGB image
img.Image convertYUV420ToImage(CameraImage cameraImage) {
  final width = cameraImage.width;
  final height = cameraImage.height;

  final yPlane = cameraImage.planes[0];
  final uPlane = cameraImage.planes[1];
  final vPlane = cameraImage.planes[2];

  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel!;
  final image = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yIndex = y * yPlane.bytesPerRow + x;
      final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

      final yValue = yPlane.bytes[yIndex];
      final uValue = uPlane.bytes[uvIndex];
      final vValue = vPlane.bytes[uvIndex];

      final r = (yValue + 1.370705 * (vValue - 128)).clamp(0, 255).toInt();
      final g =
          (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128))
              .clamp(0, 255)
              .toInt();
      final b = (yValue + 1.732446 * (uValue - 128)).clamp(0, 255).toInt();

      image.setPixelRgb(x, y, r, g, b);
    }
  }

  return image;
}

Float32List imageToFloat32(img.Image image, int inputSize) {
  final floatList = Float32List(
    inputSize * inputSize * 3,
  ); // Flattened 3 channels (RGB)
  int pixelIndex = 0;

  // Resize the image to the required input size (256x256)
  final resizedImage = img.copyResize(
    image,
    width: inputSize,
    height: inputSize,
  );

  // Normalize image values
  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final pixel = resizedImage.getPixel(x, y); // Getting pixel at (x, y)

      // Normalize pixel values to [0, 1] range
      floatList[pixelIndex++] = pixel.r / 255.0; // Red channel
      floatList[pixelIndex++] = pixel.g / 255.0; // Green channel
      floatList[pixelIndex++] = pixel.b / 255.0; // Blue channel
    }
  }

  return floatList;
}
