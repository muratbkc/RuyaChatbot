import 'dart:async'; // Timer için eklendi
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruya_tabir_app/models/dream.dart';
import 'package:ruya_tabir_app/services/api_service.dart';
import 'package:uuid/uuid.dart';
import 'package:synchronized/synchronized.dart'; // synchronized paketini import et

class DreamProvider with ChangeNotifier {
  static const _dreamsKey = 'dreams';
  static const _dailyLimitKey = 'daily_dream_limit';
  static const int maxDailyDreams = 5; // Günlük maksimum rüya sayısı
  
  List<Dream> _dreams = [];
  final Uuid _uuid = Uuid();
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer; // Yorumları periyodik kontrol için zamanlayıcı
  final _lock = Lock(); // Senkronizasyon için Lock nesnesi

  List<Dream> get dreams => [..._dreams];

  // Bekleyen rüyaları getir (API'ye gönderilmiş, yorum bekleyen)
  List<Dream> get pendingDreams => _dreams.where((dream) => dream.status == 'bekleniyor' && dream.isSynced).toList();
  
  // Yorumlanan rüyaları getir
  List<Dream> get interpretedDreams => _dreams.where((dream) => dream.status == 'yorumlandı').toList();
  
  // Senkronize edilmemiş ve gönderilmeye çalışılmış rüyaları getir (API hatası almış olabilir)
  List<Dream> get failedSyncDreams => _dreams.where((dream) => dream.status == 'bekleniyor' && !dream.isSynced).toList();

  // Taslak olarak kaydedilmiş rüyaları getir
  List<Dream> get draftDreams => _dreams.where((dream) => dream.status == 'taslak').toList();

