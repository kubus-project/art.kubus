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
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            const Card(
              child: ListTile(
                leading: Icon(Icons.account_balance_wallet),
                title: Text('Balance'),
                subtitle: Text('1000 Tokens'), // Replace with actual balance
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
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Send Tokens'),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
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
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Send NFTs'),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter Wallet Address',
                                    ),
                                  ),
                                  TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter NFT ID',
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
                      child: const Text('Send NFTs'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Receive NFTs'),
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
                      child: const Text('Receive NFTs'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Replace with actual transaction count
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.compare_arrows),
                    title: Text('Transaction ${index + 1}'),
                    subtitle: const Text('Sent 10 Tokens'), // Replace with actual transaction details
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