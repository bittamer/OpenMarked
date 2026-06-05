(function() {
  var namespace = window.openMarkedRichContent || {};
  var currentRunID = 0;

  function featureResult(enabled) {
    return { requested: !!enabled, available: false, rendered: 0, errors: [] };
  }

  function runtimeResult(options) {
    var mermaidRequested = !!(options && options.mermaid);
    var katexRequested = !!(options && options.katex);
    return {
      ready: true,
      runID: currentRunID,
      mermaid: featureResult(mermaidRequested),
      katex: featureResult(katexRequested),
      errors: []
    };
  }

  function markReady(result) {
    document.documentElement.dataset.openmarkedRichContentReady = result.ready ? "true" : "false";
    namespace.lastResult = result;
    return result;
  }

  function globalLibrary(name) {
    if (window[name]) {
      return window[name];
    }
    if (typeof globalThis !== "undefined" && globalThis[name]) {
      return globalThis[name];
    }
    return null;
  }

  namespace.run = function(options) {
    currentRunID += 1;
    var result = runtimeResult(options || {});

    try {
      result.mermaid.available = !!globalLibrary("mermaid");
      result.katex.available = !!globalLibrary("katex");
      return markReady(result);
    } catch (error) {
      result.ready = false;
      result.errors.push(String(error && error.message ? error.message : error));
      return markReady(result);
    }
  };

  namespace.waitUntilReady = function(timeoutMilliseconds) {
    var timeout = Number(timeoutMilliseconds) || 4000;
    var startedAt = Date.now();

    return new Promise(function(resolve) {
      function poll() {
        if (namespace.lastResult && namespace.lastResult.ready) {
          resolve(namespace.lastResult);
          return;
        }

        if (Date.now() - startedAt >= timeout) {
          resolve({
            ready: false,
            timedOut: true,
            errors: ["Rich content rendering timed out."]
          });
          return;
        }

        window.setTimeout(poll, 25);
      }

      poll();
    });
  };

  window.openMarkedRichContent = namespace;
})();
