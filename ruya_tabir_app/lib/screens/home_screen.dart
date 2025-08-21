

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:ruya_tabir_app/providers/dream_provider.dart'; 
import 'package:ruya_tabir_app/screens/saved_dreams_screen.dart'; 
import 'package:ruya_tabir_app/screens/how_to_use_screen.dart'; 
import 'package:ruya_tabir_app/screens/privacy_policy_screen.dart'; 
import 'package:ruya_tabir_app/screens/terms_conditions_screen.dart'; 
import '../services/api_service.dart'; 
import '../services/speech_service.dart'; 
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; 
import 'package:uuid/uuid.dart'; 
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _dreamController = TextEditingController();
  final ApiService _apiService = ApiService(); // ApiService örneği oluştur
  final SpeechService _speechService = SpeechService(); // SpeechService örneği oluştur
  final Uuid _uuid = Uuid(); // UUID örneği
  bool _isLoading = false;
  String _currentDreamText = '';
  bool _dreamSent = false; // Bu değişken rüyanın başarılı bir şekilde API'ye gönderilip gönderilmediğini veya taslak olarak kaydedildiğini gösterecek.
  bool _isListening = false; // Mikrofon dinleme durumu
  bool _speechInitialized = false; // Speech service başlatılma durumu

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final initialized = await _speechService.initialize();
    setState(() {
      _speechInitialized = initialized;
    });
    
    if (!initialized) {
      print('Speech recognition initialization failed');
    }
  }

  Future<void> _startListening() async {
    if (!_speechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konuşma tanıma başlatılamadı. Mikrofon izni verin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speechService.startListening(
      onResult: (text) {
        setState(() {
          _dreamController.text = text;
          _isListening = false;
        });
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konuşma tanıma hatası: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _sendDream() async {
    final dreamText = _dreamController.text.trim();
    final wordCount = dreamText.isEmpty ? 0 : dreamText.split(RegExp(r'\s+')).length;
    final charCount = dreamText.replaceAll(RegExp(r'\s+'), '').length; // Boşlukları çıkar ve harf sayısını al

    if (dreamText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen rüyanızı girin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (wordCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rüyanız çok kısa!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (charCount < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rüyanız çok kısa!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Günlük limit kontrolü
    final dreamProvider = Provider.of<DreamProvider>(context, listen: false);
    final canSubmit = await dreamProvider.canSubmitDreamToday();
    final remainingDreams = await dreamProvider.getRemainingDreamsToday();
    
    if (!canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Günlük rüya gönderme limitinize ulaştınız. Bugün en fazla 5 rüya gönderebilirsiniz.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rüyanı Gönder'),
          content: Text('Rüyanızı göndermek istediğinizden emin misiniz?\n\nBugün kalan rüya hakkınız: $remainingDreams'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Gönder'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == null || !confirmed) {
      return;
    }

    setState(() {
      _currentDreamText = dreamText;
      _isLoading = true;
    });

    final localDreamId = _uuid.v4();

    try {
      bool apiSuccess = await _apiService.submitDream(dreamText);

      if (apiSuccess) {
        await dreamProvider.recordSubmittedDream(dreamText, dreamIdFromServer: localDreamId);
        if (mounted) {
          final newRemainingDreams = await dreamProvider.getRemainingDreamsToday();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rüyanız gönderildi ve yorumlanmak üzere kaydedildi.\nBugün kalan rüya hakkınız: $newRemainingDreams'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {
            _dreamSent = true;
            _dreamController.clear();
          });
        }
      } else {
        _showSaveAsDraftDialog(dreamText, dreamProvider);
      }
    } catch (e) {
      debugPrint('API gönderme hatası: $e');
      _showSaveAsDraftDialog(dreamText, dreamProvider);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSaveAsDraftDialog(String dreamText, DreamProvider dreamProvider) async {
    final saveAsDraft = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gönderilemedi'),
          content: const Text('Rüyanız gönderilemedi. İnternet bağlantınızı kontrol edin veya daha sonra tekrar deneyin. Bu rüyayı taslak olarak kaydetmek ister misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Hayır'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Evet, Taslak Olarak Kaydet'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (saveAsDraft == true && mounted) {
      await dreamProvider.addOfflineDraft(dreamText);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rüyanız taslak olarak kaydedildi.'),
          backgroundColor: Colors.blue,
        ),
      );
      setState(() {
        _dreamSent = true;
        _dreamController.clear();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rüya gönderilemedi ve kaydedilmedi.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = ResponsiveHelper.isDesktop(context);
    final isMediumScreen = ResponsiveHelper.isTablet(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Rüya Tabiri',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.bookmark_border,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedDreamsScreen()),
              );
            },
            tooltip: 'Kaydedilmiş Rüyalar',
          ),
          IconButton(
            icon: Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HowToUseScreen()),
              );
            },
            tooltip: 'Nasıl Kullanılır?',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bedtime,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rüya Tabiri',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.bookmark_border,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Kaydedilmiş Rüyalar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SavedDreamsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.help_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Nasıl Kullanılır?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HowToUseScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Gizlilik Politikası',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.description_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Kullanım Koşulları',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsConditionsScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 800 : (isMediumScreen ? 600 : double.infinity),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Günlük limit bilgisi kartı
                  Consumer<DreamProvider>(
                    builder: (context, dreamProvider, child) {
                      return FutureBuilder<int>(
                        future: dreamProvider.getRemainingDreamsToday(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final remainingDreams = snapshot.data!;
                            final todayDreamCount = DreamProvider.maxDailyDreams - remainingDreams;
                            
                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: remainingDreams > 0 
                                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                  : Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      remainingDreams > 0 ? Icons.nightlight_round : Icons.block,
                                      color: remainingDreams > 0 
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.error,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Günlük Rüya Limitiniz',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Bugün $todayDreamCount/5 rüya gönderdiniz • Kalan: $remainingDreams',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_dreamSent) ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rüyanızı Anlatın',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (_isListening)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Dinleniyor...',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rüyanızı detaylı bir şekilde anlatın, size en kısa sürede yorumlayalım.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _dreamController,
                              maxLines: 5,
                              maxLength: 700,
                              buildCounter: (
                                BuildContext context,
                                {required int currentLength, required bool isFocused, required int? maxLength}
                              ) {
                                return Text(
                                  '$currentLength/$maxLength',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: currentLength > maxLength! * 0.9 
                                      ? Theme.of(context).colorScheme.error 
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                );
                              },
                              decoration: InputDecoration(
                                hintText: 'Rüyanızı buraya yazın...',
                                hintStyle: Theme.of(context).textTheme.bodyMedium,
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                suffixIcon: _speechInitialized
                                    ? IconButton(
                                        icon: Icon(
                                          _isListening ? Icons.mic : Icons.mic_none,
                                          color: _isListening 
                                              ? Theme.of(context).colorScheme.primary 
                                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        onPressed: _isListening ? _stopListening : _startListening,
                                        tooltip: _isListening ? 'Dinlemeyi Durdur' : 'Konuşarak Gir',
                                      )
                                    : null,
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendDream,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).colorScheme.onPrimary,
                                          ),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Rüyayı Gönder',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Rüyanız Başarıyla Gönderildi',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'En kısa sürede yorumlanıp size bildirilecektir.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _dreamSent = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Yeni Rüya Gönder',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dreamController.dispose();
    super.dispose();
  }
}