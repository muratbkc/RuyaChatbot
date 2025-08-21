import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import 'package:ruya_tabir_app/screens/saved_dreams_screen.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = ResponsiveHelper.isDesktop(context);
    final isMediumScreen = ResponsiveHelper.isTablet(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text(
          'Nasıl Kullanılır?',
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
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 800 : (isMediumScreen ? 600 : double.infinity),
              ),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rüya Tabiri Nasıl Yapılır?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Rüyanızın yorumlanması için aşağıdaki adımları takip edin:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      _buildStepItem(
                        context,
                        icon: Icons.edit_note,
                        step: '1. Rüyanızı Yazın',
                        description: 'Ana sayfadaki metin kutusuna rüyanızı detaylı bir şekilde yazın. Ne kadar detaylı anlatırsanız, yorum o kadar doğru olacaktır.',
                      ),
                      _buildStepItem(
                        context,
                        icon: Icons.send,
                        step: '2. Gönder',
                        description: 'Rüyanızı yazdıktan sonra "Rüyamı Gönder" butonuna tıklayın. Rüyanız yapay zeka sistemimize iletilecektir.',
                      ),
                      _buildStepItem(
                        context,
                        icon: Icons.psychology,
                        step: '3. Yorumu Alın',
                        description: 'Rüyanız analiz edildikten sonra size detaylı bir yorum sunulacaktır. Bu yorumu kaydedebilir ve daha sonra tekrar inceleyebilirsiniz.',
                      ),
                      _buildStepItem(
                        context,
                        icon: Icons.bookmark,
                        step: '4. Kaydetme ve Geçmiş',
                        description: 'Rüya yorumlarınızı kaydedebilir ve daha sonra incelemek için "Kaydedilenler" bölümünden erişebilirsiniz.',
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      Text(
                        'Önemli Notlar:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildNoteItem(
                        context,
                        '• Rüyanızı mümkün olduğunca detaylı anlatın.',
                      ),
                      _buildNoteItem(
                        context,
                        '• Rüyanızda gördüğünüz renkleri, duyguları ve detayları belirtin.',
                      ),
                      _buildNoteItem(
                        context,
                        '• İnternet bağlantınızın olduğundan emin olun.',
                      ),
                      _buildNoteItem(
                        context,
                        '• Yorumlar genel niteliktedir, kişiye özel tavsiye niteliği taşımaz.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(
    BuildContext context, {
    required IconData icon,
    required String step,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, String note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        note,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
} 