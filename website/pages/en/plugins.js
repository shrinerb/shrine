const React = require('react');
const Redirect = require('../../core/Redirect.js');

const siteConfig = require(`${process.cwd()}/siteConfig.js`);

const Plugins = () => (
  <Redirect
    redirect="/docs/plugins/activerecord"
    config={siteConfig}
  />
);

module.exports = Plugins;
