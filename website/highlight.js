const Highlights = require('highlights')

const highlighter = new Highlights()

highlighter.requireGrammarsSync({
  modulePath: require.resolve('language-diff/package.json'),
})

const languageScopes = {
  rb: 'source.ruby',
  ruby: 'source.ruby',
  js: 'source.js',
  erb: 'text.html.erb',
  diff: 'source.diff',
  xml: 'text.xml',
  yml: 'source.yaml',
  yaml: 'source.yaml',
}

const highlight = (string, language) => {
  if (!language) return string

  const scope = languageScopes[language]

  if (!scope) throw new Error(`unsupported language: ${language}`)

  let html = highlighter.highlightSync({
    fileContents: string,
    scopeName: scope,
  })

  html = html.replace(/<\/?pre[^>]*>/g, '') // remove extra <pre> tags

  return html
};

module.exports = highlight;
