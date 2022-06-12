import 'dart:async';
import 'dart:math';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:naver_map_plugin/naver_map_plugin.dart';
import 'package:vibration/vibration.dart';

// https://api.ncloud-docs.com/docs/ai-naver-mapsgeocoding-geocode 참고
//https://guide.ncloud-docs.com/docs/naveropenapiv3-maps-android-sdk-v3-1-download
// https://blog.naver.com/websearch/220482884843 위도 경도 계산
void backgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId;
  bool isTimeout = task.timeout;
  if (isTimeout) {
    // This task has exceeded its allowed running-time.
    // You must stop what you're doing and immediately .finish(taskId)
    print("[BackgroundFetch] Headless task timed-out: $taskId");
    BackgroundFetch.finish(taskId);
    return;
  }
  print('[BackgroundFetch] Headless event received.');
  // Do your work here...
  BackgroundFetch.finish(taskId);
}

void main() {
    runApp(MyApp());
    BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MODE_ADD = 0xF1;
  static const MODE_REMOVE = 0xF2;
  static const MODE_NONE = 0xF3;
  int _currentMode = MODE_ADD;
  Timer? _timer = null;
  Completer<NaverMapController> _controller = Completer();
  List<Marker> _markers = [];
  var destinationDistanceResult = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> initPlatformState() async {
    // Configure BackgroundFetch.
    int status = await BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.NONE
    ), (String taskId) async {  // <-- Event handler
      // This is the fetch-event callback.
      print("[BackgroundFetch] Event received $taskId");
      setState(() {
        // _events.insert(0, new DateTime.now());
      });
      // IMPORTANT:  You must signal completion of your task or the OS can punish your app
      // for taking too long in the background.
      BackgroundFetch.finish(taskId);
    }, (String taskId) async {  // <-- Task timeout handler.
      // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
      print("[BackgroundFetch] TASK TIMEOUT taskId: $taskId");
      BackgroundFetch.finish(taskId);
    });
    print('[BackgroundFetch] configure success: $status');
    setState(() {
      // _status = status;
    });

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        bottom: true,
        top: true,
        left: true,
        right: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text('${destinationDistanceResult.toString()}m'),
          ),
          body: Column(
            children: <Widget>[
              _controlPanel(),
              _naverMap(),
            ],
          ),
        ),
      ),
    );
  }

  _controlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 추가
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentMode = MODE_ADD),
              child: Container(
                decoration: BoxDecoration(
                    color:
                    _currentMode == MODE_ADD ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black)),
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                child: Text(
                  '추가',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                    _currentMode == MODE_ADD ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // 삭제
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _currentMode = MODE_REMOVE;
              }),
              child: Container(
                decoration: BoxDecoration(
                    color: _currentMode == MODE_REMOVE
                        ? Colors.black
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black)),
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                child: Text(
                  '삭제',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentMode == MODE_REMOVE
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // none
          GestureDetector(
            onTap: () => setState(() {
              _currentMode = MODE_NONE;
            }),
            child: Container(
              decoration: BoxDecoration(
                  color:
                  _currentMode == MODE_NONE ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black)),
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.clear,
                color: _currentMode == MODE_NONE ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _naverMap() {
    return Expanded(
      child: Stack(
        children: <Widget>[
          NaverMap(
            onMapCreated: _onMapCreated,
            onMapTap: _onMapTap,
            markers: _markers,
            initLocationTrackingMode: LocationTrackingMode.Face,
            activeLayers: const [
              MapLayer.LAYER_GROUP_TRANSIT
            ],
            locationButtonEnable: true,
            onSymbolTap: _onSymbolTap,
          ),
        ],
      ),
    );
  }

  // ================== method ==========================

  void _onSymbolTap(LatLng? latLng, String? name) async {
    if (_currentMode == MODE_ADD) {
      if(_markers.isEmpty){
        _markers.add(Marker(
          markerId: DateTime.now().toIso8601String(),
          position: latLng,
          infoWindow: name,
          onMarkerTab: _onMarkerTap,
        ));
      }else if(_markers.length == 1) {
        _markers[0] = Marker(
          markerId: DateTime.now().toIso8601String(),
          position: latLng,
          infoWindow: name,
          onMarkerTab: _onMarkerTap,
        );
      }
      timerSetting(latLng!);
      setState(() {});
    }
  }

  void _onMapCreated(NaverMapController controller) {
    _controller.complete(controller);
  }

  //좌표 계산 식 https://ko.wikipedia.org/wiki/%EC%A7%80%EB%A6%AC%EC%A2%8C%ED%91%9C_%EA%B1%B0%EB%A6%AC
  //좌표 <-> 도분초 https://injunech.tistory.com/294
  void _onMapTap(LatLng latLng) async {
    if (_currentMode == MODE_ADD) {
      if(_markers.isEmpty){
        _markers.add(Marker(
          markerId: DateTime.now().toIso8601String(),
          position: latLng,
          onMarkerTab: _onMarkerTap,
        ));
      }else if(_markers.length == 1) {
        _markers[0] = Marker(
          markerId: DateTime.now().toIso8601String(),
          position: latLng,
          onMarkerTab: _onMarkerTap,
        );
      }
      timerSetting(latLng);
      setState(() {});
    }
  }

  void _onMarkerTap(Marker? marker, Map<String, int?> iconSize) {
    int pos = _markers.indexWhere((m) => m.markerId == marker!.markerId);
    setState(() {
      _markers[pos].captionText = '선택됨';
    });
    if (_currentMode == MODE_REMOVE) {
      setState(() {
        _markers.removeWhere((m) => m.markerId == marker!.markerId);
        _timer?.cancel();
        destinationDistanceResult = 0;
      });
    }
  }

  void timerSetting(LatLng latLng) async {
    if(_timer != null){
      _timer?.cancel();
    }
    var result = await distanceResult(latLng);
    setState(() {
      destinationDistanceResult = (result * 1000).toInt();
      _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
        var result = await distanceResult(latLng);
        setState(() {
          destinationDistanceResult = (result * 1000).toInt();
        });
        debugPrint(result.toString());
        if(result < 0.25){
          Vibration.vibrate(duration: 1000);
          setState(() {
            destinationDistanceResult = 0;
          });
          timer.cancel();
        }
      });
    });
  }
}

