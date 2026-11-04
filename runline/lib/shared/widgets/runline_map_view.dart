// Keep browser APIs out of Android builds and native map creation out of web.
export 'runline_map_view_native.dart'
    if (dart.library.js_interop) 'runline_map_view_web.dart';
