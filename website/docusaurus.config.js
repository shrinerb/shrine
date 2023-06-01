module.exports = {
  title: "Shrine",
  tagline: "File attachment toolkit for Ruby applications",
  url: "https://shrinerb.com",
  baseUrl: "/",
  organizationName: "shrinerb",
  projectName: "shrine",
  favicon: "img/favicon.ico",
  customFields: {
    projectVersion: "3.4.0",
    githubUrl: "https://github.com/shrinerb/shrine",
    blogUrl: "https://janko.io",
    discourseUrl: "https://discourse.shrinerb.com",
    githubDiscussionsUrl: "https://github.com/shrinerb/shrine/discussions",
    stackOverflowUrl: "https://stackoverflow.com/questions/tagged/shrine"
  },
  onBrokenLinks: "log",
  onBrokenMarkdownLinks: "log",
  presets: [
    [
      "@docusaurus/preset-classic",
      {
        docs: {
          path: "../doc",
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
          editUrl: "https://github.com/shrinerb/shrine/edit/master/doc/",
          sidebarPath: "sidebars.json",
          sidebarCollapsed: false,
          breadcrumbs: false,
          rehypePlugins: [
            [require("rehype-pretty-code"), { theme: "dracula-soft" }]
          ]
        },
        theme: {
          customCss: "src/css/customTheme.css"
        }
      }
    ]
  ],
  plugins: [],
  themeConfig: {
    navbar: {
      title: "Shrine",
      style: "primary",
      logo: {
        src: "img/logo.png",
        alt: "Shrine logo"
      },
      items: [
        {
          to: "docs/getting-started",
          label: "Guides",
          position: "left"
        },
        {
          type: "docSidebar",
          sidebarId: "plugins",
          label: "Plugins",
          position: "left"
        },
        {
          type: "docSidebar",
          sidebarId: "external",
          label: "External",
          position: "left"
        },
        {
          type: "docSidebar",
          sidebarId: "release_notes",
          label: "Release Notes",
          position: "left"
        },
        {
          href: "https://github.com/shrinerb/shrine",
          label: "GitHub",
          position: "right"
        },
        {
          href: "https://github.com/shrinerb/shrine/discussions",
          label: "Discussion",
          position: "right"
        },
        {
          href: "https://github.com/shrinerb/shrine/wiki",
          label: "Wiki",
          position: "right"
        }
      ]
    },
    colorMode: {
      disableSwitch: true,
    },
    image: "img/logo.png",
    footer: {
      copyright: `Copyright © ${new Date().getFullYear()} Janko Marohnić`,
    },
    algolia: {
      appId: "KBFWBJ5DPX",
      apiKey: "1940be2342421608a122e2ff87617441",
      indexName: "shrinerb"
    }
  }
}
