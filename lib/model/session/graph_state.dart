/// Lightweight graph state for frequency graph readiness.
/// Kept separate from UI widgets to avoid circular deps.
enum GraphState {
  loading,
  ready,
  error,
}

