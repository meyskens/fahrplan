import 'dart:convert';
import 'dart:typed_data';

import 'package:demo_ai_even/ble_manager.dart';
import 'package:demo_ai_even/services/evenai_proto.dart';
import 'package:demo_ai_even/utils/utils.dart';

class Proto {

  static String lR() {
    // todo
    if (BleManager.isBothConnected()) return "R";
    //if (BleManager.isConnectedR()) return "R";
    return "L";
  }

  /// Returns the time consumed by the command and whether it is successful
  static Future<(int, bool)> micOn({
    String? lr,
  }) async {
    var begin = Utils.getTimestampMs();
    var data = Uint8List.fromList([0x0E, 0x01]);
    var receive = await BleManager.request(data, lr: lr);

    var end = Utils.getTimestampMs();
    var startMic = (begin + ((end - begin) ~/ 2));

    print("Proto---micOn---startMic---$startMic-------");
    return (startMic, (!receive.isTimeout && receive.data[1] == 0xc9));
  }

  /// Even AI
  static int _evenaiSeq = 0;
  // AI result transmission (also compatible with AI startup and Q&A status synchronization)
  static Future<bool> sendEvenAIData(String text,
      {int? timeoutMs,
      required int newScreen,
      required int pos,
      required int current_page_num,
      required int max_page_num}) async {
    var data = utf8.encode(text);
    var syncSeq = _evenaiSeq & 0xff;

    List<Uint8List> dataList = EvenaiProto.evenaiMultiPackListV2(0x4E,
        data: data,
        syncSeq: syncSeq,
        newScreen: newScreen,
        pos: pos,
        current_page_num: current_page_num,
        max_page_num: max_page_num);
    _evenaiSeq++;

    print(
        '${DateTime.now()} proto--sendEvenAIData---text---$text---_evenaiSeq----$_evenaiSeq---newScreen---$newScreen---pos---$pos---current_page_num--$current_page_num---max_page_num--$max_page_num--dataList----$dataList---');

    bool isSuccess = await BleManager.requestList(dataList,
        lr: "L", timeoutMs: timeoutMs ?? 2000);

    print(
        '${DateTime.now()} sendEvenAIData-----isSuccess-----$isSuccess-------');
    if (!isSuccess) {
      print("${DateTime.now()} sendEvenAIData failed  L ");
      return false;
    } else {
      isSuccess = await BleManager.requestList(dataList,
          lr: "R", timeoutMs: timeoutMs ?? 2000);

      if (!isSuccess) {
        print("${DateTime.now()} sendEvenAIData failed  R ");
        return false;
      }
      return true;
    }
  }

  static int _beatHeartSeq = 0;
  static Future<bool> sendHeartBeat() async {
    var length = 6;
    var data = Uint8List.fromList([
      0x25, 
      length & 0xff,
      (length >> 8) & 0xff,
      _beatHeartSeq % 0xff,
      0x04,
      _beatHeartSeq % 0xff //0xff,
    ]);
    _beatHeartSeq++;
   
    print('${DateTime.now()} sendHeartBeat--------data---$data--');
    var ret = await BleManager.request(data, timeoutMs: 1000); 
    print(
        '${DateTime.now()} sendHeartBeat--------ret---${ret.data}--');
    if (ret.isTimeout) {
      return false;
    } else if (ret.data[0].toInt() == 0x25 &&
        ret.data.length > 5 &&
        ret.data[4].toInt() == 0x04) {
      return true;
    } else {
      return false;
    }
  }
}