// Projects page interactions: gallery lightbox modal
// Uses Bootstrap 4 modal events and jQuery.

(function () {
  function isProjectsShowPage() {
    return (
      window.location &&
      window.location.pathname &&
      window.location.pathname.indexOf("/projects/") !== -1 &&
      // exclude index (/projects or /projects/)
      window.location.pathname.replace(/\/+$/, "") !== "/projects"
    );
  }

  $(document).on("turbolinks:load", function () {
    if (!isProjectsShowPage()) return;

    var $modal = $("#projectGalleryModal");
    if ($modal.length === 0) return;

    var $img = $("#projectGalleryModalImage");
    var $title = $("#projectGalleryModalLabel");

    function clearModal() {
      $img.attr("src", "");
    }

    $modal.on("show.bs.modal", function (event) {
      var trigger = event.relatedTarget;
      if (!trigger) return;

      var $trigger = $(trigger);
      var imageUrl = $trigger.data("image-url");
      var title = $trigger.data("title") || "Image";

      $title.text(title);
      $img.attr("src", imageUrl || "");
    });

    $modal.on("hidden.bs.modal", function () {
      clearModal();
    });
  });
})();

