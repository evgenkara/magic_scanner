import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:typed_data';
import 'package:purchases_flutter/purchases_flutter.dart';


// --- НАСТРОЙКИ ---
const String apiKey = 'AIzaSyCqPUsuI5F9d2SdW-OfkgazBkKzbB0gMoc'; 
const String promoCode = 'CURE2026';

final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Включаем логи, чтобы видеть в консоли, как идут платежи
  await Purchases.setLogLevel(LogLevel.debug);
  // Инициализируем кассу вашим ключом от RevenueCat
  await Purchases.configure(PurchasesConfiguration("goog_hQpqvhLMYDOWyPlvfZqxvwEHBgu"));
  
  final prefs = await SharedPreferences.getInstance();
  
  // Загрузка темы
  final String savedTheme = prefs.getString('theme_mode') ?? 'system';
  if (savedTheme == 'light') _themeNotifier.value = ThemeMode.light;
  if (savedTheme == 'dark') _themeNotifier.value = ThemeMode.dark;

  // Проверка на первый запуск (для онбординга)
  final bool isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

  runApp(MagicScannerApp(isFirstLaunch: isFirstLaunch));
}

class MagicScannerApp extends StatelessWidget {
  final bool isFirstLaunch;
  
  const MagicScannerApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Magic Scanner',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFEADDFF), foregroundColor: Colors.black),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2D0A3D), foregroundColor: Colors.white),
          ),
          // Если первый запуск - показываем Onboarding, иначе сразу ScannerScreen
          home: isFirstLaunch ? const OnboardingScreen() : const ScannerScreen(),
        );
      },
    );
  }
}

