// Tap Topics page interactions: boardset modal + printing
// Uses Bootstrap 4 modal events and jQuery.

(function () {
  function isTapTopicsPage() {
    return window.location && window.location.pathname && window.location.pathname.indexOf("tap-topics") !== -1;
  }

  // Print without opening a new tab/window (more reliable across browsers).
  function printImage(imageUrl, title) {
    if (!imageUrl) {
      alert("No image available to print for this boardset.");
      return;
    }

    // Remove any existing print frame
    var existing = document.getElementById("tapTopicsPrintFrame");
    if (existing && existing.parentNode) existing.parentNode.removeChild(existing);

    var iframe = document.createElement("iframe");
    iframe.id = "tapTopicsPrintFrame";
    iframe.style.position = "fixed";
    iframe.style.right = "0";
    iframe.style.bottom = "0";
    iframe.style.width = "0";
    iframe.style.height = "0";
    iframe.style.border = "0";
    iframe.style.visibility = "hidden";

    var safeTitle = (title || "Boardset").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    var safeUrl = String(imageUrl).replace(/'/g, "%27");

    iframe.srcdoc = ""
      + "<!doctype html>"
      + "<html><head><meta charset='utf-8'/>"
      + "<title>" + safeTitle + "</title>"
      + "<style>html,body{margin:0;padding:0;}img{max-width:100%;height:auto;display:block;margin:0 auto;}</style>"
      + "</head><body>"
      + "<img id='img' src='" + safeUrl + "' alt='" + safeTitle + "'/>"
      + "</body></html>";

    iframe.onload = function () {
      try {
        var win = iframe.contentWindow;
        if (!win) return;
        win.focus();
        win.print();
      } catch (e) {
        // Fallback: open image in a new tab if printing via iframe fails
        window.open(imageUrl, "_blank");
      } finally {
        // Cleanup after a short delay (allows print dialog to open)
        setTimeout(function () {
          if (iframe && iframe.parentNode) iframe.parentNode.removeChild(iframe);
        }, 1000);
      }
    };

    document.body.appendChild(iframe);
  }

  $(document).on("turbolinks:load", function () {
    if (!isTapTopicsPage()) return;

    var $modal = $("#tapTopicsBoardsetModal");
    if ($modal.length === 0) return;

    var $img = $("#tapTopicsBoardsetModalImage");
    var $title = $("#tapTopicsBoardsetModalLabel");
    var $printLow = $("#tapTopicsPrintLow");
    var $printHigh = $("#tapTopicsPrintHigh");

    $modal.on("show.bs.modal", function (event) {
      var trigger = event.relatedTarget;
      if (!trigger) return;

      var $trigger = $(trigger);
      var lowUrl = $trigger.data("low-url");
      var highUrl = $trigger.data("high-url");
      var title = $trigger.data("title") || "Boardset";

      $title.text(title);
      $img.attr("src", highUrl || lowUrl || "");
      $img.attr("alt", title);

      $printLow.data("print-url", lowUrl || "");
      $printHigh.data("print-url", highUrl || lowUrl || "");
      $printLow.data("print-title", title);
      $printHigh.data("print-title", title);

      // Disable buttons if URLs missing
      $printLow.prop("disabled", !(lowUrl && lowUrl.length));
      $printHigh.prop("disabled", !(highUrl && highUrl.length) && !(lowUrl && lowUrl.length));
    });

    $modal.on("hidden.bs.modal", function () {
      $img.attr("src", "");
      $printLow.data("print-url", "");
      $printHigh.data("print-url", "");
    });

    $printLow.on("click", function () {
      printImage($(this).data("print-url"), $(this).data("print-title"));
    });

    $printHigh.on("click", function () {
      printImage($(this).data("print-url"), $(this).data("print-title"));
    });
  });
})();


