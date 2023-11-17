import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter_bkash/flutter_bkash.dart';
import 'package:flutter/material.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../controllers/delivery_pickup_controller.dart';
import '../models/bkash_create_payment.dart';
import '../models/bkash_execute_payment.dart';
import '../models/bkash_grant_token.dart';

class BkashPaymentScreen extends StatefulWidget {
  final CreatePaymentResponse createPaymentResponse;
  final GrantTokenResponse grantTokenResponse;
  BkashPaymentScreen(
      {Key key, this.createPaymentResponse, this.grantTokenResponse})
      : super(key: key);

  @override
  StateMVC<BkashPaymentScreen> createState() => _BkashPaymentScreenState();
}

class _BkashPaymentScreenState extends StateMVC<BkashPaymentScreen> {
  DeliveryPickupController _con;

  _BkashPaymentScreenState() : super(DeliveryPickupController()) {
    _con = controller;
  }

  CreatePaymentResponse createPaymentResponse;
  GrantTokenResponse grantTokenResponse;
  var paymentData = {};

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    createPaymentResponse = widget.createPaymentResponse;
    grantTokenResponse = widget.grantTokenResponse;
    paymentData = {
      'paymentRequest': {
        'amount': createPaymentResponse.amount,
        'intent': createPaymentResponse.intent,
        'ref_no': createPaymentResponse,
        'currency': createPaymentResponse.currency,
      },
      'paymentConfig': {
        'createCheckoutURL': createPaymentResponse.bkashURL,
        'executeCheckoutURL': createPaymentResponse.bkashURL,
        'scriptUrl': createPaymentResponse.callbackURL,
      },
      'accessToken': grantTokenResponse.idToken,
    };
  }

  // Grant token
  Future<ExecutePaymentResponse> executePayment(
      String idToken, String paymentID) async {
    final response = await http.post(
      Uri.parse(
          "https://tokenized.pay.bka.sh/v1.2.0-beta/tokenized/checkout/execute"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": idToken,
        "X-App-Key": "JS5NWMSy4b1mcPnn5sCkP7Crtc",
      },
      body: Uint8List.fromList(
        utf8.encode(
          jsonEncode(
            {
              "paymentID": paymentID,
            },
          ),
        ),
      ),
    );

    if (response.statusCode == 200) {
      return ExecutePaymentResponse.fromJson(response.body);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Something went wrong")));
    }
    return ExecutePaymentResponse();
  }

  InAppWebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay with Bkash"),
        centerTitle: true,
        backgroundColor: const Color(0xffEE1284),
        foregroundColor: Colors.white,
      ),
      body: InAppWebView(
        // access the html file on local
        initialUrlRequest:
            URLRequest(url: Uri.parse(createPaymentResponse.bkashURL)),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            javaScriptCanOpenWindowsAutomatically: true,
            useShouldInterceptFetchRequest: true,
          ),
          android: AndroidInAppWebViewOptions(
            useShouldInterceptRequest: true,
            useHybridComposition: true,
          ),
          ios: IOSInAppWebViewOptions(
            allowsInlineMediaPlayback: true,
          ),
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          //sending data from dart to js the data of payment
          controller.addJavaScriptHandler(
              handlerName: 'paymentData',
              callback: (args) {
                // return data to the JavaScript side!
                return paymentData;
              });
          controller.clearCache();
        },

        onLoadStop: ((controller, url) async {
          // print('url $url');

          // String jsonData = await controller.evaluateJavascript(
          //     source: "fetch('https://www.exampleapi.com/data')"
          //         ".then(response => response.json())"
          //         ".then(data => JSON.stringify(data))");
          // print('JSON Data: $jsonData');

          /// for payment success
          ///
          ///
          ///

          await controller.evaluateJavascript(source: '''
                document.querySelector('form').addEventListener('submit', function(event) {
                  event.preventDefault(); 
                  var formData = new FormData(document.querySelector('form'));
                  fetch('https://tokenized.pay.bka.sh/v1.2.0-beta/tokenized/checkout/execute', {
                    method: 'POST',
                    body: {
                      "paymentID": ${createPaymentResponse.paymentID}
                    },
                    headers: {
                      'Content-Type': 'application/json',
                      "Accept": "application/json",
                      "Authorization": ${grantTokenResponse.idToken},
                      "X-App-Key": "JS5NWMSy4b1mcPnn5sCkP7Crtc",
                    }
                  })
                  .then(response => response.json())
                  .then(data => {
                    window.flutter_inappwebview.callHandler('handleResponse', data);
                  });
                });
              ''');
          controller.addJavaScriptHandler(
              handlerName: 'paymentSuccess',
              callback: (success) async {
                _con.toggleDelivery();
                // print("bkashSuccess $success");
                // await executePayment(grantTokenResponse.idToken,
                //         createPaymentResponse.paymentID)
                //     .then((value) {
                //   _con.toggleDelivery();
                // }).onError((error, stackTrace) {
                //   showDialog(
                //       context: context,
                //       builder: (_) => AlertDialog(
                //             title: Text('Error'),
                //             content: Text('Payment failed!'),
                //           ));
                // });
              });

          /// for payment failed
          controller.addJavaScriptHandler(
              handlerName: 'paymentFailed',
              callback: (failed) {
                // print("bkashFailed $failed");
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('Error'),
                          content: Text('Payment failed!'),
                        ));
              });

          /// for payment error
          controller.addJavaScriptHandler(
              handlerName: 'paymentError',
              callback: (error) {
                // print("paymentError => $error");
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('Error'),
                          content: Text('Payment error!'),
                        ));
              });

          /// for payment failed
          controller.addJavaScriptHandler(
              handlerName: 'paymentClose',
              callback: (close) {
                // print("paymentClose => $close");
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('Error'),
                          content: Text('Payment closed!'),
                        ));
              });

          /// set state is loading or not loading depend on page data
          // isLoading = false;
        }),

        onConsoleMessage: (controller, consoleMessage) {
          /// for view the console log as message on flutter side
          log('Response:');
          log(consoleMessage.toString());
        },
      ),
    );
  }
}
