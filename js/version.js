document.addEventListener('DOMContentLoaded', function() {
  var titleWithLogo = document.querySelector('.headerTitleWithLogo').parentNode

  var version = document.getElementById('footer').dataset.version

  var versionLink = document.createElement('a')
  versionLink.href = '/docs/release_notes/' + version
  versionLink.innerHTML = '<h3>' + version + '</h3>'

  titleWithLogo.parentNode.insertBefore(versionLink, titleWithLogo.nextSibling)
})
