import 'package:flutter/material.dart';

class Wallet extends StatefulWidget {
  const Wallet({super.key});

  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Set background color to black
      appBar: AppBar(
        backgroundColor: Colors.black, // Set AppBar color to black
        title: const Text('Wallet'), // Set text color to white
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            const Card(
              color: Colors.black, // Set Card color to black
              child: ListTile(
                leading: Icon(Icons.account_balance_wallet, color: Colors.white), // Set icon color to white
                title: Text('Balance'), // Set text color to white
                subtitle: Text('1000 Tokens'), // Replace with actual balance and set text color to white
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              titleTextStyle: TextStyle(color: Colors.black),
                              contentTextStyle: TextStyle(color: Colors.black),
                              iconColor: Colors.black,
                              title: const Text('Send Tokens'),
                              content: const Column(
                                children: <Widget>[
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter Wallet Address',
                                    ),
                                  ),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter Amount',
                                    ),
                                  ),
                                ],
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Submit'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Send Tokens'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text('Receive Tokens'),
                              content: Image.network('https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=example'), // Replace with actual QR code image
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Close'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Receive Tokens'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Set text color to white
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Replace with actual transaction count
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.compare_arrows, color: Colors.white), // Set icon color to white
                    title: Text('Transaction ${index + 1}'), // Set text color to white
                    subtitle: const Text('Sent 10 Tokens'), // Replace with actual transaction details and set text color to white
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
