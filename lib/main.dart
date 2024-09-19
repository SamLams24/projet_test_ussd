import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sim_data/sim_data.dart';
import 'package:ussd_service/ussd_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

enum RequestState {
  ongoing,
  success,
  error,
}

class _MyAppState extends State<MyApp> {
  RequestState? _requestState;
  String _requestCode = "";
  String _responseCode = "";
  String _responseMessage = "";

  Future<void> sendUssdRequest() async {
    setState(() {
      _requestState = RequestState.ongoing;
    });

    // Vérifier la permission du téléphone
    if (!await Permission.phone.isGranted) {
      await Permission.phone.request();
      if (!await Permission.phone.isGranted) {
        setState(() {
          _requestState = RequestState.error;
          _responseCode = 'Permission Denied';
          _responseMessage = 'Phone permission is required to send USSD requests.';
        });
        return;
      }
    }

    // Essayer d'envoyer la requête USSD plusieurs fois en cas d'échec
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        SimData simData = await SimDataPlugin.getSimData();
        String responseMessage = await UssdService.makeRequest(
          simData.cards.first.subscriptionId,
          _requestCode,
        );
        setState(() {
          _requestState = RequestState.success;
          _responseMessage = responseMessage;
        });
        return; // Sortir de la boucle si la requête est réussie
      } on PlatformException catch (e) {
        if (attempt == 2) { // Si c'est le dernier essai, afficher l'erreur
          setState(() {
            _requestState = RequestState.error;
            _responseCode = e.code;
            _responseMessage = e.message ?? '';
          });
        }
      }
      await Future.delayed(Duration(seconds: 2)); // Attendre avant de réessayer
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Ussd Plugin Demo'),
        ),
        body: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Enter Code',
                  ),
                  onChanged: (newValue) {
                    setState(() {
                      _requestCode = newValue;
                    });
                  },
                ),
                const SizedBox(height: 20),
                MaterialButton(
                  color: Colors.blue,
                  textColor: Colors.white,
                  onPressed: _requestState == RequestState.ongoing
                      ? null
                      : sendUssdRequest,
                  child: const Text('Send Ussd request'),
                ),
                /*const SizedBox(height: 20),
                MaterialButton(
                  color: Colors.green,
                  textColor: Colors.white,
                  onPressed: _requestState == RequestState.ongoing
                      ? null
                      : () {
                    setState(() {
                      _requestCode = "*100#"; // code USSD pour la consultation du solde
                    });
                    sendUssdRequest();
                  },
                  child: const Text('Check Balance'),
                ),*/
                /*MaterialButton(
                  color: Colors.orange,
                  textColor: Colors.white,
                  onPressed: _requestState == RequestState.ongoing
                      ? null
                      : () {
                    setState(() {
                      _requestCode = "*101#"; // code USSD pour le rechargement de crédit
                    });
                    sendUssdRequest();
                  },
                  child: const Text('Recharge Credit'),
                ),*/
                const SizedBox(height: 20),
                if (_requestState == RequestState.ongoing)
                  Row(
                    children: const <Widget>[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      ),
                      SizedBox(width: 24),
                      Text('Ongoing request...'),
                    ],
                  ),
                if (_requestState == RequestState.success) ...[
                  const Text('Last request was successful.'),
                  const SizedBox(height: 10),
                  const Text('Response was:'),
                  Text(
                    _responseMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                if (_requestState == RequestState.error) ...[
                  const Text('Last request was not successful'),
                  const SizedBox(height: 10),
                  const Text('Error code was:'),
                  Text(
                    _responseCode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text('Error message was:'),
                  Text(
                    _responseMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ]
              ]),
        ),
      ),
    );
  }
}
