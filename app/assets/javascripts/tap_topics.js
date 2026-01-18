// Tap Topics page interactions: boardset modal + PDF preview toggle
// Uses Bootstrap 4 modal events and jQuery.

(function () {
  function isTapTopicsPage() {
    return window.location && window.location.pathname && window.location.pathname.indexOf("tap-topics") !== -1;
  }

  $(document).on("turbolinks:load", function () {
    if (!isTapTopicsPage()) return;

    var $modal = $("#tapTopicsBoardsetModal");
    if ($modal.length === 0) return;

    var $pdf = $("#tapTopicsBoardsetModalPdf");
    var $pdfLink = $("#tapTopicsBoardsetModalPdfLink");
    var $title = $("#tapTopicsBoardsetModalLabel");
    var $qualityLow = $("#tapTopicsQualityLow");
    var $qualityHigh = $("#tapTopicsQualityHigh");
    var $qualityLowLabel = $("#tapTopicsQualityLowLabel");
    var $qualityHighLabel = $("#tapTopicsQualityHighLabel");
    var $qualityHint = $("#tapTopicsQualityHint");

    function setQualityAvailability(lowUrl, highUrl) {
      var hasLow = !!(lowUrl && lowUrl.length);
      var hasHigh = !!(highUrl && highUrl.length);

      $qualityLow.prop("disabled", !hasLow);
      $qualityHigh.prop("disabled", !hasHigh);
      $qualityLowLabel.toggleClass("disabled", !hasLow);
      $qualityHighLabel.toggleClass("disabled", !hasHigh);

      if (!hasLow && !hasHigh) {
        $qualityHint.text("No PDF preview available.");
      } else if (hasLow && !hasHigh) {
        $qualityHint.text("High definition not available.");
      } else if (!hasLow && hasHigh) {
        $qualityHint.text("Low definition not available.");
      } else {
        $qualityHint.text("");
      }
    }

    function setActiveQuality(quality) {
      var isLow = quality === "low";
      var isHigh = quality === "high";

      $qualityLow.prop("checked", isLow);
      $qualityHigh.prop("checked", isHigh);
      $qualityLowLabel.toggleClass("active", isLow);
      $qualityHighLabel.toggleClass("active", isHigh);
    }

    function setPreviewUrl(url) {
      var hasUrl = !!(url && url.length);
      var displayUrl = hasUrl ? url : "about:blank";
      $pdf.toggleClass("d-none", !hasUrl);
      $pdf.attr("data", displayUrl);
      $pdfLink.attr("href", hasUrl ? displayUrl : "#");
      $pdfLink.toggleClass("disabled", !hasUrl);
    }

    $modal.on("show.bs.modal", function (event) {
      var trigger = event.relatedTarget;
      if (!trigger) return;

      var $trigger = $(trigger);
      var lowUrl = $trigger.data("low-url");
      var highUrl = $trigger.data("high-url");
      var title = $trigger.data("title") || "Boardset";

      $title.text(title);
      // Clear any previous PDF to avoid showing stale content.
      setPreviewUrl("");

      setQualityAvailability(lowUrl, highUrl);

      // Default to low definition when available; otherwise fall back to high.
      if (lowUrl && lowUrl.length) {
        setActiveQuality("low");
        setPreviewUrl(lowUrl);
      } else if (highUrl && highUrl.length) {
        setActiveQuality("high");
        setPreviewUrl(highUrl);
      } else {
        setActiveQuality(null);
        setPreviewUrl("");
      }

      $qualityLow.off("change.tapTopics").on("change.tapTopics", function () {
        if ($(this).is(":checked")) {
          setActiveQuality("low");
          setPreviewUrl(lowUrl);
        }
      });

      $qualityHigh.off("change.tapTopics").on("change.tapTopics", function () {
        if ($(this).is(":checked")) {
          setActiveQuality("high");
          setPreviewUrl(highUrl);
        }
      });
    });

    $modal.on("hidden.bs.modal", function () {
      setPreviewUrl("");
      setActiveQuality(null);
      $qualityHint.text("");
    });
  });
})();


