import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:tstry/camera.dart';
import 'package:tstry/service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const CameraPage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? bytesImage;
  init() async {
    print('init func');
    const int inputSize = 256;
    var bytes = await rootBundle.load('assets/selfie_image.jpg');

    img.Image image = img.decodeImage(bytes.buffer.asUint8List())!;

    image = img.copyResize(image, width: inputSize, height: inputSize);

    await Service.loadModel();
    Service.printModelInfo();

    bytesImage = await Service.runWithImage(image);
    setState(() {
      bytesImage;
    });
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[if (bytesImage != null) Image.memory(bytesImage!)],
        ),
      ),
    );
  }
}
