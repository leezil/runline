/// Exactly one goal per run; null at the call site represents an open run.
sealed class RunningGoal {
  const RunningGoal();

  const factory RunningGoal.distance(double distanceKm) = DistanceGoal;
  const factory RunningGoal.duration(Duration duration) = DurationGoal;
}

final class DistanceGoal extends RunningGoal {
  const DistanceGoal(this.distanceKm);

  final double distanceKm;
}

final class DurationGoal extends RunningGoal {
  const DurationGoal(this.duration);

  final Duration duration;
}
