class Evento {
  int? id;
  String nome;
  String hora; // HH:mm
  String som; 
  List<String> dias; // ["Seg", "Ter"]
  bool ativo;

  Evento({
    this.id,
    required this.nome,
    required this.hora,
    required this.som,
    required this.dias,
    this.ativo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'hora': hora,
      'som': som,
      'dias': dias.join(','),
      'ativo': ativo ? 1 : 0,
    };
  }

  factory Evento.fromMap(Map<String, dynamic> map) {
    return Evento(
      id: map['id'],
      nome: map['nome'],
      hora: map['hora'],
      som: map['som'],
      dias: map['dias'].toString().split(','),
      ativo: map['ativo'] == 1,
    );
  }
}
