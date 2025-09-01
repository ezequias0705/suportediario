import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

// --- Dependências do projeto ---
// Adicione as seguintes dependências ao seu arquivo pubspec.yaml:
// dependencies:
//   flutter:
//     sdk: flutter
//   provider: ^6.0.0
//   flutter_local_notifications: ^17.0.0
//   flutter_tts: ^4.0.0
//   flutter_slidable: ^3.0.0
//   file_picker: ^8.0.0
//
// --- Configurações Nativas (Android) ---
// Para que as notificações e o TTS funcionem corretamente em segundo plano,
// é necessário fazer as seguintes configurações no AndroidManifest.xml:
//
// 1. Adicione as permissões:
// <uses-permission android:name="android.permission.VIBRATE"/>
// <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//
// 2. Adicione as dependências do Kotlin no build.gradle (app):
// buildscript {
//     ext.kotlin_version = '1.7.10' // Verifique a versão mais recente
//     repositories {
//         google()
//         mavenCentral()
//     }
//     dependencies {
//         classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
//     }
// }
//
// 3. No AndroidManifest.xml, adicione o Receiver para o boot completed:
// <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//   <intent-filter>
//     <action android:name="android.intent.action.BOOT_COMPLETED"/>
//     <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
//   </intent-filter>
// </receiver>
//
// Certifique-se também de adicionar o ícone da notificação em android/app/src/main/res/drawable/app_icon_name.png
// e configurar o AndroidManifest.xml para a notificação (veja a documentação do pacote).

// Instância global para notificações
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Função para converter dados de áudio para formato compatível com notificação
Future<String> getAudioFilePath(String assetPath) async {
  final byteData = await rootBundle.load(assetPath);
  final file = File('${(await getTemporaryDirectory()).path}/$assetPath');
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return file.path;
}

// Configuração inicial das notificações
Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
    if (response.payload != null) {
      // O payload contém os dados do evento para o TTS
      final eventData = response.payload!.split('|');
      final eventTitle = eventData[0];
      final eventTime = eventData[1];
      final eventVoice = eventData[2];

      await FlutterTts().setLanguage("pt-BR");
      await FlutterTts().setVoice({"name": eventVoice == 'female' ? 'pt-br-x-ftj-local' : 'pt-br-x-stb-local'});
      await FlutterTts().speak("Lembrete: $eventTitle, às $eventTime");
    }
  });
}

// Classe de modelo para o Lembrete (Evento)
class Event {
  final int id;
  String title;
  TimeOfDay time;
  List<int> weeklyRepeatDays; // 1 = Seg, 2 = Ter, ..., 7 = Dom
  String soundType; // 'tts' ou 'audio'
  String? audioPath;
  String? ttsVoice; // 'male' ou 'female'

  Event({
    required this.id,
    required this.title,
    required this.time,
    required this.weeklyRepeatDays,
    required this.soundType,
    this.audioPath,
    this.ttsVoice,
  });

  // Método para agendar a notificação para este evento
  Future<void> scheduleNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'lembretes_channel',
      'Lembretes',
      channelDescription: 'Canal de notificações para lembretes',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final now = DateTime.now();
    final nextNotificationTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      'Seu lembrete está programado para as ${time.format(null)}',
      nextNotificationTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Método para cancelar a notificação
  Future<void> cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}

// EventProvider: Gerenciador de estado para a lista de eventos
class EventProvider with ChangeNotifier {
  final List<Event> _events = [];
  int _nextId = 0;

  List<Event> get events => _events;

  void addEvent(Event event) {
    event.id = _nextId++;
    _events.add(event);
    event.scheduleNotification();
    notifyListeners();
  }

  void updateEvent(Event updatedEvent) {
    final index = _events.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      // Cancelar a notificação antiga
      _events[index].cancelNotification();
      _events[index] = updatedEvent;
      // Agendar a nova notificação
      updatedEvent.scheduleNotification();
      notifyListeners();
    }
  }

  void deleteEvent(int id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      _events[index].cancelNotification();
      _events.removeAt(index);
      notifyListeners();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();

  // Função para lidar com o toque na notificação
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    if (payload != null) {
      final eventData = payload.split('|');
      final eventTitle = eventData[0];
      final eventTime = eventData[1];
      final eventVoice = eventData[2];

      await FlutterTts().setLanguage("pt-BR");
      await FlutterTts().setVoice({"name": eventVoice == 'female' ? 'pt-br-x-ftj-local' : 'pt-br-x-stb-local'});
      await FlutterTts().speak("Lembrete: $eventTitle, às $eventTime");
    }
  }

  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EventProvider(),
      child: MaterialApp(
        title: 'Gerenciador de Lembretes',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          cardColor: const Color(0xFF2E2E2E),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00C853), // Verde vibrante
            secondary: Color(0xFFFDD835), // Amarelo para destaque
            background: Color(0xFF1E1E1E),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            elevation: 0,
          ),
          cardTheme: CardTheme(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF00C853),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF333333),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const EventListScreen(),
      ),
    );
  }
}

