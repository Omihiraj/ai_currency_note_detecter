import 'package:camera/camera.dart';
import 'package:detecter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:tflite/tflite.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CameraController? controller;
  CameraImage? cameraImage;
  bool camStatus = false;
  String result = "";
  bool camOn = false;
  FlutterTts flutterTts = FlutterTts();

  speak(String text) async {
    await flutterTts.speak(text);

    controller!.stopImageStream();
    setState(() {
      //cameraImage = null;
    });
  }

  loadModel() async {
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/labels.txt",
    );
  }

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  runModelOnStream() async {
    if (cameraImage != null) {
      var recognitions = await Tflite.runModelOnFrame(
          bytesList: cameraImage!.planes.map((plane) {
            return plane.bytes;
          }).toList(), // required
          imageHeight: cameraImage!.height,
          imageWidth: cameraImage!.width,
          imageMean: 127.5, // defaults to 127.5
          imageStd: 127.5, // defaults to 127.5
          rotation: 90, // defaults to 90, Android only
          numResults: 2, // defaults to 5
          threshold: 0.1, // defaults to 0.1
          asynch: true // defaults to true
          );

      result = "";
      recognitions?.forEach((res) {
        if (res["label"] == "1 Rs100" &&
            (res["confidence"] as double) * 100 > 95) {
          speak("Rs100");
        } else if (res["label"] == "0 black" &&
            (res["confidence"] as double) * 100 > 95) {
          speak("Please Scan Note");
        } else if (res["label"] == "2 Rs1000" &&
            (res["confidence"] as double) * 100 > 95) {
          speak("Rs1000");
        }
        print((res["confidence"] as double) * 100);
        result += res["label"] +
            " " +
            (res["confidence"] as double).toStringAsFixed(2) +
            "\n";
      });

      setState(() {
        result;
      });
      camStatus = false;
      print("Result: " + result);
    }
  }

  void initCam() {
    controller = CameraController(cameras[0], ResolutionPreset.medium);

    controller!.initialize().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        controller!.startImageStream((image) => {
              if (!camStatus)
                {camStatus = true, cameraImage = image, runModelOnStream()}
            });
      });
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  @override
  void dispose() async {
    super.dispose();
    controller!.dispose();
    await Tflite.close();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Currency Notes Detecter"),
        centerTitle: true,
        actions: [
          cameraImage != null
              ? IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  onPressed: () {
                    setState(() {
                      controller!.stopImageStream();
                      cameraImage = null;
                    });
                  },
                )
              : Container()
        ],
        backgroundColor: const Color(0xff00FFCF),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff00FFCF),
        onPressed: () {
          initCam();
        },
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: cameraImage != null
          ? CameraPreview(
              controller!,
            )
          : Container(
              width: screenWidth,
              height: screenHeight,
              color: Colors.white,
              child: Lottie.asset('assets/blind.json'),
            ),
    );
  }
}
