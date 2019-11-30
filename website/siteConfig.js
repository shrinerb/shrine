/**
 * Copyright (c) 2017-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

// See https://docusaurus.io/docs/site-config for all the possible
// site configuration options.

const highlight = require(`${__dirname}/highlight.js`)

const sidebars = require(`${__dirname}/sidebars.json`)

const latestSection = Object.keys(sidebars['release_notes'])[0]
const latestReleaseNotes = sidebars['release_notes'][latestSection][0]
const latestVersion = latestReleaseNotes.match(/release_notes\/(.+)/)[1]

const siteConfig = {
  title: 'Shrine', // Title for your website.
  tagline: 'File attachment toolkit for Ruby applications',
  url: 'https://shrinerb.com', // Your website URL
  baseUrl: '/', // Base URL for your project */

  // Used for publishing and more
  projectName: 'shrine',
  organizationName: 'shrinerb',
  projectVersion: latestVersion,

  // Read markdown documents from the doc/ directory
  customDocsPath: 'doc',

  // For no header links in the top nav bar -> headerLinks: [],
  headerLinks: [
    {doc: 'getting-started', label: 'Guides'},
    {doc: 'plugins/activerecord', label: 'Plugins'},
    {doc: 'external/extensions', label: 'External'},
    {href: 'https://discourse.shrinerb.com', label: 'Discourse'},
    {href: 'https://github.com/shrinerb/shrine', label: 'GitHub'},
    {href: 'https://github.com/shrinerb/shrine/wiki', label: 'Wiki'},
  ],

  algolia: {
    apiKey: '09a11b10801874df7d226df4f2ce8e8f',
    indexName: 'shrinerb',
  },

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

  markdownOptions: {
    langPrefix: 'language-',
    highlight: highlight,
  },

  // Add custom scripts here that would be placed in <script> tags.
  scripts: [
    'https://buttons.github.io/buttons.js',
    '/js/version.js',
  ],

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

  twitterUsername: 'shrine_rb',

  // Display button for scrolling to top
  scrollToTop: true,

  // for CNAME
  cname: 'shrinerb.com',

  // for Google Analytics
  gaTrackingId: 'UA-149836844-1',
};

module.exports = siteConfig;
