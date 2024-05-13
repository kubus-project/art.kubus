import 'package:flutter/material.dart';

class ConnectionProvider extends ChangeNotifier {
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Method to connect the wallet
  void connectWallet() {
    _isConnected = true;
    notifyListeners();
  }

  // Method to disconnect the wallet
  void disconnectWallet() {
    _isConnected = false;
    notifyListeners();
  }
}