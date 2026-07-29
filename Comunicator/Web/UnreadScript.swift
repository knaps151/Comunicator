import Foundation

enum UnreadScript {
    static let messageHandlerName = "comunicatorUnread"

    /// Title-based unread heuristics. Observes `document.head` so SPA title node replacements keep working.
    static let source: String = """
    (function() {
      if (window.__comunicatorUnreadInstalled) return;
      window.__comunicatorUnreadInstalled = true;

      function parseUnread(title) {
        if (!title) return 0;
        var m = title.match(/^\\((\\d+)\\+?\\)/);
        if (m) return parseInt(m[1], 10) || 0;
        m = title.match(/^(\\d+)\\s*[·•|]\\s/);
        if (m) return parseInt(m[1], 10) || 0;
        m = title.match(/^\\[(\\d+)\\]/);
        if (m) return parseInt(m[1], 10) || 0;
        return 0;
      }

      var last = -1;
      var lastTitle = '';
      function report() {
        var title = document.title || '';
        var count = parseUnread(title);
        if (count === last && title === lastTitle) return;
        last = count;
        lastTitle = title;
        try {
          window.webkit.messageHandlers.comunicatorUnread.postMessage({
            unread: count,
            title: title
          });
        } catch (e) {}
      }

      var target = document.head || document.documentElement;
      if (target) {
        new MutationObserver(report).observe(target, {
          childList: true,
          subtree: true,
          characterData: true
        });
      }

      setInterval(report, 4000);
      report();
    })();
    """
}
