# Local compatibility and integration changes

Upstream component behavior, shapes, state layers, ripples and motion remain in QmlMaterial.

- Application font updates: observe `QEvent::ApplicationFontChange` with a lifetime-bound observer in Control, Label, TextField and Popup, compatible with the launcher Qt deprecation policy.
- Popup and drawer ancestor geometry subscriptions: spell out typed signal connections for MinGW, avoiding runtime signal lookup failures with member-pointer loops.
- SearchBar: render an empty-field placeholder and optional shortcut text using library labels.
- ComboBox: implement its declared filled field variant with the library FilledTextFieldShape and caption; preserve the outlined variant. App popup backgrounds retain nonzero implicit dimensions so anchored placement can resolve before delegates are laid out.
- NavigationRail: expose item spacing, minimum item height and vertical padding to reproduce the approved desktop rail while retaining the library morph and selection behavior.
- SplitButton: honor the explicit available height and expose the trailing control for sizing.
- TabBar: allow an optional primary indicator width fraction while retaining the library transition.

The app supplies Roboto Flex / Noto Sans SC as an explicit font chain with Qt typographic line metrics. Windows 11 style and Segoe UI are applied separately to QWidget secondary windows.
