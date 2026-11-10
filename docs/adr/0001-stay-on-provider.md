# Stay on Provider

State management stays on Provider with ChangeNotifier. There is no migration to Riverpod or Bloc.

An architecture review on 2026-11-10 found seven refactoring candidates with five underlying causes: rules copied instead of owned, logic in widget State classes, state with the wrong lifetime, no seam at the audio engine or the device list, and `main()` as the only keeper of load order. None is caused by Provider and none would be fixed by replacing it. A migration would touch every widget and most tests and put the tuned audio paths at risk. Provider is in maintenance mode but stable.

## Consequences

Fix the structure first by moving logic into plain Dart modules that do not know about Provider. Session state becomes session-scoped instead of app-scoped as part of that work. Revisit this decision only after those refactors land, when the providers are thin and a switch would be mechanical.
