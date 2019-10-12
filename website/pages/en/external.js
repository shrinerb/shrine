const React = require('react');
const Redirect = require('../../core/Redirect.js');

const siteConfig = require(`${process.cwd()}/siteConfig.js`);

const External = () => (
  <Redirect
    redirect="/docs/external/extensions"
    config={siteConfig}
  />
);

module.exports = External;
