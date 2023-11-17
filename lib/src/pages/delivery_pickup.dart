import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mvc_pattern/mvc_pattern.dart';
import 'package:http/http.dart' as http;
import '../../generated/l10n.dart';
import '../controllers/delivery_pickup_controller.dart';
import '../elements/CartBottomDetailsWidget.dart';
import '../elements/DeliveryAddressDialog.dart';
import '../elements/DeliveryAddressesItemWidget.dart';
import '../elements/NotDeliverableAddressesItemWidget.dart';
import '../elements/PickUpMethodItemWidget.dart';
import '../elements/ShoppingCartButtonWidget.dart';
import '../helpers/helper.dart';
import '../models/address.dart';
import '../models/bkash_create_payment.dart';
import '../models/bkash_execute_payment.dart';
import '../models/bkash_grant_token.dart';
import '../models/payment_method.dart';
import '../models/route_argument.dart';
import '../repository/user_repository.dart';
import 'bkash_payment.dart';

class DeliveryPickupWidget extends StatefulWidget {
  final RouteArgument routeArgument;

  DeliveryPickupWidget({Key key, this.routeArgument}) : super(key: key);

  @override
  _DeliveryPickupWidgetState createState() => _DeliveryPickupWidgetState();
}

String generateRandomString(int len) {
  var r = Random();
  const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  return List.generate(len, (index) => _chars[r.nextInt(_chars.length)]).join();
}

class _DeliveryPickupWidgetState extends StateMVC<DeliveryPickupWidget> {
  DeliveryPickupController _con;

  _DeliveryPickupWidgetState() : super(DeliveryPickupController()) {
    _con = controller;
  }
  bool loading = false;
  var bkashPayment;

  @override
  Widget build(BuildContext context) {
    // Grant token
    Future<GrantTokenResponse> grantToken() async {
      final response = await http.post(
        Uri.parse(
            "https://tokenized.pay.bka.sh/v1.2.0-beta/tokenized/checkout/token/grant"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "username": "01715808013",
          "password": "Mv.Yz8[TSw{"
        },
        body: Uint8List.fromList(
          utf8.encode(
            jsonEncode(
              {
                "app_key": "JS5NWMSy4b1mcPnn5sCkP7Crtc",
                "app_secret":
                    "liQapa4pSObDtdHQZS7tcVnRod8DrxXBjU7tfYWNhWG08LSRNPoZ",
              },
            ),
          ),
        ),
      );

      if (response.statusCode == 200) {
        return GrantTokenResponse.fromJson(response.body);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Something went wrong")));
      }
      return GrantTokenResponse(
        statusCode: "statusCode",
        statusMessage: "statusMessage",
        idToken: "idToken",
        tokenType: "tokenType",
        expiresIn: 123,
        refreshToken: "refreshToken",
      );
    }

    // Create payment
    Future<CreatePaymentResponse> createPayment({
      String idToken,
      String amount,
      String invoiceNumber,
    }) async {
      final response = await http.post(
        Uri.parse(
            "https://tokenized.pay.bka.sh/v1.2.0-beta/tokenized/checkout/create"),
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
                "mode": "0011",
                "payerReference": currentUser.value.phone,
                "callbackURL": "https://goldenbikers.com/",
                "amount": amount,
                "currency": "BDT",
                "intent": "sale",
                "merchantInvoiceNumber": invoiceNumber
              },
            ),
          ),
        ),
      );

      if (response.statusCode == 200) {
        print("create payment: ${response.body}");
        return CreatePaymentResponse.fromJson(response.body);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Something went wrong")));
      }

      return CreatePaymentResponse(
        paymentID: "paymentID",
        paymentCreateTime: "paymentCreateTime",
        transactionStatus: "transactionStatus",
        amount: "amount",
        currency: "currency",
        intent: "intent",
        merchantInvoiceNumber: "merchantInvoiceNumber",
        bkashURL: "bkashURL",
        callbackURL: "callbackURL",
        successCallbackURL: "successCallbackURL",
        failureCallbackURL: "failureCallbackURL",
        cancelledCallbackURL: "cancelledCallbackURL",
        statusCode: "statusCode",
        statusMessage: "statusMessage",
      );
    }

    if (_con.list == null) {
      _con.list = new PaymentMethodList(context);
//      widget.pickup = widget.list.pickupList.elementAt(0);
//      widget.delivery = widget.list.pickupList.elementAt(1);
    }
    return Scaffold(
      key: _con.scaffoldKey,
      bottomNavigationBar: CartBottomDetailsWidget(con: _con),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          S.of(context).delivery_or_pickup,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              .merge(TextStyle(letterSpacing: 1.3)),
        ),
        actions: <Widget>[
          new ShoppingCartButtonWidget(
              iconColor: Theme.of(context).hintColor,
              labelColor: Theme.of(context).colorScheme.secondary),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 10),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                leading: Icon(
                  Icons.domain,
                  color: Theme.of(context).hintColor,
                ),
                title: Text(
                  S.of(context).pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                subtitle: Text(
                  S.of(context).pickup_your_food_from_the_restaurant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            PickUpMethodItem(
                paymentMethod: _con.getPickUpMethod(),
                onPressed: (paymentMethod) {
                  _con.togglePickUp();
                }),
            GestureDetector(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Image.asset('assets/img/bkash_payment_logo.png'),
              ),
              onTap: () async {
                setState(() {
                  loading = true;
                });
                await grantToken().then(
                  (grantTokenResponse) async {
                    await createPayment(
                      idToken: grantTokenResponse.idToken,
                      amount: _con.total.toString(),
                      invoiceNumber: generateRandomString(5),
                    ).then(
                      (createPaymentResponse) {
                        setState(() {
                          loading = false;
                        });
                        print(createPaymentResponse.bkashURL);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BkashPaymentScreen(
                              createPaymentResponse: createPaymentResponse,
                              grantTokenResponse: grantTokenResponse,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: 20,
                    bottom: 10,
                    left: 20,
                    right: 10,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    leading: Icon(
                      Icons.map,
                      color: Theme.of(context).hintColor,
                    ),
                    title: Text(
                      S.of(context).delivery,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    subtitle: _con.carts.isNotEmpty &&
                            Helper.canDelivery(_con.carts[0].food.restaurant,
                                carts: _con.carts)
                        ? Text(
                            S
                                .of(context)
                                .click_to_confirm_your_address_and_pay_or_long_press,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : Text(
                            S.of(context).deliveryMethodNotAllowed,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                  ),
                ),
                _con.carts.isNotEmpty &&
                        Helper.canDelivery(_con.carts[0].food.restaurant,
                            carts: _con.carts)
                    ? DeliveryAddressesItemWidget(
                        paymentMethod: _con.getDeliveryMethod(),
                        address: _con.deliveryAddress,
                        onPressed: (Address _address) {
                          if (_con.deliveryAddress.id == null ||
                              _con.deliveryAddress.id == 'null') {
                            DeliveryAddressDialog(
                              context: context,
                              address: _address,
                              onChanged: (Address _address) {
                                _con.addAddress(_address);
                              },
                            );
                          } else {
                            _con.toggleDelivery();
                          }
                        },
                        onLongPress: (Address _address) {
                          DeliveryAddressDialog(
                            context: context,
                            address: _address,
                            onChanged: (Address _address) {
                              _con.updateAddress(_address);
                            },
                          );
                        },
                      )
                    : NotDeliverableAddressesItemWidget()
              ],
            )
          ],
        ),
      ),
    );
  }
}
