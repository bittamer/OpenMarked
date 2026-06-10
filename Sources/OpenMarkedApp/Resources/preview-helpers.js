(function() {
  if (window.openMarkedPreviewHelpers) {
    return;
  }

  var helperStyleText = '.om-heading-target { outline: 2px solid -webkit-focus-ring-color; outline-offset: 4px; transition: outline-color 0.2s ease; } .om-search-match { background: color-mix(in srgb, Highlight 28%, transparent); color: inherit; border-radius: 2px; } .om-search-current { background: Mark; color: MarkText; }';

  function ensureStyle() {
    if (document.getElementById('om-preview-helpers')) {
      return;
    }

    var style = document.createElement('style');
    style.id = 'om-preview-helpers';
    style.textContent = helperStyleText;
    document.head.appendChild(style);
  }

  function createSectionTracker() {
    return {
      lastID: undefined,
      pending: false,
      installed: false,
      cacheDirty: true,
      cachedHeadings: [],
      cachedOffsets: [],
      refreshCache: function() {
        this.cachedHeadings = Array.prototype.slice.call(document.querySelectorAll('.om-document h1[id], .om-document h2[id], .om-document h3[id], .om-document h4[id], .om-document h5[id], .om-document h6[id]'));
        this.cachedOffsets = this.cachedHeadings.map(function(heading) {
          return heading.getBoundingClientRect().top + window.scrollY;
        });
        this.cacheDirty = false;
      },
      headings: function() {
        if (this.cacheDirty) {
          this.refreshCache();
        }
        return this.cachedHeadings;
      },
      post: function(id) {
        if (this.lastID === id) {
          return;
        }
        this.lastID = id;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.openMarkedSection) {
          window.webkit.messageHandlers.openMarkedSection.postMessage({ id: id || null });
        }
      },
      currentID: function() {
        if (window.openMarkedSectionTrackingBehavior === 'disabled') {
          return null;
        }

        var headings = this.headings();
        if (!headings.length) {
          return null;
        }

        var threshold = Math.max(72, window.innerHeight * 0.18);
        var targetOffset = window.scrollY + threshold;
        var low = 0;
        var high = this.cachedOffsets.length - 1;
        var index = 0;
        while (low <= high) {
          var mid = Math.floor((low + high) / 2);
          if (this.cachedOffsets[mid] <= targetOffset) {
            index = mid;
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        }
        return headings[index] ? headings[index].id : null;
      },
      report: function(id) {
        this.post(id || this.currentID());
      },
      schedule: function() {
        if (this.pending) {
          return;
        }

        this.pending = true;
        var tracker = this;
        var delay = window.openMarkedSectionTrackingBehavior === 'idleOnly' ? 240 : 90;
        window.setTimeout(function() {
          window.requestAnimationFrame(function() {
            tracker.pending = false;
            tracker.report();
          });
        }, delay);
      },
      markDirty: function() {
        this.cacheDirty = true;
        this.schedule();
      },
      install: function() {
        var tracker = this;
        if (window.openMarkedSectionTrackingBehavior === 'disabled') {
          this.post(null);
          return;
        }

        if (!this.installed) {
          window.addEventListener('scroll', function() { tracker.schedule(); }, { passive: true });
          window.addEventListener('resize', function() { tracker.markDirty(); }, { passive: true });
          Array.prototype.slice.call(document.images || []).forEach(function(image) {
            if (!image.complete) {
              image.addEventListener('load', function() { tracker.markDirty(); }, { once: true, passive: true });
              image.addEventListener('error', function() { tracker.markDirty(); }, { once: true, passive: true });
            }
          });
          this.installed = true;
        }

        this.refreshCache();
        this.schedule();
        window.setTimeout(function() { tracker.markDirty(); }, 250);
        window.setTimeout(function() { tracker.markDirty(); }, 1200);
      }
    };
  }

  function sectionTracker() {
    if (!window.openMarkedSectionTracker) {
      window.openMarkedSectionTracker = createSectionTracker();
    }
    return window.openMarkedSectionTracker;
  }

  function createSearch() {
    return {
      state: { query: '', index: -1, matches: [], searched: false },
      resetState: function() {
        this.state = { query: '', index: -1, matches: [], searched: false };
      },
      clear: function() {
        var matches = Array.prototype.slice.call(document.querySelectorAll('.om-search-match'));
        matches.forEach(function(match) {
          var text = document.createTextNode(match.textContent || '');
          match.parentNode.replaceChild(text, match);
          if (text.parentNode) {
            text.parentNode.normalize();
          }
        });
        this.resetState();
      },
      textNodes: function(root) {
        var nodes = [];
        var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
          acceptNode: function(node) {
            if (!node.nodeValue || !node.nodeValue.trim()) {
              return NodeFilter.FILTER_REJECT;
            }

            var parent = node.parentElement;
            if (!parent) {
              return NodeFilter.FILTER_REJECT;
            }

            if (parent.closest('script, style, textarea, select, .om-search-match')) {
              return NodeFilter.FILTER_REJECT;
            }

            return NodeFilter.FILTER_ACCEPT;
          }
        });
        while (walker.nextNode()) {
          nodes.push(walker.currentNode);
        }
        return nodes;
      },
      highlight: function(query) {
        var root = document.querySelector('.om-document') || document.body;
        var lowerQuery = query.toLocaleLowerCase();
        var nodes = this.textNodes(root);
        var matches = [];
        nodes.forEach(function(node) {
          var text = node.nodeValue;
          var lowerText = text.toLocaleLowerCase();
          var start = 0;
          var index = lowerText.indexOf(lowerQuery, start);
          if (index === -1) {
            return;
          }

          var fragment = document.createDocumentFragment();
          while (index !== -1) {
            if (index > start) {
              fragment.appendChild(document.createTextNode(text.slice(start, index)));
            }

            var span = document.createElement('mark');
            span.className = 'om-search-match';
            span.textContent = text.slice(index, index + query.length);
            fragment.appendChild(span);
            matches.push(span);
            start = index + query.length;
            index = lowerText.indexOf(lowerQuery, start);
          }

          if (start < text.length) {
            fragment.appendChild(document.createTextNode(text.slice(start)));
          }

          node.parentNode.replaceChild(fragment, node);
        });
        return matches;
      },
      matchesAreReusable: function() {
        return this.state.searched && this.state.matches.every(function(match) {
          return match && match.isConnected;
        });
      },
      result: function() {
        return {
          query: this.state.query,
          count: this.state.matches.length,
          selectedIndex: this.state.index >= 0 ? this.state.index + 1 : 0
        };
      },
      activate: function(index) {
        var matches = this.state.matches;
        if (!matches.length) {
          this.state.index = -1;
          return this.result();
        }

        index = Math.max(0, Math.min(index, matches.length - 1));
        if (this.state.index >= 0 && matches[this.state.index]) {
          matches[this.state.index].classList.remove('om-search-current');
        }

        matches[index].classList.add('om-search-current');
        matches[index].scrollIntoView({ behavior: window.openMarkedPrefersReducedMotion ? 'auto' : 'smooth', block: 'center' });
        this.state.index = index;
        return this.result();
      },
      run: function(query, action) {
        query = query || '';
        if (!query) {
          this.clear();
          return { query: '', count: 0, selectedIndex: 0 };
        }

        if (this.state.query === query && this.matchesAreReusable()) {
          if (!this.state.matches.length) {
            return this.result();
          }

          var currentIndex = this.state.index >= 0 ? this.state.index : 0;
          if (action === 'previous') {
            currentIndex = (currentIndex - 1 + this.state.matches.length) % this.state.matches.length;
          } else if (action === 'next') {
            currentIndex = (currentIndex + 1) % this.state.matches.length;
          }
          return this.activate(currentIndex);
        }

        this.clear();
        var matches = this.highlight(query);
        this.state = { query: query, index: -1, matches: matches, searched: true };
        if (!matches.length) {
          return this.result();
        }
        return this.activate(0);
      }
    };
  }

  window.openMarkedPreviewHelpers = {
    install: function(options) {
      options = options || {};
      ensureStyle();
      window.openMarkedPrefersReducedMotion = !!options.prefersReducedMotion;
      window.openMarkedSearch = createSearch();
      this.applySectionTrackingBehavior(options.sectionTrackingBehavior || 'active');
    },
    applySectionTrackingBehavior: function(behavior) {
      window.openMarkedSectionTrackingBehavior = behavior || 'active';
      if (window.openMarkedSectionTrackingBehavior === 'disabled') {
        sectionTracker().post(null);
      } else {
        sectionTracker().install();
      }
    },
    restoreScrollRatio: function(ratio) {
      var boundedRatio = Math.max(0, Math.min(1, Number(ratio) || 0));
      var scrollable = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
      window.scrollTo(0, scrollable * boundedRatio);
      if (window.openMarkedSectionTracker) {
        window.openMarkedSectionTracker.schedule();
      }
    },
    scrollToElement: function(id, behavior) {
      var target = document.getElementById(id);
      if (!target) {
        return false;
      }

      target.scrollIntoView({ behavior: behavior || 'auto', block: 'start' });
      target.classList.add('om-heading-target');
      window.setTimeout(function() { target.classList.remove('om-heading-target'); }, 900);
      if (window.openMarkedSectionTracker) {
        window.openMarkedSectionTracker.report(target.id);
      }
      return true;
    }
  };
})();
