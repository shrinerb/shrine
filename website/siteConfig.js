/**
 * Copyright (c) 2017-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// See https://docusaurus.io/docs/site-config for all the possible
// site configuration options.

const siteConfig = {
  title: 'Shrine', // Title for your website.
  tagline: 'File attachment toolkit for Ruby applications',
  url: 'https://shrinerb.com', // Your website URL
  baseUrl: '/', // Base URL for your project */

  // Used for publishing and more
  projectName: 'shrine',
  organizationName: 'shrinerb',
  projectVersion: '3.0.0',

  // Read markdown documents from the doc/ directory
  customDocsPath: 'doc',

  // For no header links in the top nav bar -> headerLinks: [],
  headerLinks: [
    {doc: 'getting-started', label: 'Guides'},
    {doc: 'plugins/activerecord', label: 'Plugins'},
    {doc: 'external/extensions', label: 'External'},
    {href: 'https://discourse.shrinerb.com', label: 'Discourse'},
    {href: 'https://github.com/shrinerb/shrine', label: 'GitHub'},
  ],

  /* path to images for header/footer */
  headerIcon: 'img/logo.png',
  footerIcon: 'img/logo.png',
  favicon: 'img/favicon.ico',

  /* Colors for website */
  colors: {
    primaryColor: '#a4080f',
    secondaryColor: '#c0101d',
  },

  /* Custom fonts for website */
  /*
  fonts: {
    myFont: [
      "Times New Roman",
      "Serif"
    ],
    myOtherFont: [
      "-apple-system",
      "system-ui"
    ]
  },
  */

  // This copyright info is used in /core/Footer.js and blog RSS/Atom feeds.
  copyright: `Copyright © ${new Date().getFullYear()} Janko Marohnić`,

  highlight: {
    // Highlight.js theme to use for syntax highlighting in code blocks.
    theme: 'zenburn',
  },

  // Add custom scripts here that would be placed in <script> tags.
  scripts: ['https://buttons.github.io/buttons.js'],

  // On page navigation for the current documentation page.
  onPageNav: 'separate',
  // No .html extensions for paths.
  cleanUrl: true,

  // Open Graph and Twitter card images.
  ogImage: 'img/logo.png',
  twitterImage: 'img/logo.png',

  // For sites with a sizable amount of content, set collapsible to true.
  // Expand/collapse the links and subcategories under categories.
  // docsSideNavCollapsible: true,

  // Show documentation's last contributor's name.
  // enableUpdateBy: true,

  // Show documentation's last update time.
  // enableUpdateTime: true,

  // You may provide arbitrary config keys to be used as needed by your
  // template. For example, if you need your repo's URL...
  githubUrl: 'https://github.com/shrinerb/shrine',
  editUrl: 'https://github.com/shrinerb/shrine/edit/master/doc/',
  blogUrl: 'https://twin.github.io',
  discourseUrl: 'https://discourse.shrinerb.com',
  stackOverflowUrl: 'https://stackoverflow.com/questions/tagged/shrine',

  // Link to first documents
  guidesUrl: '/docs/getting-started',
  pluginsUrl: '/docs/plugins/activerecord',
  externalUrl: '/docs/external/extensions',

  twitterUsername: 'shrine_rb',

  // Display button for scrolling to top
  scrollToTop: true,

  // for CNAME
  cname: 'shrinerb.com',

  // for Google Analytics
  gaTrackingId: 'UA-149836844-1',
};

module.exports = siteConfig;
