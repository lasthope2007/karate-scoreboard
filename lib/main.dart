
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KarateScoreboardApp());
}

const Color bgColor = Color(0xFF090D14);
const Color panelColor = Color(0xFF131B28);
const Color akaColor = Color(0xFFFF3448);
const Color aoColor = Color(0xFF2589FF);
const Color goldColor = Color(0xFFFFC857);

class KarateScoreboardApp extends StatelessWidget {
  const KarateScoreboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Z-Score',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        colorScheme: const ColorScheme.dark(
          primary: goldColor,
          surface: panelColor,
        ),
        useMaterial3: true,
      ),
      home: const ScoreboardPage(),
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> with SingleTickerProviderStateMixin {
  static const int maxScore = 8;

  int akaScore = 0;
  int aoScore = 0;
  int akaFouls = 0;
  int aoFouls = 0;
  int akaIppon = 0, aoIppon = 0, akaWazaAri = 0, aoWazaAri = 0;
  bool akaSenshu = false, aoSenshu = false;
  final Set<String> akaPenalties = <String>{};
  final Set<String> aoPenalties = <String>{};
  int matchDuration = 120;
  int remainingSeconds = 120;

  String akaName = 'AKA';
  String aoName = 'AO';

  bool isRunning = false;
  bool matchFinished = false;
  bool isFullscreen = false;

  Timer? timer;
  late final AnimationController _blinkController;
  late final Animation<double> _winnerOpacity;

  final List<_ScoreSnapshot> history = [];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _winnerOpacity = Tween<double>(begin: 0.25, end: 1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _setLandscape();
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _blinkController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _saveHistory() {
    history.add(
      _ScoreSnapshot(
        akaScore: akaScore,
        aoScore: aoScore,
        akaFouls: akaFouls,
        aoFouls: aoFouls,
        akaIppon: akaIppon, aoIppon: aoIppon,
        akaWazaAri: akaWazaAri, aoWazaAri: aoWazaAri,
        akaSenshu: akaSenshu, aoSenshu: aoSenshu,
        akaPenalties: Set<String>.from(akaPenalties),
        aoPenalties: Set<String>.from(aoPenalties),
        remainingSeconds: remainingSeconds,
        isRunning: isRunning,
        matchFinished: matchFinished,
      ),
    );

    if (history.length > 100) {
      history.removeAt(0);
    }
  }

  void _startTimer() {
    if (isRunning || matchFinished || remainingSeconds <= 0) return;

    setState(() => isRunning = true);

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (remainingSeconds <= 1) {
        t.cancel();
        setState(() {
          remainingSeconds = 0;
          isRunning = false;
          matchFinished = true;
        });
        _startWinnerBlink();
        return;
      }

      setState(() => remainingSeconds--);
      if (remainingSeconds <= 15 && remainingSeconds > 0) _playAlert();
      if (remainingSeconds == 0) _playAlert();
    });
  }

  void _pauseTimer() {
    timer?.cancel();
    setState(() => isRunning = false);
  }

  void _resetMatch() {
    timer?.cancel();

    setState(() {
      akaScore = 0;
      aoScore = 0;
      akaFouls = 0;
      aoFouls = 0;
      akaIppon = aoIppon = akaWazaAri = aoWazaAri = 0;
      akaSenshu = aoSenshu = false;
      akaPenalties.clear();
      aoPenalties.clear();
      remainingSeconds = matchDuration;
      isRunning = false;
      matchFinished = false;
      history.clear();
      _blinkController.stop();
      _blinkController.reset();
    });
  }

  void _changeScore(bool isAka, int points) {
    if (matchFinished) return;

    _saveHistory();

    setState(() {
      if (isAka) {
        akaScore = (akaScore + points).clamp(0, 99);
        if (points == 3) akaIppon++;
        if (points == 2) akaWazaAri++;
      } else {
        aoScore = (aoScore + points).clamp(0, 99);
        if (points == 3) aoIppon++;
        if (points == 2) aoWazaAri++;
      }
    });

    if ((akaScore - aoScore).abs() >= maxScore) {
      _finishMatch();
    }
  }

  void _changeFouls(bool isAka, int delta) {
    if (matchFinished) return;
    _saveHistory();
    setState(() {
      if (isAka) {
        akaFouls = (akaFouls + delta).clamp(0, 99);
      } else {
        aoFouls = (aoFouls + delta).clamp(0, 99);
      }
    });
  }

  void _toggleSenshu(bool isAka) {
    if (matchFinished) return;
    _saveHistory();
    setState(() {
      if (isAka) { akaSenshu = !akaSenshu; if (akaSenshu) aoSenshu = false; }
      else { aoSenshu = !aoSenshu; if (aoSenshu) akaSenshu = false; }
    });
  }

  void _togglePenalty(bool isAka, String penalty) {
    if (matchFinished) return;
    _saveHistory();
    setState(() {
      final p = isAka ? akaPenalties : aoPenalties;
      if (p.contains(penalty)) { p.remove(penalty); }
      else {
        p.add(penalty);
        if (penalty == 'HANSOKU') { isRunning = false; timer?.cancel(); matchFinished = true; }
      }
    });
    if (penalty == 'HANSOKU' && (isAka ? akaPenalties.contains(penalty) : aoPenalties.contains(penalty))) {
      _playAlert(); _startWinnerBlink();
    }
  }

  void _adjustTime(int delta) {
    if (matchFinished) return;
    _saveHistory();
    setState(() {
      remainingSeconds = (remainingSeconds + delta).clamp(0, 599);
    });
    if (remainingSeconds == 0) _finishMatch();
  }

  Future<void> _playAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Some Android devices or system profiles may silence system alerts.
    }
  }

  void _startWinnerBlink() {
    if (akaScore == aoScore) {
      _blinkController.stop();
      _blinkController.reset();
      return;
    }
    _blinkController.repeat(reverse: true);
  }

  void _undo() {
    if (history.isEmpty) return;

    final previous = history.removeLast();

    timer?.cancel();

    setState(() {
      akaScore = previous.akaScore;
      aoScore = previous.aoScore;
      akaFouls = previous.akaFouls;
      aoFouls = previous.aoFouls;
      akaIppon = previous.akaIppon; aoIppon = previous.aoIppon;
      akaWazaAri = previous.akaWazaAri; aoWazaAri = previous.aoWazaAri;
      akaSenshu = previous.akaSenshu; aoSenshu = previous.aoSenshu;
      akaPenalties..clear()..addAll(previous.akaPenalties);
      aoPenalties..clear()..addAll(previous.aoPenalties);
      remainingSeconds = previous.remainingSeconds;
      isRunning = false;
      matchFinished = previous.matchFinished;
    });
    if (matchFinished) {
      _startWinnerBlink();
    } else {
      _blinkController.stop();
      _blinkController.reset();
    }
  }

  void _finishMatch() {
    timer?.cancel();

    setState(() {
      isRunning = false;
      matchFinished = true;
    });
    _playAlert();
    _startWinnerBlink();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  bool get _akaHansoku => akaPenalties.contains('HANSOKU');
  bool get _aoHansoku => aoPenalties.contains('HANSOKU');

  String get _winner {
    if (_akaHansoku && !_aoHansoku) return aoName;
    if (_aoHansoku && !_akaHansoku) return akaName;
    if (akaScore != aoScore) return akaScore > aoScore ? akaName : aoName;
    if (akaSenshu != aoSenshu) return akaSenshu ? akaName : aoName;
    if (akaIppon != aoIppon) return akaIppon > aoIppon ? akaName : aoName;
    if (akaWazaAri != aoWazaAri) return akaWazaAri > aoWazaAri ? akaName : aoName;
    return 'HANTEI REQUIRED';
  }

  Future<void> _editNames() async {
    final akaController = TextEditingController(text: akaName);
    final aoController = TextEditingController(text: aoName);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: panelColor,
          title: const Text('ATHLETE NAMES'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: akaController,
                decoration: const InputDecoration(labelText: 'AKA / Red'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aoController,
                decoration: const InputDecoration(labelText: 'AO / Blue'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                [
                  akaController.text.trim(),
                  aoController.text.trim(),
                ],
              ),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    akaController.dispose();
    aoController.dispose();

    if (result != null && mounted) {
      setState(() {
        akaName = result[0].isEmpty ? 'AKA' : result[0];
        aoName = result[1].isEmpty ? 'AO' : result[1];
      });
    }
  }

  Future<void> _chooseDuration() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: panelColor,
          title: const Text('MATCH DURATION'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [60, 90, 120, 180, 240].map((v) {
              return ChoiceChip(
                label: Text(
                  '${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}',
                ),
                selected: matchDuration == v,
                onSelected: (_) => Navigator.pop(dialogContext, v),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      timer?.cancel();

      _blinkController.stop();
      _blinkController.reset();
      setState(() {
        matchDuration = selected;
        remainingSeconds = selected;
        isRunning = false;
        matchFinished = false;
        history.clear();
      });
    }
  }

  Future<void> _confirmFinish() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: panelColor,
          title: const Text('END MATCH?'),
          content: const Text(
            'Are you sure you want to finish this match?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('END MATCH'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      _finishMatch();
    }
  }

  Widget _scorePanel({
    required String name,
    required int score,
    required Color color,
    required bool isAka,
  }) {
    final isWinner = matchFinished && ((_winner == akaName && isAka) || (_winner == aoName && !isAka));
    final penalties = isAka ? akaPenalties : aoPenalties;
    final senshu = isAka ? akaSenshu : aoSenshu;
    final ippon = isAka ? akaIppon : aoIppon;
    final wazaAri = isAka ? akaWazaAri : aoWazaAri;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isWinner ? color.withValues(alpha: 0.32) : panelColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color, width: isWinner ? 5 : 2),
          boxShadow: isWinner ? [BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 28, spreadRadius: 4)] : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            if (isWinner)
              FadeTransition(opacity: _winnerOpacity, child: Text('WINNER', style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 3))),
            if (isWinner)
              FadeTransition(opacity: _winnerOpacity, child: Text('$score', style: TextStyle(color: color, fontSize: 88, height: 1, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])))
            else
              Text('$score', style: const TextStyle(color: Colors.white, fontSize: 88, height: 1, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _scoreButton(
                  label: '+1',
                  color: color,
                  onPressed: () => _changeScore(isAka, 1),
                ),
                const SizedBox(width: 8),
                _scoreButton(
                  label: '+2',
                  color: color,
                  onPressed: () => _changeScore(isAka, 2),
                ),
                const SizedBox(width: 8),
                _scoreButton(
                  label: '+3',
                  color: color,
                  onPressed: () => _changeScore(isAka, 3),
                ),
                const SizedBox(width: 8),
                _scoreButton(
                  label: '−1',
                  color: Colors.white70,
                  onPressed: () => _changeScore(isAka, -1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('IPPON $ippon  •  WAZA-ARI $wazaAri', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Wrap(alignment: WrapAlignment.center, spacing: 3, runSpacing: 2, children: [
              _smallToggle('SENSHU', senshu, color, () => _toggleSenshu(isAka)),
              _smallToggle('CHUI 1', penalties.contains('CHUI 1'), color, () => _togglePenalty(isAka, 'CHUI 1')),
              _smallToggle('CHUI 2', penalties.contains('CHUI 2'), color, () => _togglePenalty(isAka, 'CHUI 2')),
              _smallToggle('CHUI 3', penalties.contains('CHUI 3'), color, () => _togglePenalty(isAka, 'CHUI 3')),
              _smallToggle('HANSOKU-CHUI', penalties.contains('HANSOKU-CHUI'), color, () => _togglePenalty(isAka, 'HANSOKU-CHUI')),
              _smallToggle('HANSOKU', penalties.contains('HANSOKU'), color, () => _togglePenalty(isAka, 'HANSOKU')),
            ]),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'WARNINGS  ${isAka ? akaFouls : aoFouls}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                _scoreButton(
                  label: '−',
                  color: Colors.white70,
                  onPressed: () => _changeFouls(isAka, -1),
                ),
                const SizedBox(width: 4),
                _scoreButton(
                  label: '+',
                  color: color,
                  onPressed: () => _changeFouls(isAka, 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallToggle(String label, bool active, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: active ? Colors.black : color, backgroundColor: active ? color : Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), minimumSize: const Size(0, 24), tapTargetSize: MaterialTapTargetSize.shrinkWrap, side: BorderSide(color: active ? color : color.withValues(alpha: 0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
      child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _scoreButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _centerPanel() {
    return SizedBox(
      width: 190,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            'Z-SCORE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: goldColor,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: FittedBox(
              child: Text(
                _formatTime(remainingSeconds),
                style: TextStyle(
                  color: remainingSeconds <= 10
                      ? akaColor
                      : Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (matchFinished)
            FadeTransition(
              opacity: _winnerOpacity,
              child: Text(
                'WINNER: $_winner',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Text(
              'KUMITE • MATCH',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Subtract one second',
                onPressed: () => _adjustTime(-1),
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.white70,
                visualDensity: VisualDensity.compact,
              ),
              const Text('1 SEC', style: TextStyle(fontSize: 10, color: Colors.white54)),
              IconButton(
                tooltip: 'Add one second',
                onPressed: () => _adjustTime(1),
                icon: const Icon(Icons.add_circle_outline),
                color: goldColor,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: isRunning ? _pauseTimer : _startTimer,
            icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
            label: Text(isRunning ? 'PAUSE' : 'START'),
          ),
          OutlinedButton.icon(
            onPressed: _undo,
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('UNDO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_martial_arts, color: goldColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Z-SCORE SCOREBOARD',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Athlete names',
                    onPressed: _editNames,
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Match duration',
                    onPressed: _chooseDuration,
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: _undo,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Reset match',
                    onPressed: _resetMatch,
                    icon: const Icon(Icons.restart_alt),
                  ),
                  IconButton(
                    tooltip: 'Toggle system UI',
                    onPressed: () async {
                      isFullscreen = !isFullscreen;
                      await SystemChrome.setEnabledSystemUIMode(
                        isFullscreen
                            ? SystemUiMode.immersiveSticky
                            : SystemUiMode.edgeToEdge,
                      );
                    },
                    icon: const Icon(Icons.fullscreen),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _scorePanel(
                      name: akaName,
                      score: akaScore,
                      color: akaColor,
                      isAka: true,
                    ),
                    _centerPanel(),
                    _scorePanel(
                      name: aoName,
                      score: aoScore,
                      color: aoColor,
                      isAka: false,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.circle,
                    size: 8,
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'READY',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _confirmFinish,
                    icon: const Icon(Icons.flag, size: 15),
                    label: const Text(
                      'END MATCH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: goldColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreSnapshot {
  const _ScoreSnapshot({
    required this.akaScore, required this.aoScore,
    required this.akaFouls, required this.aoFouls,
    required this.akaIppon, required this.aoIppon,
    required this.akaWazaAri, required this.aoWazaAri,
    required this.akaSenshu, required this.aoSenshu,
    required this.akaPenalties, required this.aoPenalties,
    required this.remainingSeconds,
    required this.isRunning,
    required this.matchFinished,
  });

  final int akaScore;
  final int aoScore;
  final int akaFouls, aoFouls;
  final int akaIppon, aoIppon, akaWazaAri, aoWazaAri;
  final bool akaSenshu, aoSenshu;
  final Set<String> akaPenalties, aoPenalties;
  final int remainingSeconds;
  final bool isRunning;
  final bool matchFinished;
}
