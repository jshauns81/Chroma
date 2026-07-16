/// bat theme adapter — generates a `.tmTheme` from Chroma's semantic roles.
///
/// bat (via syntect) themes with Sublime/TextMate `.tmTheme` plists. Three of
/// our families ship as bat built-ins, but four don't — so rather than depend on
/// bat's roster at all, Chroma generates ONE `.tmTheme` from the palette for
/// *every* theme, named `Chroma`. The companion `BatAdapter` exports a constant
/// `BAT_THEME="Chroma"`, so bat always renders the current palette regardless of
/// what upstream ships. Re-theming regenerates this file and rebuilds bat's
/// cache (`bat cache --build`, the tool's reload hook).
///
/// Like `SketchyBarAdapter`, this is a generate-whole-file adapter: it owns the
/// file and ignores `current`. Scope→role mapping is intentionally small but
/// covers the common highlight groups; every color resolves through the palette
/// fallback chain, so shallow palettes still produce a complete theme.
public struct BatThemeAdapter: ThemeAdapter {
    public let toolName = "bat"

    public init() {}

    public func render(theme: Theme, current: String?) throws -> String {
        try TemplateRenderer.render(Self.template, palette: theme.palette)
    }

    /// A `.tmTheme` plist. Each `{{role}}` becomes `#rrggbb`. The global block
    /// sets bg/fg/caret/selection; the scope blocks color the common syntax
    /// groups from accent roles.
    private static let template = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>name</key>
      <string>Chroma</string>
      <key>settings</key>
      <array>
        <dict>
          <key>settings</key>
          <dict>
            <key>background</key><string>{{base}}</string>
            <key>foreground</key><string>{{text}}</string>
            <key>caret</key><string>{{text}}</string>
            <key>lineHighlight</key><string>{{surface0}}</string>
            <key>selection</key><string>{{surface1}}</string>
            <key>invisibles</key><string>{{overlay}}</string>
          </dict>
        </dict>
        <dict>
          <key>name</key><string>Comment</string>
          <key>scope</key><string>comment, punctuation.definition.comment</string>
          <key>settings</key><dict><key>foreground</key><string>{{overlay}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>String</string>
          <key>scope</key><string>string, constant.other.symbol</string>
          <key>settings</key><dict><key>foreground</key><string>{{green}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Number, Constant</string>
          <key>scope</key><string>constant.numeric, constant.language, constant.character</string>
          <key>settings</key><dict><key>foreground</key><string>{{orange}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Keyword, Storage</string>
          <key>scope</key><string>keyword, storage, storage.type, keyword.control</string>
          <key>settings</key><dict><key>foreground</key><string>{{purple}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Operator</string>
          <key>scope</key><string>keyword.operator</string>
          <key>settings</key><dict><key>foreground</key><string>{{cyan}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Function</string>
          <key>scope</key><string>entity.name.function, support.function, meta.function-call</string>
          <key>settings</key><dict><key>foreground</key><string>{{blue}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Type, Class</string>
          <key>scope</key><string>entity.name.type, entity.name.class, support.type, support.class</string>
          <key>settings</key><dict><key>foreground</key><string>{{yellow}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Variable, Tag</string>
          <key>scope</key><string>variable, entity.name.tag</string>
          <key>settings</key><dict><key>foreground</key><string>{{red}}</string></dict>
        </dict>
        <dict>
          <key>name</key><string>Punctuation</string>
          <key>scope</key><string>punctuation, meta.brace</string>
          <key>settings</key><dict><key>foreground</key><string>{{textMuted}}</string></dict>
        </dict>
      </array>
    </dict>
    </plist>
    """
}
