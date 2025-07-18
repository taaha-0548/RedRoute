// Flutter Web Bootstrap Script
(function() {
  'use strict';

  var serviceWorkerVersion = null;
  var scriptLoaded = false;

  function loadMainDartJs() {
    if (scriptLoaded) {
      return;
    }
    scriptLoaded = true;
    var scriptTag = document.createElement('script');
    scriptTag.src = 'main.dart.js';
    scriptTag.type = 'application/javascript';
    document.body.append(scriptTag);
  }

  // Downloads main.dart.js
  if ('serviceWorker' in navigator) {
    // Service workers are supported. Use them.
    window.addEventListener('load', function () {
      // Wait for registration to finish before dropping the <script> tag.
      // Otherwise, the browser will load the script multiple times,
      // potentially different versions.
      var serviceWorkerUrl = 'flutter_service_worker.js?v=' + serviceWorkerVersion;
      navigator.serviceWorker.register(serviceWorkerUrl)
        .then((reg) => {
          function waitForActivation(serviceWorker) {
            serviceWorker.addEventListener('statechange', () => {
              if (serviceWorker.state == 'activated') {
                console.log('Installed new service worker.');
                loadMainDartJs();
              }
            });
          }
          if (!reg.active && (reg.installing || reg.waiting)) {
            // No active web worker and we have installed or are installing
            // one for the first time. Simply wait for it to activate.
            waitForActivation(reg.installing || reg.waiting);
          } else if (!reg.active.scriptURL.endsWith(serviceWorkerVersion)) {
            // When the app updates the serviceWorkerVersion changes, so we
            // need to ask the service worker to update.
            console.log('New service worker available.');
            reg.update();
            waitForActivation(reg.installing);
          } else {
            // Existing service worker is still good.
            console.log('Loading app from cache.');
            loadMainDartJs();
          }
        });

      // If service worker doesn't succeed in a reasonable amount of time,
      // fallback to plaint <script> tag.
      setTimeout(() => {
        if (!scriptLoaded) {
          console.warn(
            'Failed to load app from service worker. Falling back to plain <script> tag.',
          );
          loadMainDartJs();
        }
      }, 4000);
    });
  } else {
    // Service workers not supported. Just drop the <script> tag.
    loadMainDartJs();
  }
})();