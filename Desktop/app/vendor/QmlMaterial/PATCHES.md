# Local compatibility and integration changes

Upstream component behavior, shapes, state layers, ripples and motion remain in QmlMaterial.

- Application font updates: observe `QEvent::ApplicationFontChange` with a lifetime-bound observer in Control, Label, TextField and Popup, compatible with the launcher Qt deprecation policy.
- Popup and drawer ancestor geometry subscriptions: spell out typed signal connections for MinGW, avoiding runtime signal lookup failures with member-pointer loops.
- SearchBar: render an empty-field placeholder and optional shortcut text using library labels.
- ComboBox: implement its declared filled field variant with the library FilledTextFieldShape and caption; preserve the outlined variant. App popup backgrounds retain nonzero implicit dimensions so anchored placement can resolve before delegates are laid out.
- NavigationRail: expose item spacing, minimum item height and vertical padding to reproduce the approved desktop rail while retaining the library morph and selection behavior.
- RailItem: position the indicator at the content top padding so the selection pill and ripple share the icon center in both rail states.
- SplitButton: honor the explicit available height and expose the trailing control for sizing.
- TabBar: allow an optional primary indicator width fraction while retaining the library transition.
- TabBar indicator coordinates include the content host offset; the launcher requests fixed equal-width tabs.
- MenuItem fills its menu's available width and uses an 8px state layer radius, fixing partial hover fills.
- Filled ComboBox keeps its container visible when its popup closes; menu placement/height is constrained by the app window.
- FilledTextFieldShape uses Qt's geometry renderer; the curve renderer could leave the fill/underline blank after switching hidden pages in the embedded Qt 6.12 view.
- SnakeBar uses the Material medium shape token. App dialogs use the full-window overlay and library motion.
- ProgressIndicator uses Qt's unified animation clock (as the library's spring/ripple animations do), so determinate interpolation and waves advance in embedded QQuickView without relying on scene-graph polish scheduling. Visibility and reduced-motion gates stop the clock.

The app supplies Roboto Flex / Noto Sans SC as an explicit font chain with Qt typographic line metrics. Windows 11 style and Segoe UI are applied separately to QWidget secondary windows.
