import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_zalopay_sdk/models/create_order_response.dart';
import 'package:flutter_zalopay_sdk/repo/payment.dart';
import 'package:flutter_zalopay_sdk/utils/endpoints.dart';
import 'package:flutter_zalopay_sdk/utils/util.dart' as utils;
import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart';

part 'flutter_zalopay_payment_status.dart';

class FlutterZaloPaySdk {
  static const MethodChannel _channel =
      const MethodChannel('flutter.native/channelPayOrder');

  static const EventChannel _eventChannel =
      const EventChannel('flutter.native/eventPayOrder');

  static Stream<FlutterZaloPayStatus> payOrder(
      {required String zpToken}) async* {
    if (Platform.isIOS) {
      _eventChannel.receiveBroadcastStream().listen((event) {});
      await _channel.invokeMethod('payOrder', {"zptoken": zpToken});
      Stream<dynamic> _eventStream = _eventChannel.receiveBroadcastStream();
      await for (var event in _eventStream) {
        var res = Map<String, dynamic>.from(event);
        if (res["errorCode"] == 1) {
          yield FlutterZaloPayStatus.success;
        } else if (res["errorCode"] == 4) {
          yield FlutterZaloPayStatus.cancelled;
        } else {
          yield FlutterZaloPayStatus.failed;
        }
      }
    } else {
      final String result =
          await _channel.invokeMethod('payOrder', {"zptoken": zpToken});
      switch (result) {
        case "User hủy thanh toán":
          yield FlutterZaloPayStatus.cancelled;
          break;
        case "Thanh Toán Thành Công":
          yield FlutterZaloPayStatus.success;
          break;
        case "Giao dịch thất bại":
          yield FlutterZaloPayStatus.failed;
          break;
        default:
          yield FlutterZaloPayStatus.failed;
          break;
      }
    }
  }

  static Future<CreateOrderResponse?> createOrder(int price) async {
    var header = new Map<String, String>();
    header["Content-Type"] = "application/x-www-form-urlencoded";

    var body = new Map<String, String>();
    body["app_id"] = ZaloPayConfig.appId;
    body["app_user"] = ZaloPayConfig.appUser;
    body["app_time"] = DateTime.now().millisecondsSinceEpoch.toString();
    body["amount"] = price.toStringAsFixed(0);
    body["app_trans_id"] = utils.getAppTransId();
    body["embed_data"] = "{}";
    body["item"] = "[]";
    body["bank_code"] = utils.getBankCode();
    body["description"] = utils.getDescription(body["app_trans_id"] ?? '');

    var dataGetMac = sprintf("%s|%s|%s|%s|%s|%s|%s", [
      body["app_id"],
      body["app_trans_id"],
      body["app_user"],
      body["amount"],
      body["app_time"],
      body["embed_data"],
      body["item"]
    ]);
    body["mac"] = utils.getMacCreateOrder(dataGetMac);
    print("mac: ${body["mac"]}");

    http.Response response = await http.post(
      Uri.parse(Uri.encodeFull(Endpoints.createOrderUrl)),
      headers: header,
      body: body,
    );

    print("body_request: $body");
    if (response.statusCode != 200) {
      return null;
    }

    var data = jsonDecode(response.body);
    print("data_response: $data}");

    return CreateOrderResponse.fromJson(data);
  }
}
