/**
 * Copyright (c) 2017-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

const React = require('react');

class Footer extends React.Component {
  render() {
    const config = this.props.config

    return (
      <footer className="nav-footer" id="footer">
        <section className="sitemap">
          <a href={config.baseUrl} className="nav-home">
            {config.footerIcon && (
              <img
                src={config.baseUrl + config.footerIcon}
                alt={config.title}
                width="66"
              />
            )}
          </a>
          <div>
            <h5>Docs</h5>
            <a href="/guides">Guides</a>
            <a href="/plugins">Plugins</a>
            <a href="/external">External</a>
            <a href={`${config.githubUrl}/blob/master/CONTRIBUTING.md#readme`}>Contributing</a>
          </div>
          <div>
            <h5>Community</h5>
            <a
              href={config.discourseUrl}
              target="_blank"
              rel="noreferrer noopener">
              Discourse
            </a>
            <a
              href={config.stackOverflowUrl}
              target="_blank"
              rel="noreferrer noopener">
              Stack Overflow
            </a>
          </div>
          <div>
            <h5>More</h5>
            <a href={config.blogUrl}>Blog</a>
            <a href={config.githubUrl}>GitHub</a>
            <a
              className="github-button"
              href={config.githubUrl}
              data-icon="octicon-star"
              data-count-href={`/${config.organizationName}/${config.projectName}/stargazers`}
              data-show-count="true"
              data-count-aria-label="# stargazers on GitHub"
              aria-label="Star this project on GitHub">
              Star
            </a>
            {config.twitterUsername && (
              <div className="social">
                <a
                  href={`https://twitter.com/${
                    config.twitterUsername
                  }`}
                  className="twitter-follow-button">
                  Follow @{config.twitterUsername}
                </a>
              </div>
            )}
          </div>
        </section>
        <section className="copyright">{config.copyright}</section>
      </footer>
    );
  }
}

module.exports = Footer;
