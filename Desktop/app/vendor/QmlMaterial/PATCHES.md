# Local compatibility and integration changes

Components, shapes and motion physics come from QmlMaterial. Desktop-specific rendering and interaction adaptations are listed below.

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
- SpringMotion and ProgressIndicator sample elapsed wall time with precise Qt timers. Their movement no longer depends on an exposed embedded QQuickView or scene-graph polish; physical coefficients and interpolation remain unchanged. Timers stop on settlement, inactive visibility and reduced motion.
- TabBar keeps its optional indicator fraction and uses Expressive spatial springs for indicator position and width, including current-index updates.
- SideSheet uses the Expressive default spatial spring for interruptible entry from beyond the window bounds and reverse closing; reduced motion completes immediately.
- RippleSkia keeps bounded hover/press state layers and disables the expanding sparkle shader for desktop controls. App buttons supply press/shape feedback.
- Outlined text fields and radio indicators use the geometry renderer, consistent with the existing filled-field rendering workaround.
- ComboBox exposes an optional display font size so its internal typescale binding respects the app's 14px compact desktop selector text.
- CarouselImageDelegate retains its rounded image mask and caches screenshots; masking was previously disabled by a delegate override.
- ComboBox separates keyboard reveal from pointer highlight, so hovering while scrolling does not reposition the list. Dropdown delegates bind to the popup width after its initial measurement; all state layers fill the same width, with clipped middle-elided paths and full-path tooltips.
- MenuItem state layers explicitly follow the control geometry. Desktop hover layers clear when the pointer leaves instead of retaining the previous control's animated fill; selected and pressed shape feedback remain.

The app supplies Roboto Flex / Noto Sans SC as an explicit font chain with Qt typographic line metrics. Windows 11 style and Segoe UI are applied separately to QWidget secondary windows.
