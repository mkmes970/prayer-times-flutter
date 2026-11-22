{{flutter_js}}
{{flutter_build_config}}

// The app uses its own release-aware worker from offline-setup.js.
_flutter.loader.load({
  config: {
    // CanvasKit otherwise downloads its default Roboto and missing-glyph
    // fallbacks from fonts.gstatic.com, even with --no-web-resources-cdn.
    fontFallbackBaseUrl: new URL('fallback-fonts/', document.baseURI).href,
  },
});
