# Rüya Tabiri Chatbot

Bu proje, Flutter ile geliştirilmiş bir mobil uygulama ve Python (Flask) ile yazılmış bir arka uçtan oluşan bir rüya tabiri chatbot uygulamasıdır. Kullanıcıların gördükleri rüyaları metin olarak girmelerini ve yapay zeka destekli yorumlar almalarını sağlar.

## Özellikler

- **Flutter Mobil Uygulaması:** Kullanıcıların rüyalarını girebildiği ve sonuçları görebildiği modern ve kullanıcı dostu bir arayüz.
- **Python (Flask) Arka Uç:** Gelen rüya metinlerini işleyen, anlamsal arama yapan ve yorum üreten sunucu.
- **Vektör Veritabanı (ChromaDB):** Rüya tabirlerinin anlamsal olarak aranabilmesi için verilerin saklandığı ve yönetildiği veritabanı.
- **Yapay Zeka (Google Gemini):** Rüya metinlerini analiz etme, en uygun tabirleri bulma ve kullanıcıya sunulacak nihai yorumu oluşturma.

## Kullanılan Teknolojiler

- **Ön Yüz (Frontend):**
  - Flutter
  - Dart
- **Arka Uç (Backend):**
  - Python
  - Flask
  - ChromaDB
  - Google Gemini API
  - Sentence Transformers

## Kurulum ve Çalıştırma

Projeyi yerel makinenizde çalıştırmak için aşağıdaki adımları izleyin.

### Gereksinimler

- Flutter SDK
- Python 3.8+
- Bir kod editörü (VS Code, Android Studio vb.)

### 1. Arka Ucu (Backend) Çalıştırma

Arka uç sunucusu, rüya yorumlama mantığını içerir.

1. Proje ana dizinine gidin.

2. Bir Python sanal ortamı (`virtual environment`) oluşturun ve aktive edin:
   ```bash
   python -m venv venv
   # Windows için:
   .\venv\Scripts\activate
   # macOS/Linux için:
   source venv/bin/activate
   ```

3. Gerekli Python paketlerini yükleyin:
   ```bash
   pip install -r requirements.txt
   ```

4. Google Gemini API anahtarlarınızı ortam değişkeni olarak ayarlayın. Bu, işletim sisteminize göre değişiklik gösterir:

   - **Windows (PowerShell):**
     ```powershell
     $env:GOOGLE_API_KEY_1="YOUR_API_KEY_HERE"
     $env:GOOGLE_API_KEY_2="ANOTHER_API_KEY_HERE"
     ```
   - **macOS/Linux:**
     ```bash
     export GO_API_KEY_1="YOUR_API_KEY_HERE"
     export GO_API_KEY_2="ANOTHER_API_KEY_HERE"
     ```

5. Sunucuyu başlatın:
   ```bash
   python app.py
   ```
   Sunucu varsayılan olarak `http://localhost:5000` adresinde çalışmaya başlayacaktır.

### 2. Mobil Uygulamayı (Frontend) Çalıştırma

1. `ruya_tabir_app` dizinine gidin:
   ```bash
   cd ruya_tabir_app
   ```
2. Flutter paketlerini yükleyin:
   ```bash
   flutter pub get
   ```
3. Bir emülatör başlatın veya fiziksel bir cihaz bağlayın.
4. Uygulamayı çalıştırın:
   ```bash
   flutter run
   ```
