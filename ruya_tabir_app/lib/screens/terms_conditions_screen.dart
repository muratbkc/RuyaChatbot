import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import 'package:ruya_tabir_app/screens/saved_dreams_screen.dart';
import 'package:ruya_tabir_app/screens/how_to_use_screen.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
          'Kullanım Koşulları',
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
                        'Kullanım Koşulları',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bu uygulamayı kullanarak aşağıdaki koşulları kabul etmiş olursunuz:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      _buildTermItem(
                        context,
                        '1. Uygulama Kullanımı',
                        'Bu uygulama, rüya yorumlama hizmeti sunmaktadır. Yorumlar genel niteliktedir ve kişiye özel tavsiye niteliği taşımaz.',
                      ),
                      _buildTermItem(
                        context,
                        '2. Gizlilik',
                        'Paylaştığınız rüyalar gizli tutulacak ve üçüncü taraflarla paylaşılmayacaktır.',
                      ),
                      _buildTermItem(
                        context,
                        '3. Sorumluluk Reddi',
                        'Uygulama üzerinden yapılan yorumlar tamamen bilgilendirme amaçlıdır. Herhangi bir tıbbi, psikolojik veya profesyonel danışmanlık hizmeti yerine geçmez.',
                      ),
                      _buildTermItem(
                        context,
                        '4. Kullanım Sınırlamaları',
                        'Uygulamayı kötüye kullanmak, spam yapmak veya zararlı içerik paylaşmak yasaktır.',
                      ),
                      _buildTermItem(
                        context,
                        '5. Değişiklikler',
                        'Bu kullanım koşulları önceden haber verilmeksizin değiştirilebilir. Güncel koşullar için düzenli olarak kontrol etmeniz önerilir.',
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

  Widget _buildTermItem(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
} 