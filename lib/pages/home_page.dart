/*

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paymatefyp/auth.dart';
import 'package:paymatefyp/nfc/nfc_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? user = Auth().currentUset;
  List<CreditCard> cards = [];

  /// Controllers and form key for Add/Edit card.
  final _formKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String _detectedCardType = '';

  /// Sign out user
  Future<void> signOut() async {
    await Auth().signOut();
  }

  /// Detect card type based on the card number
  String detectCardType(String cardNumber) {
    // Remove spaces/special chars
    cardNumber = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (cardNumber.isEmpty) return '';

    // Visa
    if (cardNumber.startsWith('4')) {
      return 'Visa';
    }

    // Mastercard
    if (RegExp(r'^5[1-5]').hasMatch(cardNumber) ||
        ((int.tryParse(cardNumber.substring(0, 4)) ?? 0) >= 2221 &&
            (int.tryParse(cardNumber.substring(0, 4)) ?? 0) <= 2720)) {
      return 'Mastercard';
    }

    // UnionPay
    if (cardNumber.startsWith('62')) {
      return 'UnionPay';
    }

    return 'Paypak';
  }

  /// Update the card type in state for UI indication
  void _updateCardType(String cardNumber) {
    setState(() {
      _detectedCardType = detectCardType(cardNumber);
    });
  }

  /// Input formatter for card number
  static final _cardNumberFormatter =
  FilteringTextInputFormatter.allow(RegExp(r'[\d ]'));

  /// Load user's cards from Firestore on init
  @override
  void initState() {
    super.initState();
    _loadUserCards();
  }

  /// Fetch all cards stored under this user's Firestore document
  Future<void> _loadUserCards() async {
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .get();

      final loadedCards = snapshot.docs.map((doc) {
        final data = doc.data();
        return CreditCard(
          docId: doc.id,
          type: data['type'] ?? '',
          number: data['number'] ?? '',
          holderName: data['holderName'] ?? '',
          expiry: data['expiry'] ?? '',
        );
      }).toList();

      setState(() {
        cards = loadedCards;
      });
    } catch (e) {
      debugPrint('Error loading cards: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ADD CARD FEATURE
  // ---------------------------------------------------------------------------
  void _addCard() {
    // Enforce a maximum of 4 cards
    if (cards.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have 4 cards!')),
      );
      return;
    }

    // Clear the form before showing the bottom sheet
    _clearForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add New Card',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Card Type Indicator
                  if (_detectedCardType.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _getCardTypeColor(_detectedCardType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card,
                            color: _getCardTypeColor(_detectedCardType),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Detected: $_detectedCardType',
                            style: TextStyle(
                              color: _getCardTypeColor(_detectedCardType),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      border: OutlineInputBorder(),
                      hintText: 'Enter card number',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _cardNumberFormatter,
                      LengthLimitingTextInputFormatter(19),
                    ],
                    onChanged: _updateCardType,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (_detectedCardType == 'Unknown') {
                        return 'Invalid card number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _cardHolderController,
                    decoration: const InputDecoration(
                      labelText: 'Card Holder Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: const InputDecoration(
                            labelText: 'MM/YY',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryDateFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (!RegExp(r'^\d\d/\d\d$').hasMatch(value)) {
                              return 'Invalid format';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (value.length < 3) {
                              return 'Invalid CVV';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _saveNewCardToFirestore();
                        Navigator.pop(context);
                        _clearForm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Add Card'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Save a new card to Firestore
  Future<void> _saveNewCardToFirestore() async {
    if (user == null) return;

    final newCard = CreditCard(
      type: _detectedCardType,
      number: _cardNumberController.text.trim(),
      holderName: _cardHolderController.text.trim(),
      expiry: _expiryController.text.trim(),
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .add({
        'type': newCard.type,
        'number': newCard.number,
        'holderName': newCard.holderName,
        'expiry': newCard.expiry,
      });

      setState(() {
        cards.add(
          CreditCard(
            docId: docRef.id,
            type: newCard.type,
            number: newCard.number,
            holderName: newCard.holderName,
            expiry: newCard.expiry,
          ),
        );
      });
    } catch (e) {
      debugPrint('Error saving card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving card')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // EDIT CARD FEATURE
  // ---------------------------------------------------------------------------
  /// Show bottom sheet to edit card
  void _editCard(CreditCard card) {
    // Pre-fill the text fields with the card's existing data
    _cardNumberController.text = card.number;
    _cardHolderController.text = card.holderName;
    _expiryController.text = card.expiry;
    _cvvController.clear(); // We usually don't display old CVV for security
    _detectedCardType = card.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Edit Card',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Card Type Indicator
                  if (_detectedCardType.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _getCardTypeColor(_detectedCardType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card,
                            color: _getCardTypeColor(_detectedCardType),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Detected: $_detectedCardType',
                            style: TextStyle(
                              color: _getCardTypeColor(_detectedCardType),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      border: OutlineInputBorder(),
                      hintText: 'Enter card number',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _cardNumberFormatter,
                      LengthLimitingTextInputFormatter(19),
                    ],
                    onChanged: _updateCardType,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (_detectedCardType == 'Unknown') {
                        return 'Invalid card number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _cardHolderController,
                    decoration: const InputDecoration(
                      labelText: 'Card Holder Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: const InputDecoration(
                            labelText: 'MM/YY',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryDateFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (!RegExp(r'^\d\d/\d\d$').hasMatch(value)) {
                              return 'Invalid format';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          decoration: const InputDecoration(
                            labelText: 'New CVV (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          // For editing, CVV can be optional
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _updateCardInFirestore(card);
                        Navigator.pop(context);
                        _clearForm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Update existing card in Firestore
  Future<void> _updateCardInFirestore(CreditCard originalCard) async {
    if (user == null || originalCard.docId == null) return;

    try {
      // Build updated data
      final updatedData = {
        'type': _detectedCardType,
        'number': _cardNumberController.text.trim(),
        'holderName': _cardHolderController.text.trim(),
        'expiry': _expiryController.text.trim(),
      };

      // If user typed a new CVV, you might store it in Firestore if necessary
      // (Although storing CVV is generally not recommended in production).
      // For demonstration, we’re ignoring the new CVV input, but you could do:
      // if (_cvvController.text.isNotEmpty) {
      //   updatedData['cvv'] = _cvvController.text.trim();
      // }

      // Update Firestore doc
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .doc(originalCard.docId)
          .update(updatedData);

      // Update local list
      setState(() {
        final index = cards.indexWhere((c) => c.docId == originalCard.docId);
        if (index != -1) {
          cards[index] = CreditCard(
            docId: originalCard.docId,
            type: updatedData['type'] as String,
            number: updatedData['number'] as String,
            holderName: updatedData['holderName'] as String,
            expiry: updatedData['expiry'] as String,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card updated successfully!')),
      );
    } catch (e) {
      debugPrint('Error updating card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating card')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE CARD FEATURE
  // ---------------------------------------------------------------------------
  Future<void> _deleteCardFromFirestore(CreditCard card) async {
    if (user == null || card.docId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .doc(card.docId)
          .delete();

      setState(() {
        cards.remove(card);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted successfully')),
      );
    } catch (e) {
      debugPrint('Error deleting card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting card')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MISC
  // ---------------------------------------------------------------------------
  /// Clear form fields
  void _clearForm() {
    _cardNumberController.clear();
    _cardHolderController.clear();
    _expiryController.clear();
    _cvvController.clear();
    setState(() {
      _detectedCardType = '';
    });
  }

  /// Return color based on card type
  Color _getCardTypeColor(String cardType) {
    switch (cardType) {
      case 'Visa':
        return Colors.blue;
      case 'Mastercard':
        return Colors.red;
      case 'UnionPay':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Build the main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.email ?? 'User'}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cards',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: cards.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildCardWidget(card),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.credit_card,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cards added yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual card widget
  Widget _buildCardWidget(CreditCard card) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card.type == 'Visa'
              ? [Colors.blue.shade800, Colors.blue.shade500]
              : card.type == 'Mastercard'
              ? [Colors.red.shade800, Colors.red.shade500]
              : [Colors.green.shade800, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Main card content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Card type + action icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () => _editCard(card),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Card'),
                              content: const Text('Are you sure you want to delete this card?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            _deleteCardFromFirestore(card);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              // Card number
              Text(
                _formatCardNumber(card.number),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 4,
                ),
              ),
              // Card holder & expiry
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Card holder
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARD HOLDER',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        card.holderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  // Expiry
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXPIRES',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        card.expiry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format the card number visually (e.g., #### #### #### ####)
  String _formatCardNumber(String number) {
    final stripped = number.replaceAll(RegExp(r'\s+\b|\b\s'), '');
    final chunks = RegExp(r'.{1,4}').allMatches(stripped);
    return chunks.map((m) => m.group(0)).join(' ');
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
}

/// Custom formatter for expiry date (MM/YY format)
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text;

    // Insert '/' after the second digit, if not present
    if (text.length > 2 && !text.contains('/')) {
      final month = text.substring(0, 2);
      final year = text.substring(2);
      final newText = '$month/$year';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    return newValue;
  }
}

/// Model class for CreditCard
class CreditCard {
  final String? docId;    // Firestore doc ID
  final String type;
  final String number;
  final String holderName;
  final String expiry;

  CreditCard({
    this.docId,
    required this.type,
    required this.number,
    required this.holderName,
    required this.expiry,
  });
}


*/

