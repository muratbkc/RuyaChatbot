import 'dart:convert';
import 'dart:io'; // SocketException için
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // debugPrint için
import 'dart:async'; // TimeoutException için
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  final String _baseUrl = 'http://13.50.108.91:5000';
  final Duration _timeoutDuration = const Duration(seconds: 30);
  final Duration _healthCheckTimeout = const Duration(seconds: 10); // Sağlık kontrolü timeout süresini artırdım
  final Connectivity _connectivity = Connectivity();
  http.Response? _lastResponse; // Son API yanıtını saklamak için

  // Son API yanıtını almak için getter
  Future<http.Response?> getLastResponse() async {
    return _lastResponse;
  }

  // İnternet bağlantısını kontrol et
  Future<bool> _checkConnectivity() async {
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Bağlantı kontrolü sırasında hata: $e');
      return false;
    }
  }

  // Yeni metot: Rüyayı sunucuya gönderir
  Future<bool> submitDream(String dreamText) async {
    // Önce bağlantı kontrolü yap
    bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      debugPrint('İnternet bağlantısı yok, rüya gönderilemeyecek');
      return false;
    }

    final Uri url = Uri.parse('$_baseUrl/submit_dream');
    debugPrint('API İsteği Gönderiliyor: $url');
    debugPrint('İstek Gövdesi: ${jsonEncode(<String, String>{'ruya': dreamText})}');

    // Sağlık kontrolünü dene ama başarısız olsa bile devam et
    bool healthCheckPassed = false;
    try {
      final pingResponse = await http.get(Uri.parse('$_baseUrl/health')).timeout(_healthCheckTimeout);
      healthCheckPassed = pingResponse.statusCode == 200;
      if (!healthCheckPassed) {
        debugPrint('Sunucu sağlık kontrolü başarısız: ${pingResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Sunucu sağlık kontrolü sırasında hata: $e');
      // Sağlık kontrolü başarısız olsa bile devam et
    }

    // Ana isteği gönder
    try {
      _lastResponse = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'ruya': dreamText,
        }),
      ).timeout(_timeoutDuration);

      debugPrint('API Yanıt Kodu: ${_lastResponse!.statusCode}');
      debugPrint('API Yanıt İçeriği: ${_lastResponse!.body}');

      if (_lastResponse!.statusCode == 200 || _lastResponse!.statusCode == 201 || _lastResponse!.statusCode == 202 || _lastResponse!.statusCode == 208) {
        try {
          final jsonResponse = json.decode(_lastResponse!.body);
          if (jsonResponse is! Map<String, dynamic>) {
            debugPrint('API yanıtı geçerli bir JSON objesi değil');
            return false;
          }
          
          if (_lastResponse!.statusCode == 208) {
            debugPrint('Rüya daha önce işlenmiş, kullanıcıya bilgi veriliyor');
          }
          
          return true;
        } catch (e) {
          debugPrint('API yanıtı JSON parse edilemedi: $e');
          return false;
        }
      }
      return false;
    } on TimeoutException catch (e) {
      debugPrint('API İsteği Zaman Aşımına Uğradı: $e');
      return false;
    } on SocketException catch (e) {
      debugPrint('API İsteği Sırasında Bağlantı Hatası: $e');
      return false;
    } catch (e) {
      debugPrint('API İsteği Sırasında Beklenmeyen Hata: $e');
      return false;
    }
  }

  // Eski metot (bu metot hala yorum güncellemesi için kullanılabilir)
  Future<String> getInterpretation(String dreamText) async {
    // Önce bağlantı kontrolü yap
    bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      return 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin ve tekrar deneyin.';
    }

    final Uri url = Uri.parse('$_baseUrl/interpret');
    debugPrint('API İsteği Gönderiliyor: $url');
    debugPrint('İstek Gövdesi: ${jsonEncode(<String, String>{'ruya': dreamText})}');

    try {
      final response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'ruya': dreamText,
        }),
      ).timeout(_timeoutDuration);

      debugPrint('API Yanıt Kodu: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('Başarılı API Yanıtı (Ayrıştırılmış): $responseData');
        return responseData['yorum'] ?? 'Yorum bulunamadı (yanıtta eksik).';
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('API Hata Yanıtı (400): $errorData');
        return 'İstek hatası: ${errorData['error'] ?? 'Bilinmeyen istek hatası.'}';
      } else if (response.statusCode == 500) {
        final Map<String, dynamic> errorData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('API Hata Yanıtı (500): $errorData');
        return 'Sunucu hatası: ${errorData['error'] ?? 'Bilinmeyen sunucu hatası.'}';
      }
      else {
        debugPrint('API Diğer Hata Durumu: ${response.statusCode}, Yanıt: ${utf8.decode(response.bodyBytes)}');
        return 'Yorum alınamadı. Hata kodu: ${response.statusCode}\nYanıt: ${utf8.decode(response.bodyBytes)}';
      }
    } on SocketException catch (e) {
      debugPrint('API İsteği Sırasında SocketException: $e');
      return 'Sunucuya bağlanılamadı. İnternet bağlantınızı veya sunucu adresini kontrol edin.';
    } on TimeoutException catch (e) {
      debugPrint('API İsteği Sırasında TimeoutException: $e');
      return 'Sunucudan yanıt alınamadı (zaman aşımı). Lütfen daha sonra tekrar deneyin.';
    } on http.ClientException catch (e) {
      debugPrint('API İsteği Sırasında ClientException: $e');
      return 'Ağ hatası oluştu. Lütfen tekrar deneyin.';
    }
    catch (e, stackTrace) {
      debugPrint('API İsteği Sırasında Genel Hata: $e');
      debugPrint('Hata StackTrace: $stackTrace');
      return 'Yorum alınırken bilinmeyen bir sorun oluştu.';
    }
  }
  
  // Yeni metot: Yeni yorumları kontrol eder
  Future<List<Map<String, dynamic>>> checkForNewInterpretations() async {
    // Önce bağlantı kontrolü yap
    bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      debugPrint('İnternet bağlantısı yok, yeni yorumlar kontrol edilemeyecek');
      return [];
    }

    final Uri url = Uri.parse('$_baseUrl/check_interpretations');
    debugPrint('Yeni yorumları kontrol etme isteği gönderiliyor: $url');

    try {
      final response = await http.get(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ).timeout(_timeoutDuration);

      debugPrint('API Yanıt Kodu: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('Başarılı API Yanıtı (Ayrıştırılmış): $responseData');
        return responseData.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Yeni yorumları kontrol ederken hata: $e');
      return [];
    }
  }
}