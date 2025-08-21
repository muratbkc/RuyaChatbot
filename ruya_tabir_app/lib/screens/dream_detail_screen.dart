import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ruya_tabir_app/models/dream.dart';
import 'package:ruya_tabir_app/providers/dream_provider.dart';
import 'package:intl/intl.dart'; // Tarih formatlamak için
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // Kopyalama işlemleri için
import 'package:ruya_tabir_app/screens/saved_dreams_screen.dart'; // Eklendi
import 'package:ruya_tabir_app/screens/how_to_use_screen.dart'; // Eklendi

class DreamDetailScreen extends StatefulWidget {
  final Dream dream;

  const DreamDetailScreen({super.key, required this.dream});

  @override
  State<DreamDetailScreen> createState() => _DreamDetailScreenState();
}

class _DreamDetailScreenState extends State<DreamDetailScreen> {
  bool _isSending = false;
  bool _draftSuccessfullySent = false;

  Future<void> _deleteDream(BuildContext context, String dreamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rüyayı Sil',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: Colors.red[700],
          ),
        ),
        content: Text(
          'Bu rüyayı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          style: GoogleFonts.nunito(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(
              'İptal', 
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(false);
            },
          ),
          TextButton(
            child: Text(
              'Sil', 
              style: GoogleFonts.nunito(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // ignore: use_build_context_synchronously
      await Provider.of<DreamProvider>(context, listen: false).deleteDream(dreamId);
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); // Detay ekranından çık
      
      // Başarı mesajı göster
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rüya başarıyla silindi',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _copyText(BuildContext context, String text, String type) {
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$type kopyalandı',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _submitDraft(BuildContext context) async {
    final dreamProvider = Provider.of<DreamProvider>(context, listen: false);
    
    // Günlük limit kontrolü
    final canSubmit = await dreamProvider.canSubmitDreamToday();
    final remainingDreams = await dreamProvider.getRemainingDreamsToday();
    
    if (!canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Günlük rüya gönderme limitinize ulaştınız. Bugün en fazla 5 rüya gönderebilirsiniz.',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Kullanıcıya onay sor
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Taslağı Gönder'),
          content: Text('Bu taslağı yorumlamaya göndermek istediğinizden emin misiniz?\n\nBugün kalan rüya hakkınız: $remainingDreams'),
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

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    bool success = false;
    try {
      success = await dreamProvider.submitDraftToAPI(widget.dream);
      if (success) {
        final newRemainingDreams = await dreamProvider.getRemainingDreamsToday();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Taslak başarıyla yorumlamaya gönderildi.\nBugün kalan rüya hakkınız: $newRemainingDreams',
              style: GoogleFonts.nunito(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Taslak gönderilemedi. Lütfen tekrar deneyin.',
              style: GoogleFonts.nunito(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bir hata oluştu: $e',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isSending = false;
        if (success) {
          _draftSuccessfullySent = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isInterpreted = widget.dream.status == 'yorumlandı';
    final bool isDraft = widget.dream.status == 'taslak';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Rüya Detayı',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            onPressed: widget.dream.status == 'bekleniyor'
                ? null // Eğer durum 'bekleniyor' ise butonu devre dışı bırak
                : () => _deleteDream(context, widget.dream.id),
            tooltip: widget.dream.status == 'bekleniyor'
                ? 'Yorum bekleyen rüya silinemez'
                : 'Rüyayı Sil',
          ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isDraft)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_isSending || _draftSuccessfullySent) ? null : () => _submitDraft(context),
                      icon: _isSending
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        'Taslağı Yorumlamaya Gönder',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.bedtime,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Rüya',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            onPressed: () => _copyText(context, widget.dream.text, 'Rüya'),
                            tooltip: 'Rüyayı Kopyala',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.dream.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              if (isInterpreted) ...[
                const SizedBox(height: 16),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.psychology,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Yorum',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              onPressed: () => _copyText(context, widget.dream.interpretation ?? '', 'Yorum'),
                              tooltip: 'Yorumu Kopyala',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInterpretationText(context, widget.dream.interpretation ?? 'Yorum bulunamadı.'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Yorum metnini parse ederek başlıkları kalın fontla gösteren widget
  Widget _buildInterpretationText(BuildContext context, String interpretation) {
    List<TextSpan> spans = [];
    
    // ** ile çevrili metinleri ve özel başlığı işle
    List<String> parts = [];
    String currentText = interpretation;
    
    // "Rüyanızda gördüklerinizi şöyle yorumlayabiliriz:" başlığını özel olarak işle
    String specialHeader = 'Rüyanızda gördüklerinizi şöyle yorumlayabiliriz:';
    if (currentText.contains(specialHeader)) {
      List<String> headerSplit = currentText.split(specialHeader);
      if (headerSplit.length > 1) {
        spans.add(TextSpan(
          text: headerSplit[0],
          style: Theme.of(context).textTheme.bodyLarge,
        ));
        spans.add(TextSpan(
          text: specialHeader,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
        currentText = headerSplit.sublist(1).join(specialHeader);
      }
    }
    
    // ** ile çevrili metinleri işle
    RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;
    
    for (RegExpMatch match in boldPattern.allMatches(currentText)) {
      // Bold'dan önceki normal metin
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: currentText.substring(lastEnd, match.start),
          style: Theme.of(context).textTheme.bodyLarge,
        ));
      }
      
      // Bold metin (** işaretleri olmadan)
      spans.add(TextSpan(
        text: match.group(1) ?? '',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ));
      
      lastEnd = match.end;
    }
    
    // Kalan normal metin
    if (lastEnd < currentText.length) {
      spans.add(TextSpan(
        text: currentText.substring(lastEnd),
        style: Theme.of(context).textTheme.bodyLarge,
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }
} 