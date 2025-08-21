import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import 'package:ruya_tabir_app/screens/saved_dreams_screen.dart';
import 'package:ruya_tabir_app/screens/how_to_use_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Gizlilik Politikası',
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
                        'Gizlilik Politikası',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gizliliğiniz bizim için önemlidir. Bu politika, verilerinizin nasıl işlendiğini açıklar:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      _buildPrivacyItem(
                        context,
                        '1. Veri Toplama',
                        'Sadece rüya yorumlaması için gerekli olan bilgileri toplarız. Kişisel bilgileriniz güvenle saklanır.',
                      ),
                      _buildPrivacyItem(
                        context,
                        '2. Veri Kullanımı',
                        'Topladığımız veriler sadece rüya yorumlama hizmetini sağlamak için kullanılır.',
                      ),
                      _buildPrivacyItem(
                        context,
                        '3. Veri Güvenliği',
                        'Verileriniz endüstri standardı güvenlik önlemleriyle korunmaktadır.',
                      ),
                      _buildPrivacyItem(
                        context,
                        '4. Veri Paylaşımı',
                        'Verileriniz üçüncü taraflarla paylaşılmaz ve satılmaz.',
                      ),
                      _buildPrivacyItem(
                        context,
                        '5. Çerezler',
                        'Uygulamamız, daha iyi bir deneyim sunmak için çerezler kullanabilir.',
                      ),
                      _buildPrivacyItem(
                        context,
                        '6. Haklarınız',
                        'Verilerinize erişme, düzeltme veya silme haklarına sahipsiniz.',
                      ),
                      _buildPrivacyItem(
                        context,
                        '7. İletişim',
                        'Gizlilik politikamızla ilgili sorularınız için bizimle iletişime geçebilirsiniz.',
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

  Widget _buildPrivacyItem(BuildContext context, String title, String content) {
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