
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            children: [
              SizedBox(
                height: 82,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        'assets/z_score_icon.png',
                        width: 70, height: 70, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.sports_martial_arts, color: goldColor, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Z-SCORE', style: TextStyle(
                            color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic, letterSpacing: 1.5, height: 1.0,
                          )),
                          SizedBox(height: 7),
                          Text('K A R A T E   S C O R E B O A R D', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Color(0xFFB8C7D9), fontSize: 12, letterSpacing: 1.3)),
                        ],
                      ),
                    ),
                    _headerAction('Switch sides', Icons.swap_horiz_rounded, () {
                      setState(() => sidesSwitched = !sidesSwitched);
                      _logEvent('SIDE POSITIONS SWITCHED');
                    }),
                    _headerAction('Match history', Icons.history_rounded, _showHistory),
                    PopupMenuButton<String>(
                      tooltip: 'Settings',
                      color: panelColor,
                      icon: const Icon(Icons.settings, size: 28),
                      onSelected: (value) {
                        if (value == 'names') _editNames();
                        if (value == 'duration') _chooseDuration();
                        if (value == 'reset') _resetMatch();
                        if (value == 'finish') _confirmFinish();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'names', child: ListTile(
                          dense: true, leading: Icon(Icons.edit), title: Text('Athlete names'),
                        )),
                        PopupMenuItem(value: 'duration', child: ListTile(
                          dense: true, leading: Icon(Icons.timer_outlined), title: Text('Match duration'),
                        )),
                        PopupMenuItem(value: 'reset', child: ListTile(
                          dense: true, leading: Icon(Icons.refresh), title: Text('Reset match'),
                        )),
                        PopupMenuItem(value: 'finish', child: ListTile(
                          dense: true, leading: Icon(Icons.flag), title: Text('End match'),
                        )),
                      ],
                    ),
                    _headerAction('Toggle fullscreen', Icons.fullscreen_rounded, () async {
                      isFullscreen = !isFullscreen;
                      await SystemChrome.setEnabledSystemUIMode(
                        isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
                      );
                    }),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF233246), height: 1, thickness: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sidesSwitched) ...[
                      _scorePanel(name: aoName, score: aoScore, color: aoColor, isAka: false),
                      _centerPanel(),
                      _scorePanel(name: akaName, score: akaScore, color: akaColor, isAka: true),
                    ] else ...[
                      _scorePanel(name: akaName, score: akaScore, color: akaColor, isAka: true),
                      _centerPanel(),
                      _scorePanel(name: aoName, score: aoScore, color: aoColor, isAka: false),
                    ],
                  ],
                ),
              ),
              Container(
                height: 58,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF070D16),
                  border: Border.all(color: const Color(0xFF253346), width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('15s LEFT  →  FOOTBALL WHISTLE', style: TextStyle(
                          color: Color(0xFFD7E0EC), fontSize: 11, fontWeight: FontWeight.w800,
                        )),
                        SizedBox(height: 5),
                        LinearProgressIndicator(value: 0.95, minHeight: 3, backgroundColor: Color(0xFF293444), color: goldColor),
                      ],
                    )),
                    const SizedBox(width: 24),
                    Container(width: 1, height: 34, color: const Color(0xFF344256)),
                    const SizedBox(width: 24),
                    const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MATCH END  →  LONG WARNING BUZZER', style: TextStyle(
                          color: Color(0xFFD7E0EC), fontSize: 11, fontWeight: FontWeight.w800,
                        )),
                        SizedBox(height: 5),
                        LinearProgressIndicator(value: 1, minHeight: 3, backgroundColor: Color(0xFF293444), color: akaColor),
                      ],
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerAction(String tooltip, IconData icon, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      color: const Color(0xFFE8EEF7),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(minWidth: 54, minHeight: 54),
    );
  }


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
