/// Tap events that can be reported by the R08 ring.
enum R08TapEvent {
  single("Single tap"),
  double("Double tap"),
  triple("Triple tap"),
  quad("Quadruple tap");

  final String label;

  const R08TapEvent(this.label);
}
