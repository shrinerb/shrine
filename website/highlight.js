const Highlights = require('highlights')

const highlighter = new Highlights()

highlighter.requireGrammarsSync({
  modulePath: require.resolve('language-diff/package.json'),
})

const languageScopes = {
  rb: 'source.ruby',
  ruby: 'source.ruby',
  js: 'source.js',
  json: 'source.json',
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

  // strip extra <pre> tags
  html = html.replace(/<\/?pre[^>]*>/g, '') 
  // strip extra <span> elements that are slowing down rendering
  html = html.replace(/<span>([^<]*)<\/span>/g, '$1') 

  return html
};

module.exports = highlight;
