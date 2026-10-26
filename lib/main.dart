import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const KarateScoreboardApp());
}

class KarateScoreboardApp extends StatelessWidget {
  const KarateScoreboardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'KARATE ELITE',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF080B12),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF53D6C5), brightness: Brightness.dark),
          fontFamily: 'Roboto',
        ),
        home: const ScoreboardPage(),
      );
}

class MatchRecord {
  final String aka;
  final String ao;
  final int akaScore;
  final int aoScore;
  final String winner;
  final String date;
  MatchRecord({required this.aka, required this.ao, required this.akaScore, required this.aoScore, required this.winner, required this.date});
  Map<String, dynamic> toJson() => {'aka': aka, 'ao': ao, 'akaScore': akaScore, 'aoScore': aoScore, 'winner': winner, 'date': date};
  factory MatchRecord.fromJson(Map<String, dynamic> j) => MatchRecord(aka: j['aka'] ?? 'AKA', ao: j['ao'] ?? 'AO', akaScore: j['akaScore'] ?? 0, aoScore: j['aoScore'] ?? 0, winner: j['winner'] ?? '-', date: j['date'] ?? '');
}

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});
  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  static const red = Color(0xFFFF4057);
  static const blue = Color(0xFF378BFF);
  static const panel = Color(0xFF111722);
  int akaScore = 0, aoScore = 0, seconds = 120;
  int roundSeconds = 120;
  bool running = false, ended = false;
  Timer? timer;
  String akaName = 'AKA', aoName = 'AO';
  final List<Map<String, dynamic>> undoStack = [];
  List<MatchRecord> history = [];
  final akaController = TextEditingController(text: 'AKA');
  final aoController = TextEditingController(text: 'AO');

  @override
  void initState() { super.initState(); _loadHistory(); }
  @override
  void dispose() { timer?.cancel(); akaController.dispose(); aoController.dispose(); super.dispose(); }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('match_history');
    if (raw != null) {
      try { setState(() => history = (jsonDecode(raw) as List).map((e) => MatchRecord.fromJson(Map<String, dynamic>.from(e))).toList()); } catch (_) {}
    }
  }
  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('match_history', jsonEncode(history.map((e) => e.toJson()).toList()));
  }
  String get timeText => '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  String get winner => akaScore == aoScore ? 'DRAW' : (akaScore > aoScore ? akaName : aoName);
  void _snapshot() { undoStack.add({'aka': akaScore, 'ao': aoScore, 'seconds': seconds, 'ended': ended}); if (undoStack.length > 40) undoStack.removeAt(0); }
  void _score(bool isAka, int points) {
    if (ended) return;
    _snapshot();
    setState(() { if (isAka) { akaScore += points; } else { aoScore += points; } });
    SystemSound.play(SystemSoundType.click);
    if ((akaScore - aoScore).abs() >= 8) _finish();
  }
  void _penalty(bool isAka) {
    if (ended) return;
    _snapshot();
    setState(() { if (isAka) { aoScore = (aoScore + 1); } else { akaScore = (akaScore + 1); } });
    SystemSound.play(SystemSoundType.alert);
    if ((akaScore - aoScore).abs() >= 8) _finish();
  }
  void _toggleTimer() {
    if (ended) return;
    if (running) { timer?.cancel(); setState(() => running = false); }
    else {
      setState(() => running = true);
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (seconds <= 1) { setState(() { seconds = 0; running = false; }); t.cancel(); _finish(); }
        else { setState(() => seconds--); }
      });
    }
  }
  void _finish() {
    if (ended) return;
    timer?.cancel();
    setState(() { running = false; ended = true; });
    final rec = MatchRecord(aka: akaName, ao: aoName, akaScore: akaScore, aoScore: aoScore, winner: winner, date: DateTime.now().toLocal().toString().substring(0, 16));
    history.insert(0, rec);
    if (history.length > 100) history = history.take(100).toList();
    _saveHistory();
    _winnerDialog();
  }
  Future<void> _winnerDialog() async {
    if (!mounted) return;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      backgroundColor: panel,
      title: const Text('MATCH COMPLETE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Text(winner, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: winner == akaName ? red : winner == aoName ? blue : Colors.white)), const SizedBox(height: 8), Text('$akaScore  —  $aoScore', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
      actions: [FilledButton(onPressed: () { Navigator.pop(ctx); _newMatch(); }, child: const Text('NEW MATCH')), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
    ));
  }
  void _undo() {
    if (undoStack.isEmpty) return;
    final s = undoStack.removeLast(); timer?.cancel();
    setState(() { akaScore = s['aka']; aoScore = s['ao']; seconds = s['seconds']; ended = s['ended']; running = false; });
  }
  void _newMatch() {
    timer?.cancel();
    setState(() { akaScore = 0; aoScore = 0; seconds = roundSeconds; running = false; ended = false; undoStack.clear(); });
  }
  Future<void> _settings() async {
    final a = TextEditingController(text: akaName), b = TextEditingController(text: aoName);
    int selected = roundSeconds;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
      backgroundColor: panel,
      title: const Text('MATCH SETUP'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: a, maxLength: 18, decoration: const InputDecoration(labelText: 'AKA / RED athlete name')),
        TextField(controller: b, maxLength: 18, decoration: const InputDecoration(labelText: 'AO / BLUE athlete name')),
        const SizedBox(height: 12), const Align(alignment: Alignment.centerLeft, child: Text('ROUND DURATION')),
        const SizedBox(height: 8), Wrap(spacing: 8, children: [60, 90, 120, 180, 240].map((v) => ChoiceChip(label: Text('${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}'), selected: selected == v, onSelected: (_) => update(() => selected = v)).toList()),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), FilledButton(onPressed: () { setState(() { akaName = a.text.trim().isEmpty ? 'AKA' : a.text.trim(); aoName = b.text.trim().isEmpty ? 'AO' : b.text.trim(); akaController.text = akaName; aoController.text = aoName; roundSeconds = selected; }); Navigator.pop(ctx); _newMatch(); }, child: const Text('APPLY & RESET'))],
    )));
    a.dispose(); b.dispose();
  }
  Future<void> _showHistory() async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: panel, title: const Text('MATCH HISTORY'),
      content: SizedBox(width: 480, height: 300, child: history.isEmpty ? const Center(child: Text('No saved matches yet')) : ListView.separated(itemCount: history.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final h = history[i]; return ListTile(dense: true, title: Text('${h.aka} ${h.akaScore}  —  ${h.aoScore} ${h.ao}'), subtitle: Text('${h.date}  •  Winner: ${h.winner}'), leading: Icon(Icons.emoji_events_outlined, color: h.winner == h.aka ? red : blue)); })),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')), if (history.isNotEmpty) TextButton(onPressed: () async { setState(() => history.clear()); await _saveHistory(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('CLEAR HISTORY'))],
    ));
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [const Icon(Icons.sports_martial_arts, color: Color(0xFF53D6C5), size: 24), const SizedBox(width: 8), const Text('KARATE', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 2)), const Text('  /  ELITE', style: TextStyle(fontSize: 13, color: Color(0xFF7F8CA3), letterSpacing: 2)), const Spacer(), _topButton(Icons.history, 'HISTORY', _showHistory), const SizedBox(width: 7), _topButton(Icons.tune, 'SETUP', _settings), const SizedBox(width: 7), _topButton(Icons.undo_rounded, 'UNDO', _undo), const SizedBox(width: 7), _topButton(Icons.refresh, 'RESET', _confirmReset)],),
      const SizedBox(height: 10),
      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _fighterCard(name: akaName, score: akaScore, color: red, isAka: true)),
        SizedBox(width: size.width * .27, child: _centerPanel()),
        Expanded(child: _fighterCard(name: aoName, score: aoScore, color: blue, isAka: false)),
      ])),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF657187)), const SizedBox(width: 6), Text('TAP +1 / +2 / +3 TO SCORE  •  8-POINT LEAD ENDS MATCH  •  TIMER IS MANUAL', style: TextStyle(fontSize: size.height < 420 ? 8 : 10, color: const Color(0xFF657187), letterSpacing: 1))]),
    ]))));
  }
  Widget _topButton(IconData icon, String label, VoidCallback action) => OutlinedButton.icon(onPressed: action, icon: Icon(icon, size: 15), label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: .7)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFBBC6D8), side: const BorderSide(color: Color(0xFF263143)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), visualDensity: VisualDensity.compact));
  Widget _fighterCard({required String name, required int score, required Color color, required bool isAka}) => Container(margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: .6), width: 1.2), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .13), panel, panel])), child: Column(children: [
    Container(height: 5, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),
    const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Text(isAka ? 'AKA  /  RED' : 'AO  /  BLUE', style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12))]),
    Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text('$score', style: TextStyle(fontSize: 115, height: 1, fontWeight: FontWeight.w900, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]))))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .5))),
    const SizedBox(height: 10),
    Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: Row(children: [for (final p in [1, 2, 3]) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _scoreButton('+$p', p, color, () => _score(isAka, p))))])),
    Padding(padding: const EdgeInsets.fromLTRB(13, 0, 13, 12), child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _penalty(isAka), icon: const Icon(Icons.flag_outlined, size: 15), label: const Text('PENALTY  •  +1 OPPONENT'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9BA8BC), side: const BorderSide(color: Color(0xFF2A3547)), padding: const EdgeInsets.symmetric(vertical: 8), textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))))),
  ]));
  Widget _scoreButton(String label, int points, Color color, VoidCallback action) => FilledButton(onPressed: action, style: FilledButton.styleFrom(backgroundColor: color.withValues(alpha: .16), foregroundColor: color, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withValues(alpha: .45))), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), child: Text(label));
  Widget _centerPanel() => Container(margin: const EdgeInsets.symmetric(horizontal: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0D121B), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF202A39))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('KUMITE', style: TextStyle(color: Color(0xFF74839A), fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11)),
    const SizedBox(height: 8),
    FittedBox(fit: BoxFit.scaleDown, child: Text(timeText, style: TextStyle(fontSize: 45, height: 1, fontWeight: FontWeight.w900, color: seconds <= 10 ? const Color(0xFFFFC857) : Colors.white, fontFeatures: const [FontFeature.tabularFigures()]))),
    const SizedBox(height: 10),
    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _toggleTimer, icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20), label: Text(running ? 'PAUSE' : 'START'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF53D6C5), foregroundColor: const Color(0xFF07110F), padding: const EdgeInsets.symmetric(vertical: 11), textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)))),
    const SizedBox(height: 6),
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { timer?.cancel(); setState(() { running = false; seconds = roundSeconds; }); }, icon: const Icon(Icons.restart_alt, size: 16), label: const Text('RESET CLOCK'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFABB7C9), side: const BorderSide(color: Color(0xFF2A3547)), padding: const EdgeInsets.symmetric(vertical: 8), textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
    const SizedBox(height: 12),
    Container(width: double.infinity, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(10)), child: Column(children: [const Text('MATCH STATUS', style: TextStyle(color: Color(0xFF74839A), fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(ended ? 'FINISHED' : running ? 'IN PROGRESS' : 'READY', style: TextStyle(color: ended ? const Color(0xFFFFC857) : running ? const Color(0xFF53D6C5) : const Color(0xFFBBC6D8), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1))])),
    const Spacer(),
    SizedBox(width: double.infinity, child: TextButton.icon(onPressed: _confirmFinish, icon: const Icon(Icons.flag, size: 15), label: const Text('END MATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC857))),
  ]));
  Future<void> _confirmReset() async => showDialog<void>(context: context, builder: (ctx) => AlertDialog(backgroundColor: panel, title: const Text('Reset match?'), content: const Text('Scores and clock will be reset. The match will not be added to history.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), FilledButton(onPressed: () { Navigator.pop(ctx); _newMatch(); }, child: const Text('RESET'))]));
  Future<void> _confirmFinish() async { if (ended) return; final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: panel, title: const Text('End this match?'), content: const Text('The current score will be saved to match history.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('END MATCH'))])); if (ok == true) _finish(); }
}
