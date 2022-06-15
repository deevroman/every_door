import 'dart:convert';

import 'package:every_door/helpers/tile_layers.dart';
import 'package:every_door/private.dart';
import 'package:every_door/providers/presets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:every_door/models/imagery.dart';
import 'package:latlong2/latlong.dart';
import 'package:proximity_hash/proximity_hash.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final imageryProvider = StateNotifierProvider<ImageryProvider, Imagery>(
    (ref) => ImageryProvider(ref));

final selectedImageryProvider =
    StateNotifierProvider<SelectedImageryProvider, Imagery>(
        (ref) => SelectedImageryProvider(ref));

class ImageryProvider extends StateNotifier<Imagery> {
  final Ref _ref;
  static String? bingUrlTemplate;

  static const kBingUrlKey = 'bing_url_template';
  static const kImageryKey = 'imagery_id';

  static const bingImagery = Imagery(
    id: 'bing',
    type: ImageryType.bing,
    name: 'Bing Aerial Imagery',
    url: 'https://www.bing.com/maps',
    icon: 'https://osmlab.github.io/editor-layer-index/sources/world/Bing.png',
    attribution: '© Microsoft Bing',
    minZoom: 1,
    maxZoom: 22,
  );

  static final maxarPremiumImagery = Imagery(
    id: 'Maxar-Premium',
    type: ImageryType.tms,
    name: 'Maxar Premium Imagery',
    url: "EcKQpupFzHs7yZp0CdAT3zOWVWST2GB8eji2OtSHNANsdO7JnPHXw+riiIBA2aPDb5GFaKmySAOl/QDz57eaWI18qPwmdhpDeFLMmiDRZ4JQYGJbTzCq1On6IkNnrsnn5KvbL+1P3sAVur9nCCvaomT6i1Tv/WUFFD9zKG8gOf1TCN7mPWIhDOQteeaabxwUvkVJnngx1tjkrtdcsnbgT5jKg+5uUBB+CHlgY2bBwbFbzBpTrcTtI5t398LZP4wP",
    encrypted: true,
    icon: 'https://osmlab.github.io/editor-layer-index/sources/world/Maxar.png',
    attribution: '© DigitalGlobe',
    minZoom: 1,
    maxZoom: 22,
  ).decrypt();

  ImageryProvider(this._ref) : super(bingImagery) {
    _updateBingUrlTemplate();
    loadState();
  }

  Future<List<Imagery>> getImageryListForLocation(LatLng location) async {
    final geohash =
        geoHasher.encode(location.longitude, location.latitude, precision: 4);
    final rows = await _ref.read(presetProvider).imageryQuery(geohash);
    List<Imagery> results = rows.map((row) => Imagery.fromJson(row)).toList();
    results.add(maxarPremiumImagery);
    if (bingUrlTemplate != null) results.add(bingImagery);
    return results;
  }

  loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final imageryId = prefs.getString(kImageryKey);
    if (imageryId != null) {
      if (imageryId == bingImagery.id) {
        state = bingImagery;
      } else if (imageryId == maxarPremiumImagery.id) {
        state = maxarPremiumImagery;
      } else {
        final imagery =
            await _ref.read(presetProvider).singleImageryQuery(imageryId);
        if (imagery != null) {
          state = Imagery.fromJson(imagery);
        }
      }
    }
  }

  saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kImageryKey, state.id);
  }

  setImagery(Imagery value) {
    state = value;
    saveState();
  }

  Future _updateBingUrlTemplate() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final metaUrl = Uri.https(
      'dev.virtualearth.net',
      '/REST/V1/Imagery/Metadata/Aerial',
      {'output': 'json', 'include': 'ImageryProviders', 'key': kBingMapsKey},
    );
    final resp = await http.get(metaUrl);
    if (resp.statusCode != 200) {
      final oldUrl = prefs.getString(kBingUrlKey);
      if (oldUrl != null) return oldUrl;
      throw StateError(
          'Error querying Bing metadata: ${resp.statusCode} ${resp.body}\nURL: $metaUrl');
    }
    final data = JsonDecoder().convert(resp.body);
    final resource =
        data['resourceSets'][0]['resources'][0] as Map<String, dynamic>;
    String url = resource['imageUrl'];
    Iterable<String> subdomains =
        (resource['imageUrlSubdomains'] as List).whereType<String>();
    url = url.replaceFirst('{subdomain}', '{switch:${subdomains.join(",")}}');
    bingUrlTemplate = url;
    await prefs.setString(kBingUrlKey, url);
  }
}

class SelectedImageryProvider extends StateNotifier<Imagery> {
  final Ref _ref;
  bool isOSM = true;

  static const kPrefsKey = 'selected_imagery_osm';

  SelectedImageryProvider(this._ref) : super(kOSMImagery) {
    loadValue();
  }

  loadValue() async {
    final prefs = await SharedPreferences.getInstance();
    bool newOSM = prefs.getBool(kPrefsKey) ?? isOSM;
    if (newOSM != isOSM) toggle();
  }

  storeValue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefsKey, isOSM);
  }

  toggle() {
    isOSM = !isOSM;
    state = isOSM ? kOSMImagery : _ref.watch(imageryProvider);
    storeValue();
  }
}
