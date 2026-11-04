import 'package:flutter_test/flutter_test.dart';
import 'package:runline/features/running/running_timer.dart';

void main() {
  test('delayed ticks do not lose time and repeated controls are safe', () {
    var now = Duration.zero;
    final timer = RunningTimer(now: () => now);
    addTearDown(timer.dispose);
    now += const Duration(seconds: 75, milliseconds: 750);
    expect(timer.formattedElapsed, '01:15');
    timer.pause();
    timer.pause();
    now += const Duration(hours: 1);
    expect(timer.elapsed, const Duration(seconds: 75, milliseconds: 750));
    timer.resume();
    timer.resume();
    now += const Duration(milliseconds: 250);
    expect(timer.formattedElapsed, '01:16');
    timer.finish();
    timer.finish();
    timer.resume();
    timer.pause();
    now += const Duration(minutes: 1);
    expect(timer.status, RunningStatus.finished);
    expect(timer.elapsed, const Duration(seconds: 76));
  });

  test('finishing while paused keeps the accumulated running time', () {
    var now = Duration.zero;
    final timer = RunningTimer(now: () => now);
    addTearDown(timer.dispose);
    now += const Duration(seconds: 4);
    timer.pause();
    now += const Duration(minutes: 5);
    timer.finish();
    expect(timer.elapsed, const Duration(seconds: 4));
    expect(timer.status, RunningStatus.finished);
  });

  testWidgets('dispose cancels notifications and the periodic timer', (
    tester,
  ) async {
    var now = Duration.zero;
    final timer = RunningTimer(now: () => now);
    var notifications = 0;
    timer.addListener(() => notifications++);
    now += const Duration(seconds: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(notifications, 1);
    timer.dispose();
    now += const Duration(seconds: 10);
    await tester.pump(const Duration(seconds: 10));
    expect(notifications, 1);
  });
}
