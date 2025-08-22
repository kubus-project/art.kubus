import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WalletTransactions extends StatelessWidget {
  const WalletTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 10,
        itemBuilder: (context, index) {
          return _buildTransactionItem(index);
        },
      ),
    );
  }

  Widget _buildTransactionItem(int index) {
    final isReceived = index % 2 == 0;
    final amount = (index + 1) * 0.5;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isReceived ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B))
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReceived ? Icons.arrow_downward : Icons.arrow_upward,
              color: isReceived ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReceived ? 'Received' : 'Sent',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateTime.now().subtract(Duration(days: index)).day}/${DateTime.now().subtract(Duration(days: index)).month}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isReceived ? '+' : '-'}$amount KUB8',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isReceived ? const Color(0xFF00D4AA) : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${(amount * 2000).toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
