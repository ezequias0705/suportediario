import 'package:flutter/material.dart';

enum NotificationSoundType { audioFile, tts }

class Event {
  final int id;
  final String title;
  final DateTime time;
  final String sound; // asset ou caminho local (se audioFile) ou texto TTS
  final List<bool> repeatDays; // [Dom, Seg, Ter, Qua, Qui, Sex, Sáb]
  final NotificationSoundType soundType;
  final String ttsVoice; // "male" ou "female"

  Event({
    required this.id,
    required this.title,
    required this.time,
    required this.sound,
    required this.repeatDays,
    required this.soundType,
    this.ttsVoice = "female",
  });

  String get soundLabel {
    switch (soundType) {
      case NotificationSoundType.tts:
        return "Voz (");
      default:
        switch (sound) {
          case 'som1.mp3':
            return 'Remédio';
          case 'som2.mp3':
            return 'Padrão';
          default:
            return 'Personalizado';
        }
    }
  }

  String get repeatLabel {
    if (repeatDays.every((e) => e)) return 'Todos os dias';
    final dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    List<String> diasSelecionados = [];
    for (int i = 0; i < repeatDays.length; i++) {
      if (repeatDays[i]) diasSelecionados.add(dias[i]);
    }
    return diasSelecionados.isEmpty ? 'Não repete' : diasSelecionados.join(', ');
  }
}

class EventProvider extends ChangeNotifier {
  List<Event> _events = [];

  List<Event> get events => _events;

  void addEvent(Event event) {
    _events.add(event);
    NotificationService().scheduleNotification(event);
    notifyListeners();
  }

  void updateEvent(Event event) {
    int idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
      NotificationService().cancelNotification(event.id);
      NotificationService().scheduleNotification(event);
      notifyListeners();
    }
  }

  void deleteEvent(Event event) {
    _events.removeWhere((e) => e.id == event.id);
    NotificationService().cancelNotification(event.id);
    notifyListeners();
  }
}