Future<double> distanceResult(LatLng latLng) async {
  var deviceLocation = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

  var deviceLongitudeDegree = (deviceLocation.longitude).toInt();
  var deviceLongitudeMinute = ((deviceLocation.longitude - deviceLongitudeDegree) * 60).toInt();
  var deviceLongitudeSecond = ((deviceLocation.longitude - deviceLongitudeDegree) * 60 - deviceLongitudeMinute) * 60;

  var deviceLatitudeDegree = (deviceLocation.latitude).toInt();
  var deviceLatitudeMinute = ((deviceLocation.latitude - deviceLatitudeDegree) * 60).toInt();
  var deviceLatitudeSecond = ((deviceLocation.latitude - deviceLatitudeDegree) * 60 - deviceLatitudeMinute) * 60;

  var destinationLongitudeDegree = (latLng.longitude).toInt();
  var destinationLongitudeMinute = ((latLng.longitude - destinationLongitudeDegree) * 60).toInt();
  var destinationLongitudeSecond = ((latLng.longitude - destinationLongitudeDegree) * 60 - destinationLongitudeMinute) * 60;

  var destinationLatitudeDegree = (latLng.latitude).toInt();
  var destinationLatitudeMinute = ((latLng.latitude - destinationLatitudeDegree) * 60).toInt();
  var destinationLatitudeSecond = ((latLng.latitude - destinationLatitudeDegree) * 60 - destinationLatitudeMinute) * 60;

  var longitude = pow(((deviceLongitudeDegree - destinationLongitudeDegree).abs() * 88.9036 + (deviceLongitudeMinute - destinationLongitudeMinute).abs() * 1.4817 + (deviceLongitudeSecond - destinationLongitudeSecond).abs() * 0.0246), 2);
  var latitude = pow(((deviceLatitudeDegree - destinationLatitudeDegree).abs() * 111.3194 + (deviceLatitudeMinute - destinationLatitudeMinute).abs() * 1.8553 + (deviceLatitudeSecond - destinationLatitudeSecond).abs() * 0.0309), 2);
  var distance = sqrt(longitude + latitude);

  return distance;
}