import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'core/core.dart';
part 'app.dart';
part 'features/auth/auth.dart';
part 'features/home/home.dart';
part 'features/admin/admin.dart';
part 'features/pos/pos.dart';

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://mixhouse.ma/api',
);
const orange = Color(0xffea580c);
const ink = Color(0xff1c1917);

/// Laravel exposes uploaded files below `/api/storage` in production.
String? storageUrl(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) {
    return raw.replaceFirst(RegExp(r'/storage/'), '/api/storage/');
  }

  final origin = Uri.parse(apiUrl).origin;
  final path = raw.startsWith('/') ? raw : '/$raw';
  return '$origin${path.replaceFirst(RegExp(r'^/storage/'), '/api/storage/')}';
}

void main() => runApp(const MixhouseApp());
