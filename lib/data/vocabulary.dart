class VocabularyCard {
  const VocabularyCard({
    required this.phrase,
    required this.pronunciation,
    required this.meaning,
  });

  final String phrase;
  final String pronunciation;
  final String meaning;
}

const supportedTargetLanguages = <String>[
  'Arabic',
  'Assamese',
  'Bengali',
  'English',
  'French',
  'German',
  'Gujarati',
  'Hindi',
  'Japanese',
  'Kannada',
  'Korean',
  'Malayalam',
  'Mandarin Chinese',
  'Marathi',
  'Odia',
  'Punjabi',
  'Spanish',
  'Tamil',
  'Telugu',
  'Urdu',
];

const supportedTutorLanguages = <String>['English', 'Malayalam'];

const vocabularyByLanguage = <String, List<VocabularyCard>>{
  'Arabic': [
    VocabularyCard(
      phrase: 'مرحبا',
      pronunciation: 'marhaban',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(phrase: 'شكرا', pronunciation: 'shukran', meaning: 'നന്ദി'),
    VocabularyCard(
      phrase: 'من فضلك',
      pronunciation: 'min fadlik',
      meaning: 'ദയവായി',
    ),
  ],
  'Assamese': [
    VocabularyCard(
      phrase: 'নমস্কাৰ',
      pronunciation: 'nomoskar',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ধন্যবাদ',
      pronunciation: 'dhonyobad',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'অনুগ্ৰহ কৰি',
      pronunciation: 'onugroho kori',
      meaning: 'ദയവായി',
    ),
  ],
  'Bengali': [
    VocabularyCard(
      phrase: 'নমস্কার',
      pronunciation: 'nomoshkar',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ধন্যবাদ',
      pronunciation: 'dhonnobad',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'দয়া করে',
      pronunciation: 'doya kore',
      meaning: 'ദയവായി',
    ),
  ],
  'English': [
    VocabularyCard(
      phrase: 'Hello',
      pronunciation: 'heh-loh',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'Thank you',
      pronunciation: 'thank yoo',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(phrase: 'Please', pronunciation: 'pleez', meaning: 'ദയവായി'),
  ],
  'French': [
    VocabularyCard(
      phrase: 'Bonjour',
      pronunciation: 'bohn-zhoor',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'Merci',
      pronunciation: 'mehr-see',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: "S'il vous plaît",
      pronunciation: 'seel voo pleh',
      meaning: 'ദയവായി',
    ),
  ],
  'German': [
    VocabularyCard(
      phrase: 'Hallo',
      pronunciation: 'hah-loh',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'Danke',
      pronunciation: 'dahn-kuh',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'Bitte',
      pronunciation: 'bit-tuh',
      meaning: 'ദയവായി',
    ),
  ],
  'Gujarati': [
    VocabularyCard(
      phrase: 'નમસ્તે',
      pronunciation: 'namaste',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(phrase: 'આભાર', pronunciation: 'aabhar', meaning: 'നന്ദി'),
    VocabularyCard(
      phrase: 'કૃપા કરીને',
      pronunciation: 'krupa karine',
      meaning: 'ദയവായി',
    ),
  ],
  'Hindi': [
    VocabularyCard(
      phrase: 'नमस्ते',
      pronunciation: 'namaste',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'धन्यवाद',
      pronunciation: 'dhanyavaad',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'कृपया',
      pronunciation: 'kripaya',
      meaning: 'ദയവായി',
    ),
  ],
  'Japanese': [
    VocabularyCard(
      phrase: 'こんにちは',
      pronunciation: 'konnichiwa',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ありがとう',
      pronunciation: 'arigatou',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'お願いします',
      pronunciation: 'onegaishimasu',
      meaning: 'ദയവായി',
    ),
  ],
  'Kannada': [
    VocabularyCard(
      phrase: 'ನಮಸ್ಕಾರ',
      pronunciation: 'namaskara',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ಧನ್ಯವಾದಗಳು',
      pronunciation: 'dhanyavadagalu',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'ದಯವಿಟ್ಟು',
      pronunciation: 'dayavittu',
      meaning: 'ദയവായി',
    ),
  ],
  'Korean': [
    VocabularyCard(
      phrase: '안녕하세요',
      pronunciation: 'annyeonghaseyo',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: '감사합니다',
      pronunciation: 'gamsahamnida',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: '부탁합니다',
      pronunciation: 'butakhamnida',
      meaning: 'ദയവായി',
    ),
  ],
  'Malayalam': [
    VocabularyCard(
      phrase: 'നമസ്കാരം',
      pronunciation: 'namaskaram',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(phrase: 'നന്ദി', pronunciation: 'nandi', meaning: 'നന്ദി'),
    VocabularyCard(
      phrase: 'ദയവായി',
      pronunciation: 'dayavayi',
      meaning: 'ദയവായി',
    ),
  ],
  'Mandarin Chinese': [
    VocabularyCard(phrase: '你好', pronunciation: 'nǐ hǎo', meaning: 'നമസ്കാരം'),
    VocabularyCard(phrase: '谢谢', pronunciation: 'xiè xie', meaning: 'നന്ദി'),
    VocabularyCard(phrase: '请', pronunciation: 'qǐng', meaning: 'ദയവായി'),
  ],
  'Marathi': [
    VocabularyCard(
      phrase: 'नमस्कार',
      pronunciation: 'namaskar',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'धन्यवाद',
      pronunciation: 'dhanyavaad',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'कृपया',
      pronunciation: 'krupaya',
      meaning: 'ദയവായി',
    ),
  ],
  'Odia': [
    VocabularyCard(
      phrase: 'ନମସ୍କାର',
      pronunciation: 'namaskar',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ଧନ୍ୟବାଦ',
      pronunciation: 'dhanyabad',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'ଦୟାକରି',
      pronunciation: 'dayakari',
      meaning: 'ദയവായി',
    ),
  ],
  'Punjabi': [
    VocabularyCard(
      phrase: 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
      pronunciation: 'sat sri akaal',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ਧੰਨਵਾਦ',
      pronunciation: 'dhanvaad',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'ਕਿਰਪਾ ਕਰਕੇ',
      pronunciation: 'kirpa karke',
      meaning: 'ദയവായി',
    ),
  ],
  'Spanish': [
    VocabularyCard(
      phrase: 'Hola',
      pronunciation: 'oh-lah',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'Gracias',
      pronunciation: 'grah-see-ahs',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'Por favor',
      pronunciation: 'por fah-vor',
      meaning: 'ദയവായി',
    ),
  ],
  'Tamil': [
    VocabularyCard(
      phrase: 'வணக்கம்',
      pronunciation: 'vanakkam',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(phrase: 'நன்றி', pronunciation: 'nandri', meaning: 'നന്ദി'),
    VocabularyCard(
      phrase: 'தயவு செய்து',
      pronunciation: 'thayavu seithu',
      meaning: 'ദയവായി',
    ),
  ],
  'Telugu': [
    VocabularyCard(
      phrase: 'నమస్కారం',
      pronunciation: 'namaskaram',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'ధన్యవాదాలు',
      pronunciation: 'dhanyavadalu',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'దయచేసి',
      pronunciation: 'dayachesi',
      meaning: 'ദയവായി',
    ),
  ],
  'Urdu': [
    VocabularyCard(
      phrase: 'سلام',
      pronunciation: 'salaam',
      meaning: 'നമസ്കാരം',
    ),
    VocabularyCard(
      phrase: 'شکریہ',
      pronunciation: 'shukriya',
      meaning: 'നന്ദി',
    ),
    VocabularyCard(
      phrase: 'براہ کرم',
      pronunciation: 'barah-e-karam',
      meaning: 'ദയവായി',
    ),
  ],
};

List<VocabularyCard> vocabularyFor(String language) =>
    vocabularyByLanguage[language] ?? vocabularyByLanguage['English']!;

String greetingFor(String language) => vocabularyFor(language).first.phrase;