// ==========================================
// НОВЫЙ ЭКРАН: ОНБОРДИНГ
// ==========================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Умный сканер еды 🥗",
      "description": "Узнавайте калории, БЖУ и получайте полезные рецепты просто по фото вашего блюда.",
      "icon": "restaurant_menu"
    },
    {
      "title": "Справочник растений 🌿",
      "description": "Распознавайте любые цветы, деревья и грибы. Получайте советы по уходу и предупреждения об опасности.",
      "icon": "local_florist"
    },
    {
      "title": "Переводчик и AI 🧠",
      "description": "Переводите тексты из книг или задавайте ИИ любые вопросы голосом. Вся магия в вашем кармане.",
      "icon": "auto_awesome"
    },
  ];

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant_menu': return Icons.restaurant_menu;
      case 'local_florist': return Icons.local_florist;
      case 'auto_awesome': return Icons.auto_awesome;
      default: return Icons.star;
    }
  }

  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false); // Запоминаем, что мы прошли обучение
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            _getIconData(_onboardingData[index]["icon"]!),
                            size: 100,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 50),
                        Text(
                          _onboardingData[index]["title"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _onboardingData[index]["description"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Навигация (Точки и кнопки)
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Кнопка ПРОПУСТИТЬ
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: const Text("Пропустить", style: TextStyle(color: Colors.grey)),
                  ),
                  
                  // Точки
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 10,
                        width: _currentPage == index ? 20 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  
                  // Кнопка ДАЛЕЕ / НАЧАТЬ
                  FilledButton(
                    onPressed: () {
                      if (_currentPage == _onboardingData.length - 1) {
                        _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    child: Text(_currentPage == _onboardingData.length - 1 ? "Начать" : "Далее"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ... ДАЛЬШЕ ИДЕТ ВАШ КЛАСС ScannerScreen ...

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharingImage = false; // Для анимации загрузки на кнопке
  String _resultText = '';
  String _loadingText = 'Thinking...';
  
  String _selectedCategory = 'General';
  final Map<String, IconData> _categories = {
    'General': Icons.auto_awesome,
    'Food': Icons.restaurant_menu,
    'Plant': Icons.local_florist,
    'Text': Icons.text_fields,
  };

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  int _freeScansLeft = 3;         
  bool _isPremium = false; 
  int _secretTapCounter = 0;      

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadMana();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage(_langCode);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() => setState(() => _isSpeaking = false));
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(onStatus: (val) {}, onError: (val) {});
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() => _questionController.text = val.recognizedWords), localeId: _langCode);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_resultText.isEmpty || _resultText.startsWith('Error')) return;
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      String cleanText = _resultText.replaceAll(RegExp(r'[#*]'), ''); 
      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> _loadMana() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selectedCategory = prefs.getString('last_category') ?? 'General');
    
    // Проверяем статус в RevenueCat и локальный тестовый режим
    bool hasRealPremium = await checkIsPremium();
    bool isTester = prefs.getBool('is_tester') ?? false;
    setState(() => _isPremium = hasRealPremium || isTester);

    final lastDate = prefs.getString('last_run_date') ?? '';
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastDate != today) {
      await prefs.setString('last_run_date', today);
      await prefs.setInt('daily_scans', 3);
      setState(() => _freeScansLeft = 3);
    } else {
      setState(() => _freeScansLeft = prefs.getInt('daily_scans') ?? 3);
    }
  }

  Future<void> _selectCategory(String category) async {
    setState(() => _selectedCategory = category);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_category', category);
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Внешний вид", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(leading: const Icon(Icons.brightness_auto), title: const Text("Системная"), onTap: () => _updateTheme(ThemeMode.system)),
              ListTile(leading: const Icon(Icons.wb_sunny), title: const Text("Светлая"), onTap: () => _updateTheme(ThemeMode.light)),
              ListTile(leading: const Icon(Icons.nightlight_round), title: const Text("Темная"), onTap: () => _updateTheme(ThemeMode.dark)),
              const Divider(height: 30),
              const Text("Подписка", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(_isPremium ? Icons.verified : Icons.diamond, color: _isPremium ? Colors.green : Colors.deepPurple),
                title: Text(_isPremium ? "Вы - Premium пользователь" : "Купить Premium"),
                subtitle: _isPremium ? const Text("Безлимитный доступ активен") : const Text("Снять все лимиты навсегда"),
                trailing: _isPremium ? const Icon(Icons.check, color: Colors.green) : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  if (!_isPremium) {
                    Navigator.pop(context); // Закрываем меню
                    // Открываем настоящий Paywall и ждем результата
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
                    if (result == true) {
                      _loadMana(); // Обновляем статус, если купили
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _activatePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_tester', true);
    setState(() => _isPremium = true);
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    _themeNotifier.value = mode;
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await prefs.setString('theme_mode', modeStr);
  }

  Future<void> _consumeMana() async {
    if (_isPremium) return; 
    setState(() => _freeScansLeft--);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_scans', _freeScansLeft);
  }

  void _handleTitleTap() {
    if (_isPremium) return;
    setState(() => _secretTapCounter++);
    if (_secretTapCounter >= 7) {
      _secretTapCounter = 0;
      _showPromoCodeDialog(); 
    }
  }

  void _showPromoCodeDialog() {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🕵️ Тестовый доступ'),
        content: TextField(controller: codeController, decoration: const InputDecoration(hintText: 'Промокод разработчика', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ОТМЕНА')),
          FilledButton(
            onPressed: () async {
              if (codeController.text == promoCode) {
                Navigator.of(ctx).pop();
                _activatePremium();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Доступ активирован!'), backgroundColor: Colors.green));
              } else {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Неверный код'), backgroundColor: Colors.red));
              }
            },
            child: const Text('ВОЙТИ'),
          ),
        ],
      ),
    );
  }

  String get _langCode {
    try { return Platform.localeName.split('_')[0]; } catch (e) { return 'en'; }
  }

  Map<String, String> get _uiStrings {
    if (_langCode == 'ru') {
      return {
        'title': 'Магический Сканер', 'scan_btn': 'СПРОСИТЬ AI', 'placeholder': 'Фото + Ваш вопрос',
        'hint_text': 'Например: "Это ядовито?"', 'error': 'Ошибка', 'premium_title': 'Лимит исчерпан',
        'premium_msg': 'Вы использовали все бесплатные сканирования на сегодня.', 'copy': 'Скопировано',
        'cat_General': 'Общее', 'cat_Food': 'Еда', 'cat_Plant': 'Флора', 'cat_Text': 'Текст',
      };
    } else {
      return {
        'title': 'Magic Scanner', 'scan_btn': 'ASK AI', 'placeholder': 'Photo + Your Question',
        'hint_text': 'Ex: "Is this safe to eat?"', 'error': 'Error', 'premium_title': 'Limit Reached',
        'premium_msg': 'You have used all your free scans for today.', 'copy': 'Copied',
        'cat_General': 'General', 'cat_Food': 'Food', 'cat_Plant': 'Plants', 'cat_Text': 'Text',
      };
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_isPremium && _freeScansLeft <= 0) { _showPremiumDialog(); return; }
    if (_isSpeaking) { await _flutterTts.stop(); setState(() => _isSpeaking = false); }

    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _image = File(photo.path);
        _resultText = '';
        _loadingText = _questionController.text.isEmpty ? (_langCode == 'ru' ? 'Изучаю...' : 'Analyzing...') : (_langCode == 'ru' ? 'Ищу ответ на вопрос...' : 'Answering your question...');
      });
    }
  }

  Future<void> _runAnalysis() async {
    if (_image == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, добавьте фото!'))); return; }
    if (!_isPremium && _freeScansLeft <= 0) { _showPremiumDialog(); return; }
    await _consumeMana();
    _analyzeImage();
  }
  
  void _showPremiumDialog() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(_uiStrings['premium_title']!), 
        content: Text(_uiStrings['premium_msg']!), 
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')), 
          FilledButton(
            onPressed: () async { 
              Navigator.of(ctx).pop(); 
              // Открываем настоящий Paywall вместо фейкового
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
              if (result == true) {
                _loadMana();
              }
            }, 
            child: const Text('PREMIUM')
          )
        ]
      )
    );
  }

  // --- ЛОГИКА СОХРАНЕНИЯ В ИСТОРИЮ ---
  Future<void> _saveToHistory(String result) async {
    if (_image == null) return;
    try {
      // 1. Получаем постоянную папку
      final directory = await getApplicationDocumentsDirectory();
      // 2. Генерируем уникальное имя файла
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImagePath = '${directory.path}/$fileName';
      // 3. Копируем туда картинку
      await _image!.copy(savedImagePath);

      // 4. Добавляем запись в JSON
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString('scan_history') ?? '[]';
      final List<dynamic> historyJson = jsonDecode(historyString);

      historyJson.insert(0, {
        'imagePath': savedImagePath,
        'text': result,
        'category': _selectedCategory,
        'date': DateTime.now().toIso8601String(),
      });

      await prefs.setString('scan_history', jsonEncode(historyJson));
    } catch (e) {
      print("Ошибка сохранения истории: $e");
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;
    setState(() => _isLoading = true);

    try {
      final model = GenerativeModel(model: 'gemma-3-27b-it', apiKey: apiKey);
      final imageBytes = await _image!.readAsBytes();
      
      String userQuestion = _questionController.text;
      String prompt = 'Role: You are an expert AI Assistant.\nLanguage: Respond strictly in "$_langCode".\nFormatting: Use Markdown.\n';

      if (userQuestion.isNotEmpty) {
        prompt += 
            '\n🔴 IMPORTANT USER QUESTION: "$userQuestion"\n'
            'Task: Answer the user question specifically and accurately based on the image.\n'
            'Format: Use Markdown headers (##) and relevant emojis (like 💡, ⚠️, ✅) to make the text beautiful and easy to read.\n'
            'After answering, provide a brief general description of the object.\n';
      } else {
        switch (_selectedCategory) {
          case 'Food':
            prompt += 
              'Task: Identify the dish/food.\n'
              'Structure:\n'
              '## 🍽️ [Название блюда]\n(Описание)\n'
              '## 📊 Калории и БЖУ\n(Калории на 100г, Белки/Жиры/Углеводы)\n'
              '## 📝 Рецепт / Ингредиенты\n(Из чего состоит и как готовить)\n'
              '## 🥗 Оценка пользы\n(Насколько это полезно?)';
            break;
          case 'Plant':
            prompt += 
              'Task: Identify the plant/mushroom.\n'
              'Structure:\n'
              '## 🌿 [Название растения]\n(Научное название)\n'
              '## 💧 Уход\n(Как поливать, сколько нужно света)\n'
              '## ⚠️ Безопасность\n(Ядовито ли для кошек/собак/детей?)\n'
              '## 🌍 Происхождение\n(Где растет в природе?)';
            break;
          case 'Text':
            prompt += 
              'Task: Act as an OCR and Translator.\n'
              'Structure:\n'
              '## 📄 Оригинальный текст\n(Распознанный текст)\n'
              '## 🌍 Перевод\n(Перевод на "$_langCode")\n'
              '## 📌 Суть (Саммари)\n(О чем этот текст в 1 предложении)';
            break;
          default: 
            prompt += 
              'Task: Identify the object.\n'
              'Structure:\n'
              '## 🔍 [Что это]\n(Описание)\n'
              '## 📊 Характеристики\n(Главные факты)\n'
              '## 🛠️ Как использовать\n(Практическое применение)\n'
              '## 💡 Интересный факт\n(Удивительная деталь)';
        }
      }

      final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)])];
      final response = await model.generateContent(content);

      setState(() {
        _resultText = response.text ?? 'Error';
        _isLoading = false;
      });

      // Сохраняем успешный результат
      if (!_resultText.startsWith('Error')) {
        await _saveToHistory(_resultText);
      }

    } catch (e) {
      setState(() { _resultText = 'Error: $e'; _isLoading = false; });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _resultText));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_uiStrings['copy']!), duration: const Duration(seconds: 1)));
  }

  Future<void> _shareAsCard() async {
    if (_image == null || _resultText.isEmpty) return;
    
    setState(() => _isSharingImage = true);
    
    try {
      // Очищаем текст от звездочек Markdown для красивой карточки
      String cleanText = _resultText.replaceAll(RegExp(r'[#*]'), '');
      // Ограничиваем длину текста, чтобы он влез в картинку
      if (cleanText.length > 300) {
        cleanText = '${cleanText.substring(0, 300)}...';
      }

      // Создаем скрытый виджет карточки и сразу "фотографируем" его
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        Material(
          child: Container(
            padding: const EdgeInsets.all(25),
            color: const Color(0xFF1E1E1E), // Темно-серый премиальный фон
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 28),
                    SizedBox(width: 10),
                    Text('Magic Scanner', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(_image!, height: 300, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 20),
                Text(
                  cleanText,
                  style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                const Divider(color: Colors.white24),
                const SizedBox(height: 15),
                // Ваша вирусная подпись!
                const Text(
                  'Get it on Google Play • curecurious.com',
                  style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        delay: const Duration(milliseconds: 200),
      );

      // Сохраняем во временную папку телефона
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/share_card.png').create();
      await imagePath.writeAsBytes(imageBytes);

      // Открываем системное окно "Поделиться"
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: _langCode == 'ru' 
            ? 'Смотри, что нашел мой Magic Scanner! ✨' 
            : 'Look what Magic Scanner found! ✨',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _isSharingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _uiStrings;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(onTap: _handleTitleTap, child: Text(strings['title']!)),
        actions: [
          // КНОПКА ИСТОРИИ
          IconButton(
            icon: const Icon(Icons.history), 
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
            }
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                child: Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
                  ),
                  child: _image == null 
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo, size: 50, color: Colors.grey), const SizedBox(height: 10), Text(strings['placeholder']!, style: const TextStyle(color: Colors.grey))]) 
                      : null,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: strings['hint_text'],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true,
                  suffixIcon: IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.grey), onPressed: _listen),
                ),
              ),
              const SizedBox(height: 10),
              if (!_isLoading)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.keys.map((String key) {
                      final bool isSelected = _selectedCategory == key;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(strings['cat_$key'] ?? key),
                          selected: isSelected,
                          avatar: Icon(_categories[key], size: 18),
                          onSelected: (bool selected) { if (selected) _selectCategory(key); },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _runAnalysis,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_isLoading ? _loadingText : strings['scan_btn']!),
                ),
              ),
              const SizedBox(height: 20),
              if (!_isLoading && _resultText.isEmpty)
                TextButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: Text(strings['placeholder']!.split(' ')[0])),
              if (_isLoading)
                 const Padding(padding: EdgeInsets.only(top: 20), child: CircularProgressIndicator())
              else if (_resultText.isNotEmpty && !_resultText.startsWith('Error'))
                 Column(
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         IconButton(icon: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up), color: _isSpeaking ? Colors.red : Theme.of(context).primaryColor, onPressed: _speak),
                         IconButton(icon: const Icon(Icons.copy), onPressed: _copyToClipboard),
                         IconButton(
                           icon: _isSharingImage
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.share), 
                           onPressed: _isSharingImage ? null : _shareAsCard,
                         ),
                       ],
                     ),
                     const Divider(),
                     MarkdownBody(data: _resultText),
                   ],
                 )
              else if (_resultText.startsWith('Error'))
                 Text(_resultText, style: const TextStyle(color: Colors.red)),
               const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// НОВЫЙ ЭКРАН: ИСТОРИЯ СКАНИРОВАНИЙ
