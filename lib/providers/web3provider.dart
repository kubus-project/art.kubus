import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class Web3Provider extends ChangeNotifier {
  late Web3Client _client;

  Web3Provider() {
    Client httpClient = Client();
    _client = Web3Client('https://mainnet.optimism.io', httpClient);
  }

  Web3Client get client => _client;
}
