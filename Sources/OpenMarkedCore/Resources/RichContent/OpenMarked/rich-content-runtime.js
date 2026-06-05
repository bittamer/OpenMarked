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
      ready: false,
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

  function clearElement(element) {
    while (element.firstChild) {
      element.removeChild(element.firstChild);
    }
  }

  function conciseError(error) {
    var message = String(error && error.message ? error.message : error);
    return message.replace(/\s+/g, " ").trim().slice(0, 280) || "Unknown render error.";
  }

  function stripUnsafeGeneratedContent(root) {
    Array.prototype.slice.call(root.querySelectorAll("script")).forEach(function(script) {
      script.remove();
    });

    Array.prototype.slice.call(root.querySelectorAll("*")).forEach(function(element) {
      Array.prototype.slice.call(element.attributes).forEach(function(attribute) {
        if (/^on/i.test(attribute.name)) {
          element.removeAttribute(attribute.name);
        }
      });
    });
  }

  function renderError(output, message) {
    clearElement(output);
    var error = document.createElement("div");
    error.className = "om-rich-content-error";
    error.textContent = message;
    output.appendChild(error);
  }

  async function renderMermaid(result, runID) {
    var figures = Array.prototype.slice.call(document.querySelectorAll('[data-openmarked-rich="mermaid"]'));
    var mermaid = globalLibrary("mermaid");
    result.mermaid.available = !!mermaid;

    if (!figures.length) {
      return;
    }

    if (!mermaid || typeof mermaid.render !== "function") {
      result.mermaid.errors.push("Bundled Mermaid runtime is unavailable.");
      result.errors.push("Bundled Mermaid runtime is unavailable.");
      figures.forEach(function(figure) {
        var output = figure.querySelector(".om-mermaid-output");
        if (output) {
          figure.setAttribute("data-openmarked-render-state", "failed");
          renderError(output, "Mermaid runtime is unavailable.");
        }
      });
      return;
    }

    if (typeof mermaid.initialize === "function") {
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: "strict",
        deterministicIds: true,
        deterministicIDSeed: "openmarked",
        logLevel: "fatal",
        suppressErrorRendering: true,
        theme: "default"
      });
    }

    for (var index = 0; index < figures.length; index += 1) {
      var figure = figures[index];
      var sourceElement = figure.querySelector(".om-mermaid-source");
      var outputElement = figure.querySelector(".om-mermaid-output");
      var source = sourceElement ? sourceElement.textContent.trim() : "";
      var figureID = figure.id || "om-mermaid-" + (index + 1);

      if (!outputElement) {
        continue;
      }

      clearElement(outputElement);
      figure.setAttribute("data-openmarked-render-state", "rendering");
      figure.setAttribute("data-openmarked-render-run", String(runID));

      if (!source) {
        figure.setAttribute("data-openmarked-render-state", "failed");
        result.mermaid.errors.push(figureID + ": Mermaid source is empty.");
        result.errors.push("Mermaid " + figureID + ": Mermaid source is empty.");
        renderError(outputElement, "Mermaid source is empty.");
        continue;
      }

      try {
        var renderID = figureID + "-svg-" + runID;
        var rendered = await mermaid.render(renderID, source);
        outputElement.innerHTML = rendered && rendered.svg ? rendered.svg : "";
        stripUnsafeGeneratedContent(outputElement);
        if (rendered && typeof rendered.bindFunctions === "function") {
          rendered.bindFunctions(outputElement);
        }
        figure.setAttribute("data-openmarked-render-state", "rendered");
        result.mermaid.rendered += 1;
      } catch (error) {
        var message = conciseError(error);
        figure.setAttribute("data-openmarked-render-state", "failed");
        result.mermaid.errors.push(figureID + ": " + message);
        result.errors.push("Mermaid " + figureID + ": " + message);
        renderError(outputElement, message);
      }
    }
  }

  namespace.run = function(options) {
    currentRunID += 1;
    var result = runtimeResult(options || {});
    markReady(result);

    var work = [];
    try {
      result.mermaid.available = !!globalLibrary("mermaid");
      result.katex.available = !!globalLibrary("katex");
      if (result.mermaid.requested) {
        work.push(renderMermaid(result, currentRunID));
      }
    } catch (error) {
      result.errors.push(String(error && error.message ? error.message : error));
    }

    Promise.all(work)
      .then(function() {
        result.ready = true;
        markReady(result);
      })
      .catch(function(error) {
        result.errors.push(String(error && error.message ? error.message : error));
        result.ready = true;
        markReady(result);
      });

    return result;
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
