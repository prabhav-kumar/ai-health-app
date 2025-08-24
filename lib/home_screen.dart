import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'config/ai_models_config.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _chatController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  String _currentChatId = '';
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _buttonScaleAnimation;

  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  @override
  void initState() {
    super.initState();
    _initializeDotEnv();
    _checkAuth();
    _initializeChat();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_animationController);
  }

  Future<void> _initializeDotEnv() async {
    await dotenv.load(fileName: '.env');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  void _initializeChat() {
    setState(() {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages = [
        {
          'role': 'bot',
          'text': 'Welcome! I am your AI Health Assistant. How can I help you with your health concerns today?',
          'timestamp': DateTime.now().toIso8601String(),
        }
      ];
    });
  }

  Future<String> _getGeminiResponse(String userInput) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return 'Error: Gemini API key not found in .env file.';
    }

    try {
      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  "text": "You are a health assistant that analyzes the user's health condition based on their input and gives short, helpful replies. Provide a possible cause, a brief treatment suggestion, and mention up to two commonly used medicines (with basic precautions). If needed, ask follow-up questions like how long the user has had the symptoms or their body temperature. Keep the response clear, relevant, and concise — avoid long paragraphs or detailed medical explanations. Always end with this line: 'This response is AI-generated and may not be fully accurate. Please consult a medical professional for proper diagnosis and treatment.'\n\nUser input: $userInput"
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text']?.trim() ?? 'Sorry, I couldn’t generate a response.';
      } else {
        return 'Error: Unable to fetch response from Gemini API (Status: ${response.statusCode}).';
      }
    } catch (e) {
      return 'Error: Failed to connect to Gemini API. Please try again.';
    }
  }

  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final userMessage = _chatController.text.trim();
    setState(() {
      _messages.add({
        'role': 'user',
        'text': userMessage,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _isLoading = true;
      _chatController.clear();
    });

    final botResponse = await _getGeminiResponse(userMessage);

    setState(() {
      _messages.add({
        'role': 'bot',
        'text': botResponse,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _isLoading = false;
    });
  }

  Future<void> _sendImageMessage(String imagePath, String modelType) async {
    setState(() {
      _messages.add({
        'role': 'user',
        'text': '📸 Analyzing image with $modelType model...',
        'timestamp': DateTime.now().toIso8601String(),
        'imagePath': imagePath,
      });
      _isLoading = true;
    });

    try {
      final analysisResult = await _analyzeImageWithModel(modelType, imagePath);
      
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': analysisResult,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': '❌ Error analyzing image: $e',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
    }
  }

  Future<String> _analyzeImageWithModel(String modelType, String imagePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(AIModelsConfig.getModelUrl(modelType)));
      request.headers['Authorization'] = 'Bearer ${dotenv.env['HUGGINGFACE_TOKEN']}';
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      
      final streamed = await request.send();
      
      if (streamed.statusCode != 200) {
        throw Exception('API request failed with status ${streamed.statusCode}');
      }
      
      final body = await streamed.stream.bytesToString();
      final result = json.decode(body);
      return _formatAnalysisResult(result, modelType);
      
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }

  Future<void> _analyzeImageAuto(String imagePath) async {
    final String userPrompt = _chatController.text.trim();
    setState(() {
      _messages.add({
        'role': 'user',
        'text': userPrompt.isNotEmpty ? '📸 Image uploaded with question: "$userPrompt"' : '📸 Image uploaded for analysis',
        'timestamp': DateTime.now().toIso8601String(),
        'imagePath': imagePath,
      });
      _isLoading = true;
      _chatController.clear();
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(AIModelsConfig.getAutoUrl()));
      request.headers['Authorization'] = 'Bearer ${dotenv.env['HUGGINGFACE_TOKEN']}';
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));
      if (userPrompt.isNotEmpty) {
        request.fields['user_prompt'] = userPrompt;
      }
      request.fields['threshold'] = '0.6';

      final streamed = await request.send();
      
      if (streamed.statusCode != 200) {
        throw Exception('Server error: ${streamed.statusCode}');
      }
      
      final body = await streamed.stream.bytesToString();
      final result = json.decode(body);

      String analysis = _formatAutoResultText(result);
      String? overlayPath;

      // Brain segmentation overlay
      final seg = result['brain_segmentation'];
      if (seg != null && seg['overlay_base64'] != null && (result['has_tumor_suspected'] == true)) {
        overlayPath = await _saveBase64Png(seg['overlay_base64'], prefix: 'brain_overlay_');
      }
      // Fracture annotated
      final frac = result['fracture_localization'];
      if (frac != null && frac['annotated_base64'] != null && (frac['has_fracture'] == true)) {
        overlayPath = await _saveBase64Png(frac['annotated_base64'], prefix: 'fracture_');
      }

      setState(() {
        _messages.add({
          'role': 'bot',
          'text': analysis,
          'timestamp': DateTime.now().toIso8601String(),
          if (overlayPath != null) 'imagePath': overlayPath,
        });
      });

      // Compose final advice via Gemini using findings summary
      final findingsSummary = _buildFindingsSummary(result);
      final geminiPrompt = userPrompt.isNotEmpty
          ? '$userPrompt\n\nImage findings (for context):\n$findingsSummary'
          : 'Based on these image findings, give a short, helpful health insight.\n\nImage findings:\n$findingsSummary';
      final gemini = await _getGeminiResponse(geminiPrompt);

      setState(() {
        _messages.add({
          'role': 'bot',
          'text': gemini,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': '❌ Auto analysis failed: $e',
          'timestamp': DateTime.now().toIso8601String(),
        });
        _isLoading = false;
      });
    }
  }

  Future<String> _saveBase64Png(String base64Data, {String prefix = 'overlay_'}) async {
    try {
      final bytes = base64.decode(base64Data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$prefix${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      throw Exception('Failed to save overlay image: $e');
    }
  }

  String _buildFindingsSummary(Map<String, dynamic> result) {
    final b = StringBuffer();
    if (result['domain'] != null) {
      b.writeln('Domain: ${result['domain']} (conf: ${(result['domain_confidence'] ?? 0.0).toStringAsFixed(2)})');
    }
    if (result['domain_valid'] == false) {
      b.writeln('The image appears out of supported medical domains.');
    }
    if (result['brain_classification'] != null) {
      final br = result['brain_classification'];
      b.writeln('Brain: ${br['predicted_class']} (conf: ${(br['predicted_confidence'] ?? 0.0).toStringAsFixed(2)})');
      if (result['has_tumor_suspected'] == true) b.writeln('Tumor suspected.');
    }
    if (result['chest_classification'] != null) {
      final ch = result['chest_classification'];
      b.writeln('Chest: ${ch['predicted_class']} (conf: ${(ch['predicted_confidence'] ?? 0.0).toStringAsFixed(2)})');
    }
    if (result['retinopathy_classification'] != null) {
      final rt = result['retinopathy_classification'];
      b.writeln('Retina: ${rt['predicted_class']} (conf: ${(rt['predicted_confidence'] ?? 0.0).toStringAsFixed(2)})');
    }
    if (result['fracture_localization'] != null) {
      final fr = result['fracture_localization'];
      b.writeln('Fracture suspected: ${fr['has_fracture'] == true ? 'Yes' : 'No'}');
    }
    return b.toString().trim();
  }

  String _formatAutoResultText(Map<String, dynamic> result) {
    if (result['domain_valid'] == false) {
      return '❌ The uploaded image does not match supported medical domains. Please upload a brain MRI, chest X-ray, bone X-ray, or fundus image.';
    }
    final b = StringBuffer();
    if (result['domain'] != null) {
      b.writeln('🧭 Detected domain: ${result['domain']} (conf: ${(result['domain_confidence'] ?? 0.0).toStringAsFixed(2)})');
    }
    if (result['brain_classification'] != null) {
      final br = result['brain_classification'];
      b.writeln('🧠 Brain: ${br['predicted_class']} (conf: ${(br['predicted_confidence'] ?? 0.0).toStringAsFixed(2)})');
      if (result['has_tumor_suspected'] == true) b.writeln('🎯 Tumor suspected. Segmentation overlay attached.');
    }
    if (result['chest_classification'] != null) {
      final ch = result['chest_classification'];
      b.writeln('🫁 Chest: ${ch['predicted_class']} (conf: ${(ch['predicted_confidence'] ?? 0.0).toStringAsFixed(2)})');
    }
    if (result['retinopathy_classification'] != null) {
      final rt = result['retinopathy_classification'];
      b.writeln('👁️ Retina: ${rt['predicted_class']} (conf: ${(rt['predicted_confidence'] ?? 0.0).toStringAsFixed(2)})');
    }
    if (result['fracture_localization'] != null) {
      final fr = result['fracture_localization'];
      b.writeln('🦴 Fracture: ${fr['has_fracture'] == true ? 'Detected (see overlay)' : 'Not detected'}');
    }
    b.writeln('\n⚠️ Note: Automated analysis. Consult a medical professional for diagnosis.');
    return b.toString().trim();
  }

  String _formatAnalysisResult(Map<String, dynamic> result, String modelType) {
    String formatted = '';
    
    if (result['classification'] != null) {
      formatted += '📊 **Analysis Results:**\n\n';
      for (var item in result['classification']) {
        formatted += '• ${item['class']}: ${(item['confidence'] * 100).toStringAsFixed(1)}%\n';
      }
    }
    
    if (result['segmentation_mask'] != null) {
      formatted += '\n🎯 **Segmentation Results:**\n';
      formatted += '• Segmentation mask generated\n';
      if (result['tumor_detected'] != null) {
        formatted += '• Tumor detected: ${result['tumor_detected'] ? 'Yes' : 'No'}\n';
      }
    }
    
    if (result['localization'] != null) {
      formatted += '\n📍 **Localization Results:**\n';
      if (result['fractures_detected'] != null) {
        formatted += '• Fractures detected: ${result['fractures_detected'] ? 'Yes' : 'No'}\n';
      }
      if (result['detections'] != null) {
        formatted += '• Detections: ${result['detections'].length}\n';
      }
    }
    
    formatted += '\n\n⚠️ **Note:** This analysis is AI-generated and should not replace professional medical diagnosis.';
    return formatted;
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image != null) {
      // Auto pipeline without model selection
      await _analyzeImageAuto(image.path);
    }
  }

  // Model selection dialog removed in auto pipeline

  void _startNewChat() {
    setState(() {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages = [
        {
          'role': 'bot',
          'text': 'Welcome! I am your AI Health Assistant. How can I help you with your health concerns today?',
          'timestamp': DateTime.now().toIso8601String(),
        }
      ];
    });
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print('Logout error: $e');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.medical_services, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Health Assistant',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.medical_services, color: Colors.white, size: 32),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Health Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user != null) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_user, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Verified User',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        user.email ?? '',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                        ),
                        child: Icon(Icons.home_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(
                        'Home',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.info_rounded, color: Theme.of(context).colorScheme.secondary),
                      ),
                      title: Text(
                        'About',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/about'),
                    ),
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.contact_support_rounded, color: Theme.of(context).colorScheme.tertiary),
                      ),
                      title: Text(
                        'Contact Us',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/contact'),
                    ),
                    Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.tertiary),
                      ),
                      title: Text(
                        'Logout',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF12131F),
              Color(0xFF1A1C2B),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            Positioned(
              right: -60,
              top: -60,
              child: AnimatedContainer(
                duration: Duration(seconds: 10),
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -40,
              child: AnimatedContainer(
                duration: Duration(seconds: 12),
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: isUser
                                  ? LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.secondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isUser ? null : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isUser
                                    ? Colors.transparent
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isUser) ...[
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.medical_services,
                                          color: Theme.of(context).colorScheme.secondary,
                                          size: 16,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Health Assistant',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                ],
                                Text(
                                  msg['text'] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                                if (msg['imagePath'] != null) ...[
                                  SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(msg['imagePath']!),
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: Offset(0, -10),
                      ),
                    ],
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    children: [
                      // Image capture buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.secondary),
                            onPressed: () => _pickImage(ImageSource.camera),
                            tooltip: 'Take Photo',
                          ),
                          SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.secondary),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            tooltip: 'Choose from Gallery',
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: InputDecoration(
                                hintText: 'Ask about your health concerns...',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(width: 16), // Adds space between TextField and send button
                          _isLoading
                              ? Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).colorScheme.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : GestureDetector(
                                  onTapDown: _onTapDown,
                                  onTapUp: _onTapUp,
                                  onTapCancel: () => _animationController.reverse(),
                                  child: ScaleTransition(
                                    scale: _buttonScaleAnimation,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.secondary,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: _sendMessage,
                                          child: Container(
                                            padding: EdgeInsets.all(10),
                                            child: Icon(Icons.send, color: Colors.white, size: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.secondary),
                            label: Text(
                              'New Chat',
                              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                            ),
                            onPressed: _startNewChat,                        
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}