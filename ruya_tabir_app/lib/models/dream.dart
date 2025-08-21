class Dream {
  final String id;
  final String text;
  final String interpretation;
  final DateTime date;
  final String status;
  final bool isSynced; 

  Dream({
    required this.id,
    required this.text,
    required this.interpretation,
    required this.date,
    required this.status,
    required this.isSynced,
  });

  // JSON'dan Dream nesnesi oluşturma
  factory Dream.fromJson(Map<String, dynamic> json) {
    return Dream(
      id: json['id'] as String,
      text: json['text'] as String,
      interpretation: json['interpretation'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String? ?? 'bekleniyor',
      isSynced: json['isSynced'] as bool? ?? true, // Eski kayıtlar için varsayılan değer
    );
  }

  // Dream nesnesini JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'interpretation': interpretation,
      'date': date.toIso8601String(),
      'status': status,
      'isSynced': isSynced,
    };
  }

  // Yeni bir Dream nesnesi oluşturarak bazı alanları günceller
  Dream copyWith({
    String? id,
    String? text,
    String? interpretation,
    DateTime? date,
    String? status,
    bool? isSynced,
  }) {
    return Dream(
      id: id ?? this.id,
      text: text ?? this.text,
      interpretation: interpretation ?? this.interpretation,
      date: date ?? this.date,
      status: status ?? this.status,
      isSynced: isSynced ?? this.isSynced,
    );
  }
} 