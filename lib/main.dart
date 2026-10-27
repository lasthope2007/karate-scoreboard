
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
      home: const ZScoreSplashScreen(),
    );
  }
}

class ZScoreSplashScreen extends StatefulWidget {
  const ZScoreSplashScreen({super.key});

  @override
  State<ZScoreSplashScreen> createState() => _ZScoreSplashScreenState();
}

class _ZScoreSplashScreenState extends State<ZScoreSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _openScoreboard();
  }

  Future<void> _openScoreboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const ScoreboardPage(),
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03050A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 0.9,
                colors: [Color(0xFF101B31), Color(0xFF03050A)],
              ),
            ),
          ),
          Positioned(
            left: -70,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF078CFF).withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF078CFF).withValues(alpha: 0.8),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -70,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744).withValues(alpha: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.8),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Image.asset(
                        'assets/z_score_icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(42),
                            border: Border.all(
                              color: const Color(0xFF2589FF),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Z',
                            style: TextStyle(
                              fontSize: 150,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Z-SCORE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 118,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Color(0xFF202838),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF2589FF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
      duration: const Duration(milliseconds: 650),
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
    final elapsed = matchDuration - remainingSeconds;
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

    setState(() => isRunning = true);

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (remainingSeconds <= 1) {
        t.cancel();
        _playEndSound();
        setState(() {
          remainingSeconds = 0;
          isRunning = false;
          matchFinished = true;
        });
        _startWinnerBlink();
        return;
      }

      setState(() => remainingSeconds--);
      if (remainingSeconds == 15) _playCountdownSound();
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
      matchHistory.clear();
      _blinkController.stop();
      _blinkController.reset();
    });
  }

  void _changeScore(bool isAka, int points) {
    if (matchFinished) return;

    _saveHistory();
    _logEvent('${isAka ? akaName : aoName}: ${points > 0 ? '+' : ''}$points point(s)');

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
    _logEvent('${isAka ? akaName : aoName}: warning counter ${delta > 0 ? '+' : ''}$delta');
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
    final awarding = isAka ? !akaSenshu : !aoSenshu;
    _logEvent('${isAka ? akaName : aoName}: SENSHU ${awarding ? 'awarded' : 'removed'}');
    setState(() {
      if (isAka) { akaSenshu = !akaSenshu; if (akaSenshu) aoSenshu = false; }
      else { aoSenshu = !aoSenshu; if (aoSenshu) akaSenshu = false; }
    });
  }

  void _togglePenalty(bool isAka, String penalty) {
    if (matchFinished) return;
    _saveHistory();
    final existing = isAka ? akaPenalties : aoPenalties;
    _logEvent('${isAka ? akaName : aoName}: $penalty ${existing.contains(penalty) ? 'removed' : 'recorded'}');
    setState(() {
      final p = isAka ? akaPenalties : aoPenalties;
      if (p.contains(penalty)) { p.remove(penalty); }
      else {
        p.add(penalty);
        if (penalty == 'HANSOKU') { isRunning = false; timer?.cancel(); matchFinished = true; }
      }
    });
    if (penalty == 'HANSOKU' && (isAka ? akaPenalties.contains(penalty) : aoPenalties.contains(penalty))) {
      _playEndSound(); _startWinnerBlink();
    }
  }

  void _adjustTime(int delta) {
    if (matchFinished) return;
    _saveHistory();
    _logEvent('Timer ${delta > 0 ? 'increased' : 'decreased'} by ${delta.abs()} second');
    setState(() {
      remainingSeconds = (remainingSeconds + delta).clamp(0, 599);
    });
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

    if (confirm == true && mounted) {
      _finishMatch();
    }
  }

  Widget _scorePanel({
    required String name, required int score, required Color color, required bool isAka,
  }) {
    final isWinner = matchFinished && ((_winner == akaName && isAka) || (_winner == aoName && !isAka));
    final penalties = isAka ? akaPenalties : aoPenalties;
    final senshu = isAka ? akaSenshu : aoSenshu;
    final ippon = isAka ? akaIppon : aoIppon;
    final wazaAri = isAka ? akaWazaAri : aoWazaAri;
    final senshuButton = Tooltip(
      message: senshu ? 'Remove Senshu' : 'Award Senshu',
      child: Material(
        color: senshu ? color : color.withValues(alpha: 0.12),
        shape: const CircleBorder(), clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(), onTap: () => _toggleSenshu(isAka),
          child: SizedBox(width: 40, height: 32, child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(senshu ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                color: senshu ? Colors.black : color, size: 16),
              const SizedBox(height: 0),
              Text('SENSHU', style: TextStyle(
                color: senshu ? Colors.black : color, fontSize: 6,
                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ],
          )),
        ),
      ),
    );
    Widget sectionLabel(String label) => Row(children: [
      Expanded(child: Divider(color: color.withValues(alpha: 0.45))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w900, letterSpacing: 1.2))),
      Expanded(child: Divider(color: color.withValues(alpha: 0.45))),
    ]);
    return Expanded(child: Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWinner ? color.withValues(alpha: 0.20) : panelColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: isWinner ? 3.5 : 2),
        boxShadow: isWinner ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 24, spreadRadius: 2)] : const [],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          senshuButton,
          const SizedBox(width: 6),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
            if (isWinner) FadeTransition(opacity: _winnerOpacity,
              child: Text('WINNER', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2))),
          ])),
          const SizedBox(width: 46),
        ]),
        FittedBox(fit: BoxFit.scaleDown, child: FadeTransition(
          opacity: isWinner ? _winnerOpacity : const AlwaysStoppedAnimation<double>(1),
          child: Text('$score', style: TextStyle(color: isWinner ? color : Colors.white,
            fontSize: 60, height: 0.9, fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()])))),
        Row(children: [
          Expanded(child: Text('IPPON  $ippon', textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800))),
          const Text('•', style: TextStyle(color: Colors.white38)),
          Expanded(child: Text('WAZA-ARI  $wazaAri', textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800))),
        ]),
        sectionLabel('POINTS'),
        Row(children: [
          Expanded(child: _scoreButton(label: '+1', color: color, onPressed: () => _changeScore(isAka, 1))),
          const SizedBox(width: 7),
          Expanded(child: _scoreButton(label: '+2', color: color, onPressed: () => _changeScore(isAka, 2))),
          const SizedBox(width: 7),
          Expanded(child: _scoreButton(label: '+3', color: color, onPressed: () => _changeScore(isAka, 3))),
          const SizedBox(width: 7),
          Expanded(child: _scoreButton(label: '−1', color: const Color(0xFF8B98AA), onPressed: () => _changeScore(isAka, -1))),
        ]),
        sectionLabel('FOULS'),
        Row(children: [
          for (final penalty in ['CHUI 1', 'CHUI 2', 'CHUI 3']) ...[
            if (penalty != 'CHUI 1') const SizedBox(width: 6),
            Expanded(child: _smallToggle(penalty, penalties.contains(penalty), color, () => _togglePenalty(isAka, penalty))),
          ],
        ]),
        Row(children: [
          Expanded(child: _smallToggle('HANSOKU-CHUI', penalties.contains('HANSOKU-CHUI'), color, () => _togglePenalty(isAka, 'HANSOKU-CHUI'))),
          const SizedBox(width: 7),
          Expanded(child: _smallToggle('HANSOKU', penalties.contains('HANSOKU'), color, () => _togglePenalty(isAka, 'HANSOKU'))),
        ]),
      ]),
    ));
  }

  Widget _smallToggle(String label, bool active, Color color, VoidCallback onTap) {
    return SizedBox(height: 28, child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? Colors.black : color,
        backgroundColor: active ? color : color.withValues(alpha: 0.035),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: active ? color : color.withValues(alpha: 0.75), width: active ? 2 : 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: FittedBox(fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
    ));
  }

  Widget _scoreButton({required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(width: double.infinity, height: 38, child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12), foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: color.withValues(alpha: 0.75), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onPressed,
      child: FittedBox(fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21))),
    ));
  }

  Widget _centerPanel() {
    return SizedBox(width: 200, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        const Text('Z-SCORE', textAlign: TextAlign.center,
          style: TextStyle(color: goldColor, fontSize: 17, letterSpacing: 2.4, fontWeight: FontWeight.w900)),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: goldColor.withValues(alpha: 0.22))),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(_formatTime(remainingSeconds),
            style: TextStyle(color: remainingSeconds <= 15 ? akaColor : Colors.white,
              fontSize: 42, fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()])))),
        if (matchFinished)
          FadeTransition(opacity: _winnerOpacity, child: Text('WINNER: $_winner', textAlign: TextAlign.center,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: goldColor, fontWeight: FontWeight.w900, fontSize: 12)))
        else
          const Text('KUMITE  •  MATCH', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.7)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'Subtract one second', onPressed: matchFinished ? null : () => _adjustTime(-1),
            icon: const Icon(Icons.remove_circle_outline, size: 28), color: Colors.white70, visualDensity: VisualDensity.compact),
          const Text('1 SEC', style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1)),
          IconButton(tooltip: 'Add one second', onPressed: matchFinished ? null : () => _adjustTime(1),
            icon: const Icon(Icons.add_circle_outline, size: 28), color: goldColor, visualDensity: VisualDensity.compact),
        ]),
        SizedBox(width: double.infinity, height: 46, child: FilledButton.icon(
          onPressed: matchFinished ? null : (isRunning ? _pauseTimer : _startTimer),
          icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 23),
          label: Text(matchFinished ? 'MATCH ENDED' : (isRunning ? 'PAUSE' : 'START'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          style: FilledButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
        )),
        SizedBox(width: double.infinity, height: 40, child: OutlinedButton.icon(
          onPressed: history.isEmpty ? null : _undo, icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text('UNDO', style: TextStyle(fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(foregroundColor: goldColor, side: BorderSide(color: goldColor.withValues(alpha: 0.65)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        )),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(children: [
        SizedBox(height: 66, child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/z_score_icon.png', width: 52, height: 52, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 52, height: 52,
                decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sports_martial_arts, color: goldColor, size: 32)))),
          const SizedBox(width: 12),
          const Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Z-SCORE SCOREBOARD', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 17)),
            SizedBox(height: 3),
            Text('KUMITE  •  MATCH CONTROL', maxLines: 1,
              style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.2)),
          ])),
          _headerAction('Athlete names', Icons.edit_rounded, _editNames),
          _headerAction('Match history', Icons.history_rounded, _showHistory),
          _headerAction('Match duration', Icons.timer_outlined, _chooseDuration),
          _headerAction('Switch sides', Icons.swap_horiz_rounded, () {
            setState(() => sidesSwitched = !sidesSwitched);
            _logEvent('SIDE POSITIONS SWITCHED');
          }),
          _headerAction('Reset match', Icons.restart_alt_rounded, _resetMatch),
          _headerAction('Toggle fullscreen', Icons.fullscreen_rounded, () async {
            isFullscreen = !isFullscreen;
            await SystemChrome.setEnabledSystemUIMode(isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
          }),
        ])),
        const Divider(color: Color(0xFF263140), height: 1),
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
        SizedBox(height: 38, child: Row(children: [
          const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
          const SizedBox(width: 7),
          Text(matchFinished ? 'MATCH FINISHED' : (isRunning ? 'MATCH IN PROGRESS' : 'READY'),
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const Spacer(),
          TextButton.icon(onPressed: _confirmFinish, icon: const Icon(Icons.flag_rounded, size: 16),
            label: const Text('END MATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            style: TextButton.styleFrom(foregroundColor: goldColor)),
        ])),
      ]),
    )));
  }

  Widget _headerAction(String tooltip, IconData icon, VoidCallback onPressed) => IconButton(
    tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, size: 24),
    color: const Color(0xFFE8EEF7), padding: const EdgeInsets.symmetric(horizontal: 7),
    constraints: const BoxConstraints(minWidth: 42, minHeight: 48), visualDensity: VisualDensity.compact,
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
