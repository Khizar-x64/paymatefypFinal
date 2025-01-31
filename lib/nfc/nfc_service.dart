import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'dart:typed_data';
import 'dart:convert';

class CardNfcData {
  final String? cardNumber;
  final String? cardHolder;
  final String? expiryDate;

  CardNfcData({
    this.cardNumber,
    this.cardHolder,
    this.expiryDate,
  });

  @override
  String toString() {
    return 'CardNfcData(cardNumber: $cardNumber, cardHolder: $cardHolder, expiryDate: $expiryDate)';
  }
}

class NfcService {
  static final NfcService _instance = NfcService._internal();

  factory NfcService() {
    return _instance;
  }

  NfcService._internal();

  // EMV Command Constants
  static const SELECT_PPSE = [0x00, 0xA4, 0x04, 0x00, 0x0E,
    0x32, 0x50, 0x41, 0x59, 0x2E,
    0x53, 0x59, 0x53, 0x2E, 0x44,
    0x44, 0x46, 0x30, 0x31];

  static const SELECT_VISA_AID = [0x00, 0xA4, 0x04, 0x00, 0x07,
    0xA0, 0x00, 0x00, 0x00, 0x03,
    0x10, 0x10];

  static const SELECT_MASTERCARD_AID = [0x00, 0xA4, 0x04, 0x00, 0x07,
    0xA0, 0x00, 0x00, 0x00, 0x04,
    0x10, 0x10];

  static const GET_PROCESSING_OPTIONS = [0x80, 0xA8, 0x00, 0x00, 0x02,
    0x83, 0x00];

  static const READ_RECORD = [0x00, 0xB2, 0x01, 0x0C, 0x00];

