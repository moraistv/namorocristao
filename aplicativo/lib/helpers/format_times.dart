String formatMinsToTime(int mins) {
  if (mins <= 1) {
    return "$mins min";
  } else if (mins <= 60) {
    return "$mins mins";
  } else {
    return "${mins ~/ 60}h ${mins % 60}m";
  }
}

String formatSecsToTime(int secs) {
  if (secs <= 1) {
    return "$secs sec";
  } else if (secs <= 60) {
    return "$secs secs";
  } else {
    return "${secs ~/ 60}m ${secs % 60}s";
  }
}

String formatDuration(Duration duration) {
  String twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}

String formatDurationToHourAndMin(Duration duration,
    {bool showSeconds = true}) {
  String mins = duration.inMinutes.remainder(60).toString();

  return "${duration.inHours}h ${mins}m";
}
