const React = require('react');
const Redirect = require('../../core/Redirect.js');

const siteConfig = require(`${process.cwd()}/siteConfig.js`);

const Guides = () => (
  <Redirect
    redirect="/docs/getting-started"
    config={siteConfig}
  />
);

module.exports = Guides;