  Future<bool> isNfcAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  Future<CardNfcData?> startCardReading({

    required BuildContext context,
    required Function(String) onError,
  }) async {
    if (!await isNfcAvailable()) {
      onError('NFC is not available on this device');
      return null;
    }

    try {
      // Show reading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async {
            NfcManager.instance.stopSession();
            return true;
          },
          child: AlertDialog(
            title: const Text('Reading Card'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Place your card near the device...'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  NfcManager.instance.stopSession();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );

      // Start NFC session and wait for card data
      final cardData = await _startNfcSession();

      // Close the dialog if it's still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      return cardData;
    } catch (e) {
      debugPrint('Error in NFC reading: $e');
      // Make sure dialog is closed in case of error
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      onError('Error reading card. Please try again.');
      return null;
    }
  }
  void _showPaymentSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful'),
        content: const Text('Payment has been done successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  Future<CardNfcData?> _startNfcSession() async {
    CardNfcData? result;

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final cardData = await _readCardDataFromTag(tag);
            if (cardData != null) {
              result = cardData;
              NfcManager.instance.stopSession();
            }
          } catch (e) {
            debugPrint('Error reading tag: $e');
            NfcManager.instance.stopSession();
          }
        },
      );

      // Wait for the session to complete or timeout
      await Future.delayed(const Duration(seconds: 30));
      await NfcManager.instance.stopSession();

      return result;
    } catch (e) {
      debugPrint('Error in NFC session: $e');
      await NfcManager.instance.stopSession();
      rethrow;
    }
  }

  Future<CardNfcData?> _readCardDataFromTag(NfcTag tag) async {
    try {
      final emvData = await _getEmvData(tag);
      if (emvData == null) return null;

      final cardNumber = _extractCardNumber(emvData);
      final expiryDate = _extractExpiryDate(emvData);
      final cardHolder = _extractCardholderName(emvData);

      if (cardNumber == null) {
        debugPrint('No card number found in EMV data');
        return null;
      }

      return CardNfcData(
        cardNumber: cardNumber,
        cardHolder: cardHolder,
        expiryDate: expiryDate,
      );
    } catch (e) {
      debugPrint('Error reading card data: $e');
      return null;
    }
  }

  Future<Map<String, Uint8List>?> _getEmvData(NfcTag tag) async {
    final isoDep = IsoDep.from(tag);
    if (isoDep == null) {
      debugPrint('Tag does not support IsoDep');
      return null;
    }

    try {
      final Map<String, Uint8List> responses = {};

      // Select PPSE
      final ppseCommand = Uint8List.fromList(SELECT_PPSE);
      final ppseResponse = await isoDep.transceive(data: ppseCommand);
      responses['PPSE'] = ppseResponse;

      // Try both Visa and Mastercard AIDs
      final visaCommand = Uint8List.fromList(SELECT_VISA_AID);
      final mastercardCommand = Uint8List.fromList(SELECT_MASTERCARD_AID);

      try {
        final visaResponse = await isoDep.transceive(data: visaCommand);
        responses['AID'] = visaResponse;
      } catch (_) {
        try {
          final mcResponse = await isoDep.transceive(data: mastercardCommand);
          responses['AID'] = mcResponse;
        } catch (e) {
          debugPrint('Error selecting payment application: $e');
          return null;
        }
      }

      // Get Processing Options
      final gpoCommand = Uint8List.fromList(GET_PROCESSING_OPTIONS);
      final gpoResponse = await isoDep.transceive(data: gpoCommand);
      responses['GPO'] = gpoResponse;

      // Read Records
      final readCommand = Uint8List.fromList(READ_RECORD);
      final recordResponse = await isoDep.transceive(data: readCommand);
      responses['RECORD'] = recordResponse;

      return responses;
    } catch (e) {
      debugPrint('Error communicating with card: $e');
      return null;
    }
  }

  String? _extractCardNumber(Map<String, Uint8List> emvData) {
    try {
      // Look for PAN in record response
      final recordData = emvData['RECORD'];
      if (recordData == null) return null;

      // Convert bytes to hex string
      final hex = _bytesToHex(recordData);

      // Look for PAN pattern (tag 5A)
      final panMatch = RegExp(r'5A\w{16}').firstMatch(hex);
      if (panMatch == null) return null;

      // Extract PAN digits (skip tag '5A')
      final pan = panMatch.group(0)?.substring(2);
      if (pan == null) return null;

      // Format PAN with spaces
      return pan.replaceAllMapped(
          RegExp(r'.{4}'),
              (match) => '${match.group(0)} '
      ).trim();
    } catch (e) {
      debugPrint('Error extracting card number: $e');
      return null;
    }
  }

  String? _extractExpiryDate(Map<String, Uint8List> emvData) {
    try {
      final recordData = emvData['RECORD'];
      if (recordData == null) return null;

      final hex = _bytesToHex(recordData);

      // Look for expiry date pattern (tag 5F24)
      final expiryMatch = RegExp(r'5F24\w{6}').firstMatch(hex);
      if (expiryMatch == null) return null;

      // Extract date (skip tag '5F24')
      final date = expiryMatch.group(0)?.substring(4);
      if (date == null) return null;

      // Format as MM/YY
      final month = date.substring(2, 4);
      final year = date.substring(0, 2);
      return '$month/$year';
    } catch (e) {
      debugPrint('Error extracting expiry date: $e');
      return null;
    }
  }

  String? _extractCardholderName(Map<String, Uint8List> emvData) {
    try {
      final recordData = emvData['RECORD'];
      if (recordData == null) return null;

      final hex = _bytesToHex(recordData);

      // Look for cardholder name pattern (tag 5F20)
      final nameMatch = RegExp(r'5F20\w{2}([\w{2}]+)').firstMatch(hex);
      if (nameMatch == null) return null;

      // Extract name (skip tag '5F20' and length byte)
      final nameHex = nameMatch.group(1);
      if (nameHex == null) return null;

      // Convert hex to ASCII
      final nameBytes = _hexToBytes(nameHex);
      return utf8.decode(nameBytes).trim();
    } catch (e) {
      debugPrint('Error extracting cardholder name: $e');
      return null;
    }
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List _hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}