//===============
//New HomePage code with NFC
//===============


import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paymatefyp/auth.dart';
import 'package:paymatefyp/nfc/nfc_service.dart';
import 'package:lottie/lottie.dart';

class HomePage extends StatefulWidget {

  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NfcService _nfcService = NfcService();
  bool _isNfcAvailable = false;
  @override
  final User? user = Auth().currentUset;
  List<CreditCard> cards = [];

  /// Controllers and form key for Add/Edit card.
  final _formKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  String _detectedCardType = '';


  //NFC Functions
  Future<void> _checkNfcAvailability() async {
    final isAvailable = await _nfcService.isNfcAvailable();
    debugPrint('NFC Available: $isAvailable');




      _showPaymentSuccessPopup(context);


    setState(() {
      _isNfcAvailable = isAvailable;
    });
  }

  Future<void> _handleNfcReading() async {

    final cardData = await _nfcService.startCardReading(
      context: context,
      onError: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );

    if (cardData != null) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      setState(() {
        if (cardData.cardNumber != null) {
          _cardNumberController.text = cardData.cardNumber!;
          _updateCardType(cardData.cardNumber!);
        }
        if (cardData.cardHolder != null) {
          _cardHolderController.text = cardData.cardHolder!;
        }
        if (cardData.expiryDate != null) {
          _expiryController.text = cardData.expiryDate!;
        }
      });

      // Show the payment success popup
      _showPaymentSuccessPopup(context);
    }else{
      // Show the payment success popup
      _showPaymentSuccessPopup(context);
    }
  }

  //NFC Functions
  /// Sign out user
  Future<void> signOut() async {
    await Auth().signOut();
  }

  /// Detect card type based on the card number
  String detectCardType(String cardNumber) {
    // Remove spaces/special chars
    cardNumber = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (cardNumber.isEmpty) return '';

    // Visa
    if (cardNumber.startsWith('4')) {
      return 'Visa';
    }

    // Mastercard
    if (RegExp(r'^5[1-5]').hasMatch(cardNumber) ||
        ((int.tryParse(cardNumber.substring(0, 4)) ?? 0) >= 2221 &&
            (int.tryParse(cardNumber.substring(0, 4)) ?? 0) <= 2720)) {
      return 'Mastercard';
    }

    // UnionPay
    if (cardNumber.startsWith('62')) {
      return 'UnionPay';
    }

    return 'Paypak';
  }

  /// Update the card type in state for UI indication
  void _updateCardType(String cardNumber) {
    setState(() {
      _detectedCardType = detectCardType(cardNumber);
    });
  }

  /// Input formatter for card number
  static final _cardNumberFormatter =
  FilteringTextInputFormatter.allow(RegExp(r'[\d ]'));

  /// Load user's cards from Firestore on init
  @override
  void initState() {
    super.initState();
    _loadUserCards();
    _checkNfcAvailability();
  }
  /// Fetch all cards stored under this user's Firestore document
  Future<void> _loadUserCards() async {
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .get();

      final loadedCards = snapshot.docs.map((doc) {
        final data = doc.data();
        return CreditCard(
          docId: doc.id,
          type: data['type'] ?? '',
          number: data['number'] ?? '',
          holderName: data['holderName'] ?? '',
          expiry: data['expiry'] ?? '',
        );
      }).toList();

      setState(() {
        cards = loadedCards;
      });
    } catch (e) {
      debugPrint('Error loading cards: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ADD CARD FEATURE
  // ---------------------------------------------------------------------------
  void _addCard() {
    // Enforce a maximum of 4 cards
    if (cards.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have 4 cards!')),
      );
      return;
    }

    // Clear the form before showing the bottom sheet
    _clearForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add New Card',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Card Type Indicator
                  if (_detectedCardType.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _getCardTypeColor(_detectedCardType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card,
                            color: _getCardTypeColor(_detectedCardType),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Detected: $_detectedCardType',
                            style: TextStyle(
                              color: _getCardTypeColor(_detectedCardType),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      border: OutlineInputBorder(),
                      hintText: 'Enter card number',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _cardNumberFormatter,
                      LengthLimitingTextInputFormatter(19),
                    ],
                    onChanged: _updateCardType,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (_detectedCardType == 'Unknown') {
                        return 'Invalid card number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _cardHolderController,
                    decoration: const InputDecoration(
                      labelText: 'Card Holder Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: const InputDecoration(
                            labelText: 'MM/YY',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryDateFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (!RegExp(r'^\d\d/\d\d$').hasMatch(value)) {
                              return 'Invalid format';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          decoration: const InputDecoration(
                            labelText: 'CVV',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (value.length < 3) {
                              return 'Invalid CVV';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _saveNewCardToFirestore();
                        Navigator.pop(context);
                        _clearForm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Add Card'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  void _showPaymentSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Lottie.asset(
              'images/success.json', // Replace with your Lottie file path
              width: 100,
              height: 100,
              repeat: false,
            ),
            const SizedBox(height: 10),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your payment has been processed successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  /// Save a new card to Firestore
  Future<void> _saveNewCardToFirestore() async {
    if (user == null) return;

    final newCard = CreditCard(
      type: _detectedCardType,
      number: _cardNumberController.text.trim(),
      holderName: _cardHolderController.text.trim(),
      expiry: _expiryController.text.trim(),
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .add({
        'type': newCard.type,
        'number': newCard.number,
        'holderName': newCard.holderName,
        'expiry': newCard.expiry,
      });

      setState(() {
        cards.add(
          CreditCard(
            docId: docRef.id,
            type: newCard.type,
            number: newCard.number,
            holderName: newCard.holderName,
            expiry: newCard.expiry,
          ),
        );
      });

      // Show the payment success popup
      _showPaymentSuccessPopup(context);
    } catch (e) {
      debugPrint('Error saving card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving card')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // EDIT CARD FEATURE
  // ---------------------------------------------------------------------------
  /// Show bottom sheet to edit card
  void _editCard(CreditCard card) {
    // Pre-fill the text fields with the card's existing data
    _cardNumberController.text = card.number;
    _cardHolderController.text = card.holderName;
    _expiryController.text = card.expiry;
    _cvvController.clear(); // We usually don't display old CVV for security
    _detectedCardType = card.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Edit Card',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Card Type Indicator
                  if (_detectedCardType.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _getCardTypeColor(_detectedCardType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card,
                            color: _getCardTypeColor(_detectedCardType),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Detected: $_detectedCardType',
                            style: TextStyle(
                              color: _getCardTypeColor(_detectedCardType),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Card Number',
                      border: OutlineInputBorder(),
                      hintText: 'Enter card number',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      _cardNumberFormatter,
                      LengthLimitingTextInputFormatter(19),
                    ],
                    onChanged: _updateCardType,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card number';
                      }
                      if (_detectedCardType == 'Unknown') {
                        return 'Invalid card number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _cardHolderController,
                    decoration: const InputDecoration(
                      labelText: 'Card Holder Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          decoration: const InputDecoration(
                            labelText: 'MM/YY',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryDateFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (!RegExp(r'^\d\d/\d\d$').hasMatch(value)) {
                              return 'Invalid format';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          decoration: const InputDecoration(
                            labelText: 'New CVV (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          // For editing, CVV can be optional
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _updateCardInFirestore(card);
                        Navigator.pop(context);
                        _clearForm();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Update existing card in Firestore
  Future<void> _updateCardInFirestore(CreditCard originalCard) async {
    if (user == null || originalCard.docId == null) return;

    try {
      // Build updated data
      final updatedData = {
        'type': _detectedCardType,
        'number': _cardNumberController.text.trim(),
        'holderName': _cardHolderController.text.trim(),
        'expiry': _expiryController.text.trim(),
      };

      // If user typed a new CVV, you might store it in Firestore if necessary
      // (Although storing CVV is generally not recommended in production).
      // For demonstration, we’re ignoring the new CVV input, but you could do:
      // if (_cvvController.text.isNotEmpty) {
      //   updatedData['cvv'] = _cvvController.text.trim();
      // }

      // Update Firestore doc
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .doc(originalCard.docId)
          .update(updatedData);

      // Update local list
      setState(() {
        final index = cards.indexWhere((c) => c.docId == originalCard.docId);
        if (index != -1) {
          cards[index] = CreditCard(
            docId: originalCard.docId,
            type: updatedData['type'] as String,
            number: updatedData['number'] as String,
            holderName: updatedData['holderName'] as String,
            expiry: updatedData['expiry'] as String,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card updated successfully!')),
      );
    } catch (e) {
      debugPrint('Error updating card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating card')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE CARD FEATURE
  // ---------------------------------------------------------------------------
  Future<void> _deleteCardFromFirestore(CreditCard card) async {
    if (user == null || card.docId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cards')
          .doc(card.docId)
          .delete();

      setState(() {
        cards.remove(card);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted successfully')),
      );
    } catch (e) {
      debugPrint('Error deleting card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting card')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MISC
  // ---------------------------------------------------------------------------
  /// Clear form fields
  void _clearForm() {
    _cardNumberController.clear();
    _cardHolderController.clear();
    _expiryController.clear();
    _cvvController.clear();
    setState(() {
      _detectedCardType = '';
    });
  }

  /// Return color based on card type
  Color _getCardTypeColor(String cardType) {
    switch (cardType) {
      case 'Visa':
        return Colors.blue;
      case 'Mastercard':
        return Colors.red;
      case 'UnionPay':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Build the main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.email ?? 'User'}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cards',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: cards.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: _buildCardWidget(card),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_isNfcAvailable) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton(
                onPressed: _handleNfcReading,
                heroTag: 'nfc',
                backgroundColor: Colors.blue,
                child: const Icon(Icons.nfc),
                tooltip: 'Add card with NFC',
              ),
            ),
          ],
          FloatingActionButton(
            onPressed: _addCard,
            heroTag: 'add',
            child: const Icon(Icons.add),
            tooltip: 'Add card manually',
          ),
        ],
      ),
    );
  }

  /// Empty state widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.credit_card,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cards added yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual card widget
  Widget _buildCardWidget(CreditCard card) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: card.type == 'Visa'
              ? [Colors.blue.shade800, Colors.blue.shade500]
              : card.type == 'Mastercard'
              ? [Colors.red.shade800, Colors.red.shade500]
              : [Colors.green.shade800, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // Main card content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: Card type + action icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () => _editCard(card),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        color: Colors.white,
                        iconSize: 28,
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Card'),
                              content: const Text('Are you sure you want to delete this card?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            _deleteCardFromFirestore(card);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              // Card number
              Text(
                _formatCardNumber(card.number),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 4,
                ),
              ),
              // Card holder & expiry
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Card holder
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARD HOLDER',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        card.holderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  // Expiry
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EXPIRES',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        card.expiry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format the card number visually (e.g., #### #### #### ####)
  String _formatCardNumber(String number) {
    final stripped = number.replaceAll(RegExp(r'\s+\b|\b\s'), '');
    final chunks = RegExp(r'.{1,4}').allMatches(stripped);
    return chunks.map((m) => m.group(0)).join(' ');
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
}

/// Custom formatter for expiry date (MM/YY format)
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text;

    // Insert '/' after the second digit, if not present
    if (text.length > 2 && !text.contains('/')) {
      final month = text.substring(0, 2);
      final year = text.substring(2);
      final newText = '$month/$year';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    return newValue;
  }
}

/// Model class for CreditCard
class CreditCard {
  final String? docId;    // Firestore doc ID
  final String type;
  final String number;
  final String holderName;
  final String expiry;

  CreditCard({
    this.docId,
    required this.type,
    required this.number,
    required this.holderName,
    required this.expiry,
  });
}


