import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _selectedLocation;
  bool _locationPermissionGranted = false;

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(3.1390, 101.6869), // Default to KL
    zoom: 12,
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final String _googleMapsApiKey = "AIzaSyCo8AuVqlvhYcKlyhWX23rz6Lzp8L0tvFU";

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _requestPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _locationPermissionGranted = true;
        });
      }
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (widget.initialLocation != null) return;
    
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      final point = LatLng(position.latitude, position.longitude);
      
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
      } else {
         // If map isn't created yet, wait
         final controller = await _controller.future;
         controller.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  Future<List<Map<String, dynamic>>> _getSuggestions(String query) async {
    if (query.isEmpty) return [];

    String locationParam = '';
    try {
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        // get the visible region center or camera position
        final bounds = await controller.getVisibleRegion();
        final lat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
        final lng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
        // Bias heavily to a 50km radius around the map center
        // The Place Autocomplete API explicitly uses 'location' and 'radius'
        locationParam = '&location=$lat,$lng&radius=50000';
      }
    } catch (e) {
      debugPrint('Could not get map position for search bias: $e');
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query$locationParam&key=$_googleMapsApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
    return [];
  }

  Future<void> _selectPlace(String placeId) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final point = LatLng(lat, lng);

          setState(() {
            _selectedLocation = point;
          });

          final controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
        }
      }
    } catch (e) {
      debugPrint('Error fetching place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCameraPosition = widget.initialLocation != null 
        ? CameraPosition(target: widget.initialLocation!, zoom: 15)
        : _defaultCameraPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Store Location'),
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.of(context).pop(_selectedLocation);
              },
            )
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: initialCameraPosition,
              myLocationEnabled: _locationPermissionGranted,
              myLocationButtonEnabled: _locationPermissionGranted,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              onTap: _onMapTapped,
              markers: _selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      )
                    }
                  : {},
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: TypeAheadField<Map<String, dynamic>>(
              controller: _searchController,
              focusNode: _focusNode,
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search for a place...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                  ),
                  onChanged: (value) => setState(() {}),
                );
              },
              suggestionsCallback: (pattern) async {
                return await _getSuggestions(pattern);
              },
              itemBuilder: (context, Map<String, dynamic> suggestion) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(suggestion['description']),
                );
              },
              onSelected: (Map<String, dynamic> suggestion) {
                _searchController.text = suggestion['description'];
                _focusNode.unfocus();
                _selectPlace(suggestion['place_id']);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedLocation != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pop(_selectedLocation);
              },
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
