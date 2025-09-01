import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'event.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => EventProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Notificações',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0D1F3C),
        scaffoldBackgroundColor: const Color(0xFF162447),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0D1F3C),
          secondary: Color(0xFF1F4287),
        ),
        cardColor: const Color(0xFF1F4287),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1F4287),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23395D),
          border: OutlineInputBorder(),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: EventListScreen(),
    );
  }
}

class EventListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Lembretes'),
        backgroundColor: const Color(0xFF0D1F3C),
      ),
      body: provider.events.isEmpty
          ? const Center(
              child: Text('Nenhum lembrete cadastrado.'),
            )
          : ListView.builder(
              itemCount: provider.events.length,
              itemBuilder: (context, index) {
                final event = provider.events[index];
                return Slidable(
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (_) {
                          provider.deleteEvent(event);
                        },
                        backgroundColor: Colors.red,
                        icon: Icons.delete,
                        label: 'Excluir',
                      ),
                      SlidableAction(
                        onPressed: (_) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditEventScreen(event: event),
                            ),
                          );
                        },
                        backgroundColor: Colors.blue.shade700,
                        icon: Icons.edit,
                        label: 'Editar',
                      ),
                    ],
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      title: Text(
                        event.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      subtitle: Text(
                        "${DateFormat.Hm().format(event.time)} | ${event.soundLabel} | Repete: ${event.repeatLabel}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(Icons.notifications_active, color: Colors.lightBlueAccent),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditEventScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddEditEventScreen extends StatefulWidget {
  final Event? event;
  const AddEditEventScreen({this.event, Key? key}) : super(key: key);

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  TimeOfDay? _selectedTime;
  List<bool> _repeatDays = List.generate(7, (_) => false);

  NotificationSoundType _soundType = NotificationSoundType.audioFile;
  String _selectedSound = 'som1.mp3';
  String? _pickedAudioPath;
  String _ttsVoice = "female";

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.title);
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.time);
      _repeatDays = List.from(widget.event!.repeatDays);
      _soundType = widget.event!.soundType;
      _ttsVoice = widget.event!.ttsVoice;
      if (_soundType == NotificationSoundType.audioFile) {
        if (widget.event!.sound.startsWith('/')) {
          _pickedAudioPath = widget.event!.sound;
          _selectedSound = '';
        } else {
          _selectedSound = widget.event!.sound;
        }
      }
    } else {
      _titleController = TextEditingController();
      _selectedTime = TimeOfDay.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Novo Lembrete' : 'Editar Lembrete'),
        backgroundColor: const Color(0xFF0D1F3C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => value == null || value.isEmpty ? 'Informe o título' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Horário: ${_selectedTime?.format(context) ?? ''}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text("Tipo de som da notificação", style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile(
                title: const Text("Áudio personalizado"),
                value: NotificationSoundType.audioFile,
                groupValue: _soundType,
                onChanged: (val) => setState(() => _soundType = val!),
              ),
              RadioListTile(
                title: const Text("Voz sintética (fala horário e nome)"),
                value: NotificationSoundType.tts,
                groupValue: _soundType,
                onChanged: (val) => setState(() => _soundType = val!),
              ),
              if (_soundType == NotificationSoundType.audioFile) ...[
                DropdownButtonFormField<String>(
                  value: _selectedSound.isEmpty ? null : _selectedSound,
                  items: const [
                    DropdownMenuItem(
                      value: 'som1.mp3',
                      child: Text('Som de Remédio'),
                    ),
                    DropdownMenuItem(
                      value: 'som2.mp3',
                      child: Text('Som Padrão'),
                    ),
                  ],
                  decoration: const InputDecoration(labelText: 'Som padrão'),
                  onChanged: (val) {
                    setState(() {
                      _selectedSound = val ?? 'som1.mp3';
                      _pickedAudioPath = null;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder),
                  label: Text(_pickedAudioPath == null
                      ? "Selecionar arquivo de áudio"
                      : "Áudio selecionado"),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3', 'wav', 'ogg'],
                    );
                    if (result != null && result.files.single.path != null) {
                      setState(() {
                        _pickedAudioPath = result.files.single.path;
                        _selectedSound = '';
                      });
                    }
                  },
                ),
              ],
              if (_soundType == NotificationSoundType.tts)
                DropdownButtonFormField<String>(
                  value: _ttsVoice,
                  items: const [
                    DropdownMenuItem(value: "female", child: Text("Voz feminina")),
                    DropdownMenuItem(value: "male", child: Text("Voz masculina")),
                  ],
                  onChanged: (val) => setState(() => _ttsVoice = val ?? "female"),
                  decoration: const InputDecoration(labelText: "Tipo de voz"),
                ),
              const SizedBox(height: 16),
              const Text('Repetir em:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
                  return FilterChip(
                    label: Text(days[index]),
                    selected: _repeatDays[index],
                    onSelected: (selected) {
                      setState(() => _repeatDays[index] = selected);
                    },
                  );
                }),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() && _selectedTime != null) {
                    final now = DateTime.now();
                    final scheduledTime = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      _selectedTime!.hour,
                      _selectedTime!.minute,
                    );
                    String soundValue = _soundType == NotificationSoundType.audioFile
                        ? (_pickedAudioPath ?? _selectedSound)
                        : "";
                    final newEvent = Event(
                      id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch,
                      title: _titleController.text,
                      time: scheduledTime,
                      sound: soundValue,
                      repeatDays: List.from(_repeatDays),
                      soundType: _soundType,
                      ttsVoice: _ttsVoice,
                    );
                    if (widget.event == null) {
                      provider.addEvent(newEvent);
                    } else {
                      provider.updateEvent(newEvent);
                    }
                    Navigator.pop(context);
                  }
                },
                child: Text(widget.event == null ? 'Cadastrar' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
