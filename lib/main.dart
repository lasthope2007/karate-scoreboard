
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

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
  bool sidesSwitched = false;

  Timer? timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _blinkController;
  late final Animation<double> _winnerOpacity;

  final List<_ScoreSnapshot> history = [];
  final List<_MatchEvent> matchHistory = [];

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
    _audioPlayer.dispose();
    _blinkController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _logEvent(String description) {
    // Clamp elapsed time so adding time never creates a negative timestamp.
    final elapsed = (matchDuration - remainingSeconds).clamp(0, 599);
    final stamp = '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
    matchHistory.insert(0, _MatchEvent(time: stamp, description: description, akaScore: akaScore, aoScore: aoScore, remainingSeconds: remainingSeconds));
    if (matchHistory.length > 250) matchHistory.removeLast();
  }

  Future<void> _showHistory() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panelColor,
        title: Row(children: [const Expanded(child: Text('MATCH HISTORY')), Text('${matchHistory.length}', style: const TextStyle(color: goldColor))]),
        content: SizedBox(
          width: 520,
          height: 360,
          child: matchHistory.isEmpty
              ? const Center(child: Text('No events recorded yet.', style: TextStyle(color: Colors.white54)))
              : ListView.separated(
                  itemCount: matchHistory.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (_, index) {
                    final event = matchHistory[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 54, child: Text(event.time, style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold))),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(event.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Score ${event.akaScore} - ${event.aoScore}  •  Timer ${_formatTime(event.remainingSeconds)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ])),
                      ]),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE'))],
      ),
    );
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

    _saveHistory();
    setState(() => isRunning = true);
    _logEvent('TIMER STARTED');

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (remainingSeconds <= 1) {
        t.cancel();
        _saveHistory();
        _playEndSound();
        setState(() {
          remainingSeconds = 0;
          isRunning = false;
          matchFinished = true;
        });
        _logEvent('TIME EXPIRED — MATCH ENDED');
        _startWinnerBlink();
        return;
      }

      setState(() => remainingSeconds--);
      // One clear referee whistle exactly when the final 15 seconds begin.
      if (remainingSeconds == 15) _playCountdownSound();
    });
  }

  void _pauseTimer() {
    if (!isRunning) return;
    _saveHistory();
    timer?.cancel();
    setState(() => isRunning = false);
    _logEvent('TIMER PAUSED');
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
      matchHistory.clear();
      _blinkController.stop();
      _blinkController.reset();
    });
    _logEvent('MATCH RESET');
  }

  void _changeScore(bool isAka, int points) {
    if (matchFinished) return;

    _saveHistory();
    final oldScore = isAka ? akaScore : aoScore;

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

    final newScore = isAka ? akaScore : aoScore;
    _logEvent('${isAka ? akaName : aoName}: ${points > 0 ? '+' : ''}$points point(s) — $oldScore → $newScore');
    if ((akaScore - aoScore).abs() >= maxScore) {
      _saveHistory();
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
    _logEvent('${isAka ? akaName : aoName}: warning counter ${delta > 0 ? '+' : ''}$delta — now ${isAka ? akaFouls : aoFouls}');
  }

  void _toggleSenshu(bool isAka) {
    if (matchFinished) return;
    _saveHistory();
    final awarding = isAka ? !akaSenshu : !aoSenshu;
    setState(() {
      if (isAka) { akaSenshu = !akaSenshu; if (akaSenshu) aoSenshu = false; }
      else { aoSenshu = !aoSenshu; if (aoSenshu) akaSenshu = false; }
    });
    _logEvent('${isAka ? akaName : aoName}: SENSHU ${awarding ? 'awarded' : 'removed'}');
  }

  void _togglePenalty(bool isAka, String penalty) {
    if (matchFinished) return;
    _saveHistory();
    final existing = isAka ? akaPenalties : aoPenalties;
    final wasActive = existing.contains(penalty);
    setState(() {
      final p = isAka ? akaPenalties : aoPenalties;
      if (p.contains(penalty)) { p.remove(penalty); }
      else {
        p.add(penalty);
        if (penalty == 'HANSOKU') { isRunning = false; timer?.cancel(); matchFinished = true; }
      }
    });
    _logEvent('${isAka ? akaName : aoName}: $penalty ${wasActive ? 'removed' : 'recorded'}');
    if (penalty == 'HANSOKU' && !wasActive && (isAka ? akaPenalties.contains(penalty) : aoPenalties.contains(penalty))) {
      _logEvent('MATCH ENDED — HANSOKU against ${isAka ? akaName : aoName}');
      _playEndSound();
      _startWinnerBlink();
    }
  }

  void _adjustTime(int delta) {
    if (matchFinished) return;
    _saveHistory();
    final previousTime = remainingSeconds;
    setState(() {
      remainingSeconds = (remainingSeconds + delta).clamp(0, 599);
    });
    _logEvent('TIMER ${delta > 0 ? 'increased' : 'decreased'} by ${delta.abs()} sec — $previousTime → $remainingSeconds');
    if (remainingSeconds == 0) _finishMatch();
  }

  Future<void> _playCountdownSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('countdown.wav'));
    } catch (_) {
      // Audio is best-effort if a device disables media output.
    }
  }

  Future<void> _playEndSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('match_end.wav'));
    } catch (_) {
      // Audio is best-effort if a device disables media output.
    }
  }

  void _startWinnerBlink() {
    if (_winner == 'HANTEI REQUIRED') {
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
    _logEvent('UNDO — restored score ${akaScore}–${aoScore}, timer ${_formatTime(remainingSeconds)}');
    if (matchFinished) {
      _startWinnerBlink();
    } else {
      _blinkController.stop();
      _blinkController.reset();
    }
  }

  void _finishMatch() {
    if (matchFinished) return;
    timer?.cancel();

    setState(() {
      isRunning = false;
      matchFinished = true;
    });
    _logEvent('MATCH ENDED — winner: $_winner');
    _playEndSound();
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
        matchHistory.clear();
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

    if (confirm == true && mounted && !matchFinished) {
      _saveHistory();
      _finishMatch();
    }
  }

  Widget _scorePanel({
    required String name,
    required int score,
    required Color color,
    required bool isAka,
  }) {
    final isWinner = matchFinished &&
        ((_winner == akaName && isAka) || (_winner == aoName && !isAka));
    final penalties = isAka ? akaPenalties : aoPenalties;
    final senshu = isAka ? akaSenshu : aoSenshu;
    final ippon = isAka ? akaIppon : aoIppon;
    final wazaAri = isAka ? akaWazaAri : aoWazaAri;

    Widget senshuControl() => Tooltip(
      message: senshu ? 'Remove Senshu' : 'Award Senshu',
      child: Material(
        color: senshu ? color : color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _toggleSenshu(isAka),
          child: SizedBox(
            width: 66, height: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(senshu ? Icons.flag : Icons.outlined_flag,
                    color: senshu ? Colors.white : color, size: 25),
                const SizedBox(height: 2),
                Text('SENSHU', style: TextStyle(
                  color: senshu ? Colors.white : color,
                  fontSize: 10, fontWeight: FontWeight.w900,
                )),
              ],
            ),
          ),
        ),
      ),
    );

    Widget sectionLabel(String label) => Row(
      children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.55), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2,
          )),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.55), thickness: 1)),
      ],
    );

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(7),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.075), const Color(0xFF050912), color.withValues(alpha: 0.035)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: isWinner ? 3.5 : 2.5),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 22, spreadRadius: 1),
            if (isWinner) BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 28),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                if (isAka) senshuControl(),
                Expanded(child: Text(
                  name.toUpperCase(), textAlign: TextAlign.center,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2.2),
                )),
                if (!isAka) senshuControl(),
              ],
            ),
            if (isWinner) FadeTransition(
              opacity: _winnerOpacity,
              child: Text('WINNER', style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 3)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$score', style: TextStyle(
                color: isWinner ? color : Colors.white, fontSize: 92, height: 0.88,
                fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()],
              )),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('IPPON  $ippon', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('•', style: TextStyle(color: Colors.white54))),
                Text('WAZA-ARI  $wazaAri', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
            sectionLabel('POINTS'),
            Row(
              children: [
                for (final points in [1, 2, 3, -1]) ...[
                  if (points != 1) const SizedBox(width: 8),
                  Expanded(child: _scoreButton(
                    label: points == -1 ? '−1' : '+$points',
                    color: points == -1 ? const Color(0xFF8B9BAD) : color,
                    onPressed: () => _changeScore(isAka, points),
                  )),
                ],
              ],
            ),
            sectionLabel('FOULS'),
            Row(
              children: [
                for (final penalty in ['CHUI 1', 'CHUI 2', 'CHUI 3', 'HANSOKU-CHUI']) ...[
                  if (penalty != 'CHUI 1') const SizedBox(width: 6),
                  Expanded(
                    flex: penalty == 'HANSOKU-CHUI' ? 2 : 1,
                    child: _smallToggle(penalty, penalties.contains(penalty), color, () => _togglePenalty(isAka, penalty)),
                  ),
                ],
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: _smallToggle('HANSOKU', penalties.contains('HANSOKU'), color,
                () => _togglePenalty(isAka, 'HANSOKU'), large: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallToggle(String label, bool active, Color color, VoidCallback onTap, {bool large = false}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? Colors.black : color,
        backgroundColor: active ? color : color.withValues(alpha: 0.025),
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: large ? 10 : 7),
        minimumSize: Size(0, large ? 42 : 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: active ? color : color.withValues(alpha: 0.85), width: active ? 2 : 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: TextStyle(fontSize: large ? 14 : 10.5, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _scoreButton({required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.10), foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          minimumSize: const Size(0, 50), tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: color.withValues(alpha: 0.95), width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        onPressed: onPressed,
        child: FittedBox(fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22))),
      ),
    );
  }

  Widget _centerPanel() {
    Widget roundButton({required String label, required IconData icon, required VoidCallback? onPressed, bool primary = false, Color? color}) {
      final tint = color ?? (primary ? goldColor : const Color(0xFF7E91A9));
      return SizedBox(
        height: primary ? 58 : 48,
        child: primary
          ? FilledButton.icon(
              onPressed: onPressed, icon: Icon(icon, size: 22),
              label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
              style: FilledButton.styleFrom(backgroundColor: tint, foregroundColor: const Color(0xFF050912), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            )
          : OutlinedButton.icon(
              onPressed: onPressed, icon: Icon(icon, size: 18),
              label: FittedBox(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              style: OutlinedButton.styleFrom(foregroundColor: tint, side: BorderSide(color: tint.withValues(alpha: 0.65), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
            ),
      );
    }

    return SizedBox(
      width: 292,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Text('MATCH TIMER', style: TextStyle(color: goldColor, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
              decoration: BoxDecoration(color: const Color(0xFF03060B), borderRadius: BorderRadius.circular(20), border: Border.all(color: goldColor.withValues(alpha: 0.65), width: 1.5), boxShadow: [BoxShadow(color: goldColor.withValues(alpha: 0.06), blurRadius: 20)]),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                _formatTime(remainingSeconds),
                style: TextStyle(color: remainingSeconds <= 15 ? akaColor : Colors.white, fontSize: 64, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()]),
              )),
            ),
            if (matchFinished)
              FadeTransition(opacity: _winnerOpacity, child: Text('WINNER: $_winner', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: goldColor, fontWeight: FontWeight.w900)))
            else
              const Text('KUMITE  •  MATCH', style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.0)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Subtract one second', onPressed: () => _adjustTime(-1), icon: const Icon(Icons.remove_circle_outline, size: 29), color: const Color(0xFF8798AE), visualDensity: VisualDensity.compact),
              const Text('1 SEC', style: TextStyle(fontSize: 12, color: Colors.white60, letterSpacing: 1)),
              IconButton(tooltip: 'Add one second', onPressed: () => _adjustTime(1), icon: const Icon(Icons.add_circle_outline, size: 29), color: goldColor, visualDensity: VisualDensity.compact),
            ]),
            SizedBox(width: double.infinity, child: roundButton(
              label: matchFinished ? 'MATCH ENDED' : (isRunning ? 'PAUSE' : 'START'),
              icon: matchFinished ? Icons.flag : (isRunning ? Icons.pause : Icons.play_arrow),
              primary: true, onPressed: matchFinished ? null : (isRunning ? _pauseTimer : _startTimer),
            )),
            Row(children: [
              Expanded(child: roundButton(label: 'PAUSE', icon: Icons.pause, onPressed: isRunning ? _pauseTimer : null)),
              const SizedBox(width: 10),
              Expanded(child: roundButton(label: 'RESET', icon: Icons.refresh, onPressed: _resetMatch)),
            ]),
            SizedBox(width: double.infinity, child: roundButton(label: 'UNDO LAST ACTION', icon: Icons.undo_rounded, onPressed: history.isEmpty ? null : _undo)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(children: [
            SizedBox(height: 82, child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.asset('assets/z_score_icon.png', width: 70, height: 70, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 70, height: 70,
                    decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.sports_martial_arts, color: goldColor, size: 40))),
              ),
              const SizedBox(width: 18),
              const Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Z-SCORE', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1.5, height: 1.0)),
                  SizedBox(height: 7),
                  Text('K A R A T E   S C O R E B O A R D', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFB8C7D9), fontSize: 12, letterSpacing: 1.3)),
                ],
              )),
              _headerAction('Switch sides', Icons.swap_horiz_rounded, () { setState(() => sidesSwitched = !sidesSwitched); _logEvent('SIDE POSITIONS SWITCHED'); }),
              _headerAction('Match history', Icons.history_rounded, _showHistory),
              PopupMenuButton<String>(
                tooltip: 'Settings', color: panelColor, icon: const Icon(Icons.settings, size: 28),
                onSelected: (value) {
                  if (value == 'names') _editNames();
                  if (value == 'duration') _chooseDuration();
                  if (value == 'reset') _resetMatch();
                  if (value == 'finish') _confirmFinish();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'names', child: ListTile(dense: true, leading: Icon(Icons.edit), title: Text('Athlete names'))),
                  PopupMenuItem(value: 'duration', child: ListTile(dense: true, leading: Icon(Icons.timer_outlined), title: Text('Match duration'))),
                  PopupMenuItem(value: 'reset', child: ListTile(dense: true, leading: Icon(Icons.refresh), title: Text('Reset match'))),
                  PopupMenuItem(value: 'finish', child: ListTile(dense: true, leading: Icon(Icons.flag), title: Text('End match'))),
                ],
              ),
              _headerAction('Toggle fullscreen', Icons.fullscreen_rounded, () async {
                isFullscreen = !isFullscreen;
                await SystemChrome.setEnabledSystemUIMode(isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
              }),
            ])),
            const Divider(color: Color(0xFF233246), height: 1, thickness: 1),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (sidesSwitched) ...[
                _scorePanel(name: aoName, score: aoScore, color: aoColor, isAka: false),
                _centerPanel(),
                _scorePanel(name: akaName, score: akaScore, color: akaColor, isAka: true),
              ] else ...[
                _scorePanel(name: akaName, score: akaScore, color: akaColor, isAka: true),
                _centerPanel(),
                _scorePanel(name: aoName, score: aoScore, color: aoColor, isAka: false),
              ],
            ])),
            Container(
              height: 58, margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(color: const Color(0xFF070D16), border: Border.all(color: const Color(0xFF253346), width: 1.5), borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('15s LEFT  →  FOOTBALL WHISTLE', style: TextStyle(color: Color(0xFFD7E0EC), fontSize: 11, fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  LinearProgressIndicator(value: 0.95, minHeight: 3, backgroundColor: Color(0xFF293444), color: goldColor),
                ])),
                const SizedBox(width: 24),
                Container(width: 1, height: 34, color: const Color(0xFF344256)),
                const SizedBox(width: 24),
                const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MATCH END  →  LONG WARNING BUZZER', style: TextStyle(color: Color(0xFFD7E0EC), fontSize: 11, fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  LinearProgressIndicator(value: 1, minHeight: 3, backgroundColor: Color(0xFF293444), color: akaColor),
                ])),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _headerAction(String tooltip, IconData icon, VoidCallback onPressed) => IconButton(
    tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, size: 28),
    color: const Color(0xFFE8EEF7), padding: const EdgeInsets.symmetric(horizontal: 12),
    constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
  );
}

class _MatchEvent {
  const _MatchEvent({required this.time, required this.description, required this.akaScore, required this.aoScore, required this.remainingSeconds});
  final String time;
  final String description;
  final int akaScore;
  final int aoScore;
  final int remainingSeconds;
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
