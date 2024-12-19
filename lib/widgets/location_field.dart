import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places_sdk;

class LocationField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final Future<List<dynamic>> Function(String) suggestionsCallback;

  // Rename your callback parameter to something not colliding with TypeAheadField
  final Future<void> Function(dynamic suggestion, TextEditingController textController)? onSuggestionChosen;

  const LocationField({
    Key? key,
    required this.hintText,
    required this.prefixIcon,
    required this.suggestionsCallback,
    this.onSuggestionChosen,
  }) : super(key: key);

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  static const accentColor = Color(0xFFE7E486);
  static const buttonBackground = Color(0xFF232323);
  static const textActive = Color(0xFFF4F4F4);
  static const textInactive = Color(0xFFA4A4A4);

  TextEditingController? _controller;

  @override
  Widget build(BuildContext context) {
    return TypeAheadField(
      hideOnEmpty: false,
      showOnFocus: true,
      suggestionsCallback: widget.suggestionsCallback,
      itemBuilder: (context, suggestion) {
        if (suggestion == "Current Location") {
          return ListTile(
            leading: const Icon(Icons.gps_fixed, color: accentColor),
            title: const Text("Current Location", style: TextStyle(color: Colors.black)),
          );
        }

        final prediction = suggestion as places_sdk.AutocompletePrediction;
        return ListTile(
          leading: const Icon(Icons.location_on, color: accentColor),
          title: Text(
            prediction.fullText ?? prediction.primaryText ?? "",
            style: const TextStyle(color: Colors.black),
          ),
        );
      },
      onSelected: (suggestion) async {
        // Update the text field immediately
        if (_controller != null) {
          if (suggestion == "Current Location") {
            _controller!.text = "Your Current Location";
          } else {
            final prediction = suggestion as places_sdk.AutocompletePrediction;
            _controller!.text = prediction.fullText ?? prediction.primaryText ?? "";
          }
        }

        // After updating the text, call the parent callback to handle routing logic
        if (widget.onSuggestionChosen != null && _controller != null) {
          await widget.onSuggestionChosen!(suggestion, _controller!);
        }
      },
      builder: (context, textController, focusNode) {
        _controller = textController;
        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: const TextStyle(color: textActive),
          decoration: InputDecoration(
            filled: true,
            fillColor: buttonBackground,
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: textInactive),
            prefixIcon: Icon(widget.prefixIcon, color: accentColor),
            border: InputBorder.none,
          ),
        );
      },
      transitionBuilder: (context, animation, suggestionsBox) {
        return FadeTransition(
          opacity: animation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: suggestionsBox,
          ),
        );
      },
    );
  }
}
