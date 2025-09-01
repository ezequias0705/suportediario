import 'package:flutter/material.dart';
import 'event.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EventListScreen(),
    );
  }
}

class EventListScreen extends StatefulWidget {
  @override
  _EventListScreenState createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  List<Evento> eventos = [];

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  void loadEvents() async {
    eventos = await DatabaseService.getAll();
    setState(() {});
    scheduleAll();
  }

  void scheduleAll() {
    for (var e in eventos) {
      final parts = e.hora.split(':');
      final now = DateTime.now();
      final scheduled = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      NotificationService.scheduleNotification(
        id: e.id ?? 0,
        title: e.nome,
        body: "Hora de ${e.nome}",
        sound: e.som,
        scheduledTime: scheduled,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Meus Lembretes")),
      body: ListView.builder(
        itemCount: eventos.length,
        itemBuilder: (context, index) {
          final e = eventos[index];
          return ListTile(
            title: Text(e.nome),
            subtitle: Text("${e.hora} - Dias: ${e.dias.join(', ')}"),
            trailing: IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                final now = DateTime.now();
                NotificationService.scheduleNotification(
                  id: e.id ?? index,
                  title: e.nome,
                  body: "Hora de ${e.nome}",
                  sound: e.som,
                  scheduledTime: now.add(Duration(seconds: 5)),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final newEvent = Evento(nome: "Novo Lembrete", hora: "12:00", som: "som1.mp3", dias: ["Seg", "Ter"]);
          await DatabaseService.insert(newEvent);
          loadEvents();
        },
      ),
    );
  }
}
