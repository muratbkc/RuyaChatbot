import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ruya_tabir_app/models/dream.dart';
import 'package:ruya_tabir_app/providers/dream_provider.dart';
import 'package:ruya_tabir_app/screens/saved_dreams_screen.dart';
import 'package:ruya_tabir_app/screens/how_to_use_screen.dart';

class DreamHistoryScreen extends StatelessWidget {
  const DreamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Rüya Geçmişim',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
      body: Consumer<DreamProvider>(
        builder: (context, dreamProvider, child) {
          if (dreamProvider.dreams.isEmpty) {
            return const Center(
              child: Text(
                'Kaydedilmiş rüyanız bulunmamaktadır.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: dreamProvider.dreams.length,
            itemBuilder: (context, index) {
              final dream = dreamProvider.dreams[index];
              return Card(
                child: ListTile(
                  title: Text(
                    dream.text.length > 50
                        ? '${dream.text.substring(0, 50)}...'
                        : dream.text,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  subtitle: Text(
                    DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(dream.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[400]),
                    onPressed: () => _showDeleteConfirmationDialog(context, dreamProvider, dream),
                  ),
                  onTap: () => _showDreamDetailDialog(context, dream),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, DreamProvider dreamProvider, Dream dream) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Rüyayı Sil'),
          content: const Text('Bu rüyayı silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sil'),
              onPressed: () {
                dreamProvider.deleteDream(dream.id);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Rüya silindi.'),
                    backgroundColor: Colors.red[400],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showDreamDetailDialog(BuildContext context, Dream dream) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            'Rüya Detayı (${DateFormat('dd.MM.yyyy', 'tr_TR').format(dream.date)})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Rüyanız:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(dream.text, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text('Yorumu:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildInterpretationText(context, dream.interpretation),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Kapat'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
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
          style: Theme.of(context).textTheme.bodyMedium,
        ));
        spans.add(TextSpan(
          text: specialHeader,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          style: Theme.of(context).textTheme.bodyMedium,
        ));
      }
      
      // Bold metin (** işaretleri olmadan)
      spans.add(TextSpan(
        text: match.group(1) ?? '',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ));
      
      lastEnd = match.end;
    }
    
    // Kalan normal metin
    if (lastEnd < currentText.length) {
      spans.add(TextSpan(
        text: currentText.substring(lastEnd),
        style: Theme.of(context).textTheme.bodyMedium,
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}  