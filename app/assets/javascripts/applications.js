// Javascript used on applications pages
$('#comment_address_input a').click(function(e) {
  e.preventDefault();
  $('#faq_commenting_address').slideToggle('fast');
});

$('#comment_text_input a').click(function(e) {
  e.preventDefault();
  $('#disclosure_explanation').slideToggle('fast');
});

if ($('#comment-receiver-inputgroup').length) {
  // TODO: Add aria attributes for accessibility
  // TODO: Fix keyboard navigation
  councillorTogglerRadio = document.createElement('input');
  $(councillorTogglerRadio).attr('type','radio')
                           .attr('id', 'councillors-list-toggler')
                           .attr('class', 'receiver-select-radio receiver-type-option');

  councillorTogglerLabel = document.createElement('label');
  $(councillorTogglerLabel).attr('for', 'councillors-list-toggler')
                           .attr('class', 'receiver-select-label receiver-type-option');

  $('.councillor-select-list').before(councillorTogglerRadio)
                              .before(councillorTogglerLabel);

  $('label[for="councillors-list-toggler"').append('<strong>' + $('.councillor-select-list-intro strong').text() + '</strong><p>' + $('.councillor-select-list-intro p').text() + '</p>');

  $('.councillor-select-list-intro').remove();

  radioForAuthorityOption = $('#receiver-to-authority-option')
  radioForCouncillorsList = $('#councillors-list-toggler')

  $(radioForCouncillorsList).click(function(e) {
    if ($(radioForAuthorityOption).prop('checked') === true) {
      $(radioForAuthorityOption).prop('checked', false);
    }
  });

  $(radioForAuthorityOption).click(function(e) {
    if ($(radioForCouncillorsList).prop('checked') === true) {
      $(radioForCouncillorsList).prop('checked', false);
    }
  });
}

// GA Tracking of comment process
$( document ).ready(function() {
  // check if the Google Analytics function is available
  if (typeof ga == 'function') {
    $('.link-to-comment-form').click(function(e) {
      ga('send', 'event', 'comments', 'click link to go to comment form');
    });

    $('#comment_submit_action input[type="submit"]').click(function(e) {
      ga('send', 'event', 'comments', 'click submit new comment');
    });

    if ($('.notice-comment-confirmed').length) {
      ga('send', 'event', 'comments', 'comment confirm message displayed');
    }
  }
});