// ==========================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('scan_history') ?? '[]';
    setState(() {
      _historyList = jsonDecode(historyString);
    });
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scan_history');
    setState(() {
      _historyList = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История сканирований'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              // Диалог подтверждения очистки
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить историю?'),
                  content: const Text('Все ваши прошлые сканирования будут удалены навсегда.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ОТМЕНА')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        _clearHistory();
                        Navigator.pop(ctx);
                      },
                      child: const Text('УДАЛИТЬ'),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _historyList.isEmpty
          ? const Center(child: Text("История пуста. Сделайте первый скан!", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: _historyList.length,
              itemBuilder: (context, index) {
                final item = _historyList[index];
                final imageFile = File(item['imagePath']);
                
                // Форматируем дату просто для красоты (обрезаем лишнее)
                final dateStr = item['date'].toString().split('T')[0];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ExpansionTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageFile.existsSync() 
                          ? Image.file(imageFile, width: 50, height: 50, fit: BoxFit.cover)
                          : const Icon(Icons.broken_image, size: 50),
                    ),
                    title: Text('Режим: ${item['category']}'),
                    subtitle: Text(dateStr),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: MarkdownBody(data: item['text']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

Future<bool> checkIsPremium() async {
  try {
    CustomerInfo customerInfo = await Purchases.getCustomerInfo();
    // Слово 'premium' — это тот самый Entitlement, который мы создавали в панели
    if (customerInfo.entitlements.all["premium"]?.isActive == true) {
      return true;
    }
  } catch (e) {
    debugPrint("Ошибка проверки подписки: $e");
  }
  return false;
}

// ==========================================
// ЭКРАН ОПЛАТЫ (PAYWALL)
// ==========================================
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  // Получаем товары с сервера RevenueCat
  Future<void> _fetchOffers() async {
    try {
      final offerings = await Purchases.getOfferings();
      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      debugPrint("Ошибка загрузки товаров: ${e.message}");
      setState(() => _isLoading = false);
    }
  }

  // Процесс покупки
  Future<void> _makePurchase(Package package) async {
    setState(() => _isLoading = true);
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      // Проверяем, появилось ли право "premium" после оплаты
      if (customerInfo.entitlements.all["premium"]?.isActive == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Спасибо за покупку! Magic Scanner теперь безлимитный ✨'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Возвращаемся назад с успехом
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("Ошибка покупки: ${e.message}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Восстановление покупок (Обязательное требование Google Play!)
  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all["premium"]?.isActive == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Покупки успешно восстановлены!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Активных подписок не найдено.')),
        );
      }
    } catch (e) {
      debugPrint("Ошибка восстановления: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ищем наш пакет (Monthly) в дефолтной витрине
    final package = _offerings?.current?.availablePackages.firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 80, color: Colors.deepPurpleAccent),
                    const SizedBox(height: 20),
                    const Text(
                      "Magic Scanner\nPRO",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                    ),
                    const SizedBox(height: 40),
                    
                    // Список преимуществ
                    _buildFeatureRow("Безлимитные сканирования еды и растений"),
                    _buildFeatureRow("Подробная аналитика БЖУ"),
                    _buildFeatureRow("Перевод любых текстов без ограничений"),
                    _buildFeatureRow("Приоритетная скорость ответов ИИ"),
                    
                    const Spacer(),

                    // Кнопка покупки
                    if (package != null)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () => _makePurchase(package),
                          child: Text(
                            "Оформить за ${package.storeProduct.priceString} / мес",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      )
                    else
                      const Text("Товары пока недоступны", style: TextStyle(color: Colors.grey)),

                    const SizedBox(height: 20),
                    
                    // Кнопка восстановления (обязательно для модерации)
                    TextButton(
                      onPressed: _restorePurchases,
                      child: const Text("Восстановить покупки", style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16))),
        ],
      ),
    );
  }
}