/// Simple UI state model. The admin app has no state-management package;
/// screens are plain `StatefulWidget`s driven by `setState`, mirroring the
/// mobile app's approach.
enum ViewState { initial, loading, success, empty, error }
