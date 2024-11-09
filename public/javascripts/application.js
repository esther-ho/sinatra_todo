$(function() {
  // Submits the form only if the user selects OK
  $("form.delete").on('submit', function(event) {
    // Prevents the request from being sent
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure? This cannot be undone!")

    if (ok) {
      var form = $(this);

      // Submits the form asynchronously
      var request = $.ajax({
        url: form.attr("action"),
        method: form.attr("method")
      });

      // Deletes the todo item or redirects to `"/lists"` page if the request is successful
      request.done(function(data, textStatus, jqXHR) {
        if (jqXHR.status === 204) {
          form.parent('li').remove();
        } else if (jqXHR.status === 200) {
          window.location = data;
        }
      });
    }
  });
});