// Tela de Listagem de Eventos
class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Lembretes'),
        centerTitle: true,
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          if (eventProvider.events.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum lembrete cadastrado.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: eventProvider.events.length,
            itemBuilder: (context, index) {
              final event = eventProvider.events[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Slidable(
                  key: ValueKey(event.id),
                  endActionPane: ActionPane(
                    motion: const StretchMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditEventScreen(event: event),
                            ),
                          );
                        },
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                        label: 'Editar',
                        borderRadius: BorderRadius.circular(12),
                      ),
                      SlidableAction(
                        onPressed: (context) {
                          eventProvider.deleteEvent(event.id);
                        },
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Excluir',
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                  child: Card(
                    child: ListTile(
                      title: Text(event.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Horário: ${event.time.format(context)}'),
                          Text('Repetição: ${_getDaysString(event.weeklyRepeatDays)}'),
                          Text('Som: ${_getSoundTypeString(event)}'),
                        ],
                      ),
                      trailing: const Icon(Icons.notifications_active, color: Color(0xFF00C853)),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditEventScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getDaysString(List<int> days) {
    if (days.isEmpty) return 'Nenhum dia';
    final weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return days.map((day) => weekdays[day - 1]).join(', ');
  }

  String _getSoundTypeString(Event event) {
    if (event.soundType == 'tts') {
      return 'Voz Sintética (${event.ttsVoice == 'male' ? 'masculina' : 'feminina'})';
    } else {
      return 'Áudio Customizado';
    }
  }
}

// Tela de Adicionar/Editar Evento
class AddEditEventScreen extends StatefulWidget {
  final Event? event;
  const AddEditEventScreen({super.key, this.event});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<int> _selectedDays = [];
  String _soundType = 'tts';
  String _ttsVoice = 'male';
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _selectedTime = widget.event!.time;
      _selectedDays = widget.event!.weeklyRepeatDays;
      _soundType = widget.event!.soundType;
      _ttsVoice = widget.event!.ttsVoice ?? 'male';
      _audioPath = widget.event!.audioPath;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioPath = result.files.single.path;
      });
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      final newEvent = Event(
        id: widget.event?.id ?? 0,
        title: _titleController.text,
        time: _selectedTime,
        weeklyRepeatDays: _selectedDays,
        soundType: _soundType,
        audioPath: _audioPath,
        ttsVoice: _ttsVoice,
      );

      final provider = Provider.of<EventProvider>(context, listen: false);
      if (widget.event == null) {
        provider.addEvent(newEvent);
      } else {
        provider.updateEvent(newEvent);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Adicionar Lembrete' : 'Editar Lembrete'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um título.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Horário'),
                trailing: Text(_selectedTime.format(context)),
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _selectedTime = pickedTime;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Repetição Semanal', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              _buildDaySelector(),
              const SizedBox(height: 16),
              const Text('Tipo de Som', style: TextStyle(fontSize: 16)),
              _buildSoundTypeSelector(),
              if (_soundType == 'tts') ...[
                const SizedBox(height: 16),
                const Text('Voz TTS', style: TextStyle(fontSize: 16)),
                _buildTTSVoiceSelector(),
              ] else ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickAudioFile,
                  child: const Text('Selecionar Arquivo de Áudio'),
                ),
                if (_audioPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Arquivo selecionado: ${_audioPath!.split('/').last}'),
                  ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveEvent,
                child: Text(widget.event == null ? 'Salvar Lembrete' : 'Atualizar Lembrete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final weekdays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (index) {
        final day = index + 1;
        final isSelected = _selectedDays.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(day);
              } else {
                _selectedDays.add(day);
              }
            });
          },
          child: CircleAvatar(
            backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[700],
            child: Text(weekdays[index], style: const TextStyle(color: Colors.white)),
          ),
        );
      }),
    );
  }

  Widget _buildSoundTypeSelector() {
    return Row(
      children: [
        Radio<String>(
          value: 'tts',
          groupValue: _soundType,
          onChanged: (value) {
            setState(() {
              _soundType = value!;
            });
          },
        ),
        const Text('Voz Sintética'),
        Radio<String>(
          value: 'audio',
          groupValue: _soundType,
          onChanged: (value) {
            setState(() {
              _soundType = value!;
            });
          },
        ),
        const Text('Áudio'),
      ],
    );
  }

  Widget _buildTTSVoiceSelector() {
    return Row(
      children: [
        Radio<String>(
          value: 'male',
          groupValue: _ttsVoice,
          onChanged: (value) {
            setState(() {
              _ttsVoice = value!;
            });
          },
        ),
        const Text('Masculina'),
        Radio<String>(
          value: 'female',
          groupValue: _ttsVoice,
          onChanged: (value) {
            setState(() {
              _ttsVoice = value!;
            });
          },
        ),
        const Text('Feminina'),
      ],
    );
  }
}
