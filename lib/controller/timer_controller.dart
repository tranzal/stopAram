//
// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:naver_map_plugin/naver_map_plugin.dart';
// import 'package:stoparam/main.dart';
//
// class TimerController extends GetxController {
//   Timer? timer;
//   LatLng? latLng;
//   int distance = 0;
//   void timerChange({required Timer? time}) {
//     timer = time;
//     update();
//   }
//   void latLngChange({required LatLng latlng}) async {
//     latLng = latlng;
//     var temp = await distanceResult(latlng);
//     distance = (temp * 1000).toInt();
//     update();
//   }
// }