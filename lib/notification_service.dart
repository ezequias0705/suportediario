import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'event.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> scheduleNotification(Event event) async {
    for (int i = 0; i < 7; i++) {
      if (event.repeatDays[i]) {
        final scheduledDate = _nextInstanceOfDay(event.time, i);

        if (event.soundType == NotificationSoundType.tts) {
          // TTS: faz a voz falar o nome e horário do lembrete
          await _scheduleTtsNotification(event, scheduledDate, event.id * 10 + i);
        } else {
          final androidDetails = event.sound.startsWith('/')
              ? AndroidNotificationDetails(
                  'agenda_channel',
                  'Agenda Notificações',
                  importance: Importance.max,
                  priority: Priority.high,
                  sound: FilePathAndroidNotificationSound(event.sound),
                )
              : AndroidNotificationDetails(
                  'agenda_channel',
                  'Agenda Notificações',
                  importance: Importance.max,
                  priority: Priority.high,
                  sound: RawResourceAndroidNotificationSound(
                    event.sound.replaceAll('.mp3', ''),
                  ),
                );
          await flutterLocalNotificationsPlugin.zonedSchedule(
            event.id * 10 + i,
            event.title,
            'Está na hora do seu lembrete!',
            scheduledDate,
            NotificationDetails(android: androidDetails),
            androidAllowWhileIdle: true,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
  }

  Future<void> _scheduleTtsNotification(Event event, tz.TZDateTime scheduledDate, int notifId) async {
    // Apenas dispara a notificação padrão, e executa TTS ao abrir o app.
    // (Notificações Android não tocam áudio TTS automaticamente sem workaround de foreground service)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notifId,
      event.title,
      'Clique para ouvir o lembrete',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'agenda_channel',
          'Agenda Notificações',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'tts|${event.id}',
    );
  }

  tz.TZDateTime _nextInstanceOfDay(DateTime time, int dayOfWeek) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduledDate.weekday % 7 != (dayOfWeek + 1) % 7 ||
        scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelNotification(int eventId) async {
    for (int i = 0; i < 7; i++) {
      await flutterLocalNotificationsPlugin.cancel(eventId * 10 + i);
    }
  }

  // Para ser chamado ao abrir o app via notificação, usando payload
  Future<void> playTts(Event event) async {
    final tts = FlutterTts();
    await tts.setLanguage("pt-BR");
    if (event.ttsVoice == "male") {
      await tts.setVoice({"name": "pt-br-x-ptz-network", "locale": "pt-BR"});
    } else {
      await tts.setVoice({"name": "pt-br-x-ptz-local", "locale": "pt-BR"});
    }
    String message =
        "Agora são ${event.time.hour} horas e ${event.time.minute} minutos. ${event.title}.";
    await tts.speak(message);
  }
}