import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya_tabir_app/providers/dream_provider.dart';
import 'package:ruya_tabir_app/models/dream.dart';
import 'package:intl/intl.dart'; // Tarih formatlamak için
import 'package:google_fonts/google_fonts.dart';
import 'dream_detail_screen.dart'; // Detay ekranı için import
import 'package:ruya_tabir_app/screens/how_to_use_screen.dart'; // Eklendi

class SavedDreamsScreen extends StatefulWidget {
  const SavedDreamsScreen({super.key});

  @override
  State<SavedDreamsScreen> createState() => _SavedDreamsScreenState();
}

class _SavedDreamsScreenState extends State<SavedDreamsScreen> {
  // Gönderme işlemi için yükleme durumlarını tutacak map
  final Map<String, bool> _isSendingMap = {}; 

  @override
  Widget build(BuildContext context) {
    final dreamProvider = Provider.of<DreamProvider>(context);
    // Artık dreamProvider'dan doğrudan draft, pending ve interpreted listelerini alacağız.
    final draftDreams = dreamProvider.draftDreams;
    final pendingDreams = dreamProvider.pendingDreams;
    final interpretedDreams = dreamProvider.interpretedDreams;
    // final failedSyncDreams = dreamProvider.failedSyncDreams; // İleride kullanılabilir

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Kaydedilmiş Rüyalar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
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
          bottom: TabBar(
            labelStyle: Theme.of(context).tabBarTheme.labelStyle,
            unselectedLabelStyle: Theme.of(context).tabBarTheme.unselectedLabelStyle,
            labelColor: Theme.of(context).tabBarTheme.labelColor,
            unselectedLabelColor: Theme.of(context).tabBarTheme.unselectedLabelColor,
            indicatorColor: Theme.of(context).tabBarTheme.indicatorColor,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Taslaklar (${draftDreams.length})'),
              Tab(text: 'Bekleniyor (${pendingDreams.length})'),
              Tab(text: 'Yorumlandı (${interpretedDreams.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Günlük limit bilgisi kartı
            Container(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<int>(
                future: dreamProvider.getRemainingDreamsToday(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final remainingDreams = snapshot.data!;
                    final todayDreamCount = DreamProvider.maxDailyDreams - remainingDreams;
                    
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: remainingDreams > 0 
                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                          : Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              remainingDreams > 0 ? Icons.nightlight_round : Icons.block,
                              color: remainingDreams > 0 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bugün $todayDreamCount/5 rüya gönderdiniz • Kalan: $remainingDreams',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            // TabBarView
            Expanded(
              child: TabBarView(
                children: [
                  _buildDreamList(context, draftDreams, 'taslak', dreamProvider),
                  _buildDreamList(context, pendingDreams, 'bekleniyor', dreamProvider),
                  _buildDreamList(context, interpretedDreams, 'yorumlandı', dreamProvider),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddDraftDialog(context, dreamProvider),
          icon: const Icon(Icons.add),
          label: Text(
            "Yeni Taslak",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 2,
        ),
      ),
    );
  }
  
  void _showAddDraftDialog(BuildContext context, DreamProvider dreamProvider) {
    final TextEditingController draftController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            bool isSaving = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Yeni Taslak Rüya',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rüyanızı detaylı bir şekilde anlatın',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Taslak olarak kaydedilen rüyalar daha sonra yorumlamaya gönderilebilir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: draftController,
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
                      hintText: "Rüyanızı buraya yazın...",
                      hintStyle: Theme.of(context).textTheme.bodyMedium,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    'İptal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final text = draftController.text.trim();
                          final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
                          final charCount = text.replaceAll(RegExp(r'\s+'), '').length; // Boşlukları çıkar ve harf sayısını al
                          
                          if (text.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Lütfen rüyanızı girin.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onError,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          if (wordCount < 3) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Rüyanız çok kısa!',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onError,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          if (charCount < 15) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Rüyanız çok kısa!',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onError,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                            return;
                          }

                          setStateDialog(() {
                            isSaving = true;
                          });
                          try {
                            await dreamProvider.addOfflineDraft(text);
                            if (mounted && Navigator.of(ctx).canPop()) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Taslak kaydedildi.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint("Taslak kaydetme hatası: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Taslak kaydedilemedi: $e',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onError,
                                    ),
                                  ),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setStateDialog(() {
                                isSaving = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Kaydet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDreamList(BuildContext context, List<Dream> dreams, String statusType, DreamProvider dreamProvider) {
    if (dreams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E55AF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: const Color(0xFF4E55AF),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Bu kategoride rüya bulunmuyor',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Yeni bir rüya gönderebilir veya başka bir kategoriyi kontrol edebilirsiniz',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dreams.length,
      itemBuilder: (ctx, index) {
        final dream = dreams[index];
        final dreamDate = DateFormat('dd MMMM yyyy').format(dream.date);
        final dreamTime = DateFormat('HH:mm').format(dream.date);
        
        // Rüya metnini önizlemesi için kısaltma (ellipsis)
        final truncatedText = dream.text.length > 80 
            ? '${dream.text.substring(0, 80)}...' 
            : dream.text;
            
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DreamDetailScreen(dream: dream),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(statusType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(statusType),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _getStatusColor(statusType),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$dreamDate $dreamTime',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      truncatedText,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taslak':
        return const Color(0xFFFF9800); // Turuncu
      case 'bekleniyor':
        return const Color(0xFF4E55AF); // Mavi
      case 'yorumlandı':
        return const Color(0xFF4CAF50); // Yeşil
      default:
        return const Color(0xFF9A9AB0); // Gri
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'taslak':
        return 'Taslak';
      case 'bekleniyor':
        return 'Bekleniyor';
      case 'yorumlandı':
        return 'Yorumlandı';
      default:
        return status;
    }
  }
} 