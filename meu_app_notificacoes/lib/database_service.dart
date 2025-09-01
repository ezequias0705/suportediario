import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'event.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('eventos.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE eventos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT,
          hora TEXT,
          som TEXT,
          dias TEXT,
          ativo INTEGER
        )
      ''');
    });
  }

  static Future<int> insert(Evento evento) async {
    final db = await database;
    return await db.insert('eventos', evento.toMap());
  }

  static Future<List<Evento>> getAll() async {
    final db = await database;
    final maps = await db.query('eventos');
    return List.generate(maps.length, (i) => Evento.fromMap(maps[i]));
  }

  static Future<int> update(Evento evento) async {
    final db = await database;
    return await db.update('eventos', evento.toMap(), where: 'id = ?', whereArgs: [evento.id]);
  }

  static Future<int> delete(int id) async {
    final db = await database;
    return await db.delete('eventos', where: 'id = ?', whereArgs: [id]);
  }
}