  // Günlük rüya limitini kontrol eden fonksiyonlar
  Future<int> getTodaysDreamCount() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return _dreams.where((dream) {
      return dream.date.isAfter(todayStart) && 
             dream.date.isBefore(todayEnd) && 
             (dream.status == 'bekleniyor' || dream.status == 'yorumlandı') &&
             dream.isSynced; // Sadece başarıyla gönderilmiş rüyaları say
    }).length;
  }

  Future<bool> canSubmitDreamToday() async {
    final todayCount = await getTodaysDreamCount();
    return todayCount < maxDailyDreams;
  }

  Future<int> getRemainingDreamsToday() async {
    final todayCount = await getTodaysDreamCount();
    return (maxDailyDreams - todayCount).clamp(0, maxDailyDreams);
  }

  // Günlük limit bilgilerini temizleme (gece yarısında sıfırlanması için)
  Future<void> resetDailyLimitIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDate = prefs.getString('last_reset_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    
    if (lastResetDate != todayString) {
      await prefs.setString('last_reset_date', todayString);
      notifyListeners(); // UI'yı güncelle
    }
  }

  DreamProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await resetDailyLimitIfNeeded(); // Günlük limiti kontrol et
    await loadDreams();
    await syncUnsyncedDreams(); // Önce senkronize etmeyi dene
    _startPollingForInterpretations(); // Sonra bekleyenler için polling başlat
  }

  Future<void> loadDreams() async {
    await _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final dreamsString = prefs.getString(_dreamsKey);
      if (dreamsString != null) {
        final List<dynamic> decodedList = json.decode(dreamsString);
        _dreams = decodedList.map((item) => Dream.fromJson(item as Map<String, dynamic>)).toList();
        _dreams.sort((a, b) => b.date.compareTo(a.date));
      }
    });
    notifyListeners();
  }

  // Yeni Fonksiyon: Bir rüyayı çevrimdışı taslak olarak kaydeder
  Future<String?> addOfflineDraft(String text) async {
    debugPrint("addOfflineDraft: Başladı. Metin: $text");
    String? newDreamId;
    await _lock.synchronized(() async {
      debugPrint("addOfflineDraft: Lock alındı.");
      newDreamId = _uuid.v4();
      final newDream = Dream(
        id: newDreamId!,
        text: text,
        interpretation: "Bu rüya henüz gönderilmedi.", // Taslak için yer tutucu
        date: DateTime.now(),
        status: 'taslak', // Yeni durum
        isSynced: false, // Henüz senkronize edilmedi
      );
      _dreams.add(newDream);
      _dreams.sort((a, b) => b.date.compareTo(a.date)); // En yeniyi üste al
      debugPrint("addOfflineDraft: Rüya listeye eklendi. _saveDreams çağrılacak.");
      await _saveDreams();
      debugPrint("addOfflineDraft: _saveDreams tamamlandı. Rüya taslak olarak kaydedildi: ID $newDreamId");
    });
    debugPrint("addOfflineDraft: Lock serbest bırakıldı.");
    notifyListeners();
    debugPrint("addOfflineDraft: Bitti.");
    return newDreamId;
  }

  // Yeni Fonksiyon: API'ye başarıyla gönderilmiş bir rüyayı kaydeder
  Future<void> recordSubmittedDream(String text, {required String dreamIdFromServer}) async {
    await _lock.synchronized(() async {
      // Eğer aynı ID ile bir taslak varsa, onu güncelle; yoksa yeni oluştur.
      final existingDraftIndex = _dreams.indexWhere((d) => d.id == dreamIdFromServer && d.status == 'taslak');
      if (existingDraftIndex != -1) {
        _dreams[existingDraftIndex] = _dreams[existingDraftIndex].copyWith(
          status: 'bekleniyor',
          isSynced: true,
          interpretation: "Yorumunuz hazırlanıyor...",
        );
         debugPrint("Mevcut taslak (ID: $dreamIdFromServer) gönderildi olarak güncellendi.");
      } else {
        // Eğer sunucudan farklı bir ID geldiyse veya bu doğrudan online gönderimse
        // ve yerelde bu ID ile bir kayıt yoksa, yeni kayıt oluştur.
        // Genellikle API'ye gönderirken yerel bir UUID kullanılır ve sunucu da bu ID'yi alır veya kendi ID'sini döner.
        // Bu örnekte sunucunun bizim ID'mizi kullandığını veya bizim onun ID'sini aldığımızı varsayıyoruz.
        final dreamExists = _dreams.any((d) => d.id == dreamIdFromServer);
        if (!dreamExists) {
           final newDream = Dream(
            id: dreamIdFromServer, // Sunucudan gelen ID (veya gönderilen ID)
            text: text,
            interpretation: "Yorumunuz hazırlanıyor...",
            date: DateTime.now(),
            status: 'bekleniyor',
            isSynced: true,
          );
          _dreams.add(newDream);
          debugPrint("Yeni gönderilmiş rüya (ID: $dreamIdFromServer) kaydedildi.");
        } else {
           // Rüya zaten 'bekleniyor' veya 'yorumlandı' durumunda olabilir, ID eşleşmesi varsa ve taslak değilse dokunma.
           // Veya isSynced false durumdaki bir 'bekleniyor'u true yapabiliriz.
           final existingUnsyncedIndex = _dreams.indexWhere((d) => d.id == dreamIdFromServer && d.status == 'bekleniyor' && !d.isSynced);
           if (existingUnsyncedIndex != -1) {
             _dreams[existingUnsyncedIndex] = _dreams[existingUnsyncedIndex].copyWith(isSynced: true);
             debugPrint("Daha önce senkronize olamamış rüya (ID: $dreamIdFromServer) şimdi senkronize edildi.");
           } else {
             debugPrint("Rüya (ID: $dreamIdFromServer) zaten farklı bir durumda kayıtlı, tekrar eklenmedi/güncellenmedi.");
           }
        }
      }
      _dreams.sort((a, b) => b.date.compareTo(a.date));
      await _saveDreams();
    });
    notifyListeners();
    // API'ye yeni bir rüya gönderildiğinde yorumları kontrol etmeye başla
    _startPollingForInterpretations();
  }
  
  // Yeni Fonksiyon: Bir taslak rüyayı API'ye göndermeyi dener
  Future<bool> submitDraftToAPI(Dream draftDream) async {
    if (draftDream.status != 'taslak') {
      debugPrint("Hata: Yalnızca 'taslak' durumundaki rüyalar gönderilebilir. ID: ${draftDream.id}");
      return false;
    }

    bool success = false;
    try {
      debugPrint("Taslak rüya API'ye gönderiliyor: ${draftDream.text}");
      
      // API'ye gönder ve yanıtı al
      success = await _apiService.submitDream(draftDream.text);

      if (success) {
        // API'den gelen yanıtı kontrol et
        final response = await _apiService.getLastResponse();
        if (response != null && response.statusCode == 208) {
          // Rüya daha önce işlenmiş, kullanıcıya bilgi ver
          await _lock.synchronized(() async {
            final index = _dreams.indexWhere((d) => d.id == draftDream.id);
            if (index != -1) {
              _dreams[index] = _dreams[index].copyWith(
                status: 'bekleniyor', // Durumu 'bekleniyor' yap
                isSynced: true,     // Senkronize edildi olarak işaretle
                interpretation: "Bu rüya daha önce işlenmiş. Sonuçları kontrol edebilirsiniz.", // Özel mesaj
              );
              await _saveDreams();
            }
          });
          notifyListeners();
          debugPrint("Rüya daha önce işlenmiş, kullanıcıya bilgi verildi: ID ${draftDream.id}");
          return true; // Başarılı olarak işaretle
        }

        // Normal başarılı durum
        await _lock.synchronized(() async {
          final index = _dreams.indexWhere((d) => d.id == draftDream.id);
          if (index != -1) {
            _dreams[index] = _dreams[index].copyWith(
              status: 'bekleniyor',
              isSynced: true,
              interpretation: "Yorumunuz hazırlanıyor...",
            );
            await _saveDreams();
          }
        });
        notifyListeners();
        debugPrint("Taslak rüya başarıyla gönderildi ve güncellendi: ID ${draftDream.id}");
        _startPollingForInterpretations();
        return true;
      } else {
        debugPrint("Taslak rüya API'ye gönderilemedi (API'den false döndü): ID ${draftDream.id}");
        return false;
      }
    } catch (e) {
      debugPrint('Taslak rüya gönderilirken hata (submitDraftToAPI): ID ${draftDream.id} - $e');
      return false;
    }
  }

  // Senkronize edilmemiş tüm rüyaları API'ye göndermeye çalışır
  // Bu fonksiyon artık sadece 'bekleniyor' durumunda olup 'isSynced = false' olanları hedefler.
  // 'taslak' rüyalar manuel olarak SavedDreamsScreen'den gönderilir.
  Future<void> syncUnsyncedDreams() async {
    List<Dream> dreamsToSync = [];
    await _lock.synchronized(() {
      // Sadece 'bekleniyor' durumunda olup senkronize olmamışları al
      dreamsToSync = List.from(_dreams.where((dream) => dream.status == 'bekleniyor' && !dream.isSynced));
    });
    
    if (dreamsToSync.isEmpty) {
      debugPrint("Senkronize edilecek rüya yok.");
      return;
    }
    
    debugPrint("${dreamsToSync.length} adet senkronize edilmemiş rüya gönderiliyor...");
    bool anyDreamSyncedInThisRun = false;

    for (var dream in dreamsToSync) {
      try {
        final success = await _apiService.submitDream(dream.text);
        if (success) {
          await _lock.synchronized(() async {
            final index = _dreams.indexWhere((d) => d.id == dream.id);
            if (index >= 0) {
              _dreams[index] = _dreams[index].copyWith(isSynced: true);
              anyDreamSyncedInThisRun = true;
              debugPrint("Rüya senkronize edildi: ${dream.text}");
            }
          });
        } else {
          debugPrint("Rüya senkronize edilemedi (API'den false): ${dream.text}");
        }
      } catch (e) {
        debugPrint('Rüya senkronizasyon hatası (syncUnsyncedDreams): ${dream.text} - $e');
      }
    }
    if (anyDreamSyncedInThisRun) {
      await _saveDreams();
      notifyListeners();
      debugPrint("Senkronizasyon sonrası polling başlatılıyor.");
      _startPollingForInterpretations(); 
    }
  }
  
  void _startPollingForInterpretations() {
    if (pendingDreams.isEmpty) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      debugPrint("Bekleyen rüya yok, polling durduruldu.");
      return;
    }

    if (_pollingTimer != null && _pollingTimer!.isActive) {
      debugPrint("Polling zaten aktif.");
      return;
    }

    debugPrint("Polling başlatılıyor... Bekleyen rüya sayısı: ${pendingDreams.length}");
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      debugPrint("Yeni yorumlar için sunucu kontrol ediliyor...");
      try {
        List<Map<String, dynamic>> newInterpretations = await _apiService.checkForNewInterpretations();

        if (newInterpretations.isNotEmpty) {
          debugPrint("${newInterpretations.length} adet yeni yorum geldi.");
          await _updateInterpretations(newInterpretations);
        } else {
          debugPrint("Sunucudan yeni yorum gelmedi.");
        }
      } catch (e) {
        debugPrint("Yorumları kontrol ederken hata (polling timer): $e");
        // Hata olsa bile timer'ı durdurma, bir sonraki denemede çalışsın
      }

      // Her kontrolden sonra bekleyen rüya kalıp kalmadığına bak
      if (pendingDreams.isEmpty) {
        _pollingTimer?.cancel();
        _pollingTimer = null;
        debugPrint("Tüm bekleyen rüyalar yorumlandı, polling durduruldu.");
      }
    });
  }
  
  // Yeni özel metot: Yorumları senkronize bir şekilde günceller
  Future<void> _updateInterpretations(List<Map<String, dynamic>> newInterpretations) async {
    bool interpretationUpdated = false;
    await _lock.synchronized(() async {
      debugPrint("${newInterpretations.length} adet yeni yorum geldi. _updateInterpretations içinde.");
      for (var interpretationData in newInterpretations) {
        String? dreamText = interpretationData['ruya'];
        String? yorum = interpretationData['yorum'];

        if (dreamText != null && yorum != null) {
          final dreamIndex = _dreams.indexWhere((d) => d.text == dreamText && d.status == 'bekleniyor' && d.isSynced);
          if (dreamIndex != -1) {
            _dreams[dreamIndex] = _dreams[dreamIndex].copyWith(
              interpretation: yorum,
              status: 'yorumlandı',
            );
            interpretationUpdated = true;
            debugPrint('Yorum güncellendi (yerel): ${dreamText.substring(0, (dreamText.length > 50) ? 50 : dreamText.length)}...');
          }
        }
      }
      if (interpretationUpdated) {
        await _saveDreams();
      }
    });
    if (interpretationUpdated) {
      notifyListeners();
    }
  }
  
  // Yeni metot: Bir rüyanın durumunu günceller
  Future<void> updateDreamStatus(String id, String newStatus) async {
    await _lock.synchronized(() async {
      final dreamIndex = _dreams.indexWhere((dream) => dream.id == id);
      if (dreamIndex >= 0) {
        final oldDream = _dreams[dreamIndex];
        final updatedDream = oldDream.copyWith(status: newStatus);
        
        _dreams[dreamIndex] = updatedDream;
        await _saveDreams();
      }
    });
    notifyListeners();
  }
  
  // Yeni metot: Bir rüyanın yorumunu günceller
  Future<void> updateDreamInterpretation(String id, String newInterpretation) async {
    await _lock.synchronized(() async {
      final dreamIndex = _dreams.indexWhere((dream) => dream.id == id);
      if (dreamIndex >= 0) {
        final oldDream = _dreams[dreamIndex];
        final updatedDream = oldDream.copyWith(
          interpretation: newInterpretation,
          status: 'yorumlandı', // Yorum güncellendiğinde durumu "yorumlandı" olarak güncellenir
        );
        
        _dreams[dreamIndex] = updatedDream;
        await _saveDreams();
      }
    });
    notifyListeners();
  }
  
  // Yeni metot: Bir rüyanın senkronizasyon durumunu günceller
  Future<void> updateDreamSyncStatus(String id, bool isSynced) async {
    await _lock.synchronized(() async {
      final dreamIndex = _dreams.indexWhere((dream) => dream.id == id);
      if (dreamIndex >= 0) {
        // Eğer rüya 'taslak' ise ve senkronize oluyorsa, durumunu 'bekleniyor' yapmalıyız.
        // Ancak bu genellikle submitDraftToAPI içinde ele alınır.
        // Bu fonksiyon daha çok genel bir sync durumu güncellemesi için.
        String newStatus = _dreams[dreamIndex].status;
        if (_dreams[dreamIndex].status == 'taslak' && isSynced) {
            // Bu senaryo submitDraftToAPI ile çakışabilir.
            // Genelde 'taslak' bir rüya isSynced=true olmaz, önce gönderilmesi gerekir.
            // Bu yüzden bu durumu burada özel olarak ele almak yerine,
            // submitDraftToAPI'nin doğru şekilde status ve isSynced'i ayarladığından emin olmak daha iyi.
            // Şimdilik, eğer bir 'taslak' rüya bir şekilde isSynced=true oluyorsa, onu 'bekleniyor' yapalım.
            debugPrint("updateDreamSyncStatus: 'taslak' durumundaki rüya (ID $id) senkronize edildi olarak işaretleniyor, durumu 'bekleniyor' yapılıyor.");
            newStatus = 'bekleniyor';
        }

        final oldDream = _dreams[dreamIndex];
        final updatedDream = oldDream.copyWith(isSynced: isSynced, status: newStatus);
        
        _dreams[dreamIndex] = updatedDream;
        await _saveDreams();
      }
    });
    notifyListeners();
  }

  Future<void> deleteDream(String id) async {
    await _lock.synchronized(() async {
      _dreams.removeWhere((dream) => dream.id == id);
      await _saveDreams();
    });
    notifyListeners();
  }

  Future<void> _saveDreams() async {
    debugPrint("_saveDreams: Başladı.");
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint("_saveDreams: SharedPreferences örneği alındı.");
      final dreamsJson = json.encode(_dreams.map((dream) => dream.toJson()).toList());
      debugPrint("_saveDreams: JSON encode tamamlandı.");
      await prefs.setString(_dreamsKey, dreamsJson);
      debugPrint("_saveDreams: SharedPreferences'a yazıldı. ${_dreams.length} rüya diske kaydedildi.");
    } catch (e) {
      debugPrint("_saveDreams içinde HATA: $e");
      // throw e; // Hatayı yukarı fırlatmak daha iyi olabilir.
    }
    debugPrint("_saveDreams: Bitti (Lock olmadan).");
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
} 