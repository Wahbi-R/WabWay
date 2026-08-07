{{flutter_js}}
{{flutter_build_config}}

// Paint app background colour behind the CanvasKit canvas immediately so any
// gap between Flutter frames shows cream rather than the browser's grey default.
(function () {
  var style = document.createElement('style');
  style.textContent =
    'flutter-view, flt-glass-pane { background: #F8F3EA; }' +
    'canvas { background: transparent !important; }';
  document.head.appendChild(style);
})();

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({});
      await appRunner.runApp();
    } catch (e) {
      // If CanvasKit fails to init (e.g. WebGL not available), show a
      // human-readable message instead of a silent grey screen.
      console.error('Flutter engine failed to start:', e);
      var el = document.getElementById('flutter-loading');
      if (el) {
        el.style.opacity = '1';
        el.innerHTML =
          '<div style="text-align:center;padding:40px;color:#555;font-family:system-ui">' +
          '<p style="font-size:18px;font-weight:600">wabway</p>' +
          '<p style="margin-top:12px;font-size:14px">Could not start on this browser.<br>' +
          'Try refreshing, or open in Chrome.</p>' +
          '<button onclick="location.reload()" style="margin-top:20px;padding:10px 24px;' +
          'border:none;border-radius:8px;background:#2D2D2D;color:#fff;font-size:14px;cursor:pointer">' +
          'Refresh</button></div>';
      }
    }
  },
});
