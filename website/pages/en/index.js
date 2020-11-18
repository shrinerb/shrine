/**
 * Copyright (c) 2017-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

const React = require('react');

const CompLibrary = require('../../core/CompLibrary.js');

const MarkdownBlock = CompLibrary.MarkdownBlock; /* Used to read markdown */
const Container = CompLibrary.Container;
const GridBlock = CompLibrary.GridBlock;

const fs = require('fs');

const readFile = (name) => fs.readFileSync(`${process.cwd()}/${name}`, 'utf-8')

class HomeSplash extends React.Component {
  render() {
    const {siteConfig} = this.props;
    const {baseUrl} = siteConfig;

    const SplashContainer = props => (
      <div className="homeContainer">
        <div className="homeSplashFade">
          <div className="wrapper homeWrapper">{props.children}</div>
        </div>
      </div>
    );

    const Logo = props => (
      <div className="projectLogo">
        <img src={props.img_src} alt="Project Logo" />
      </div>
    );

    const ProjectTitle = () => (
      <h2 className="projectTitle">
        {siteConfig.title}
        <small>{siteConfig.tagline}</small>
      </h2>
    );

    const PromoSection = props => (
      <div className="section promoSection">
        <div className="promoRow">
          <div className="pluginRowBlock">{props.children}</div>
        </div>
      </div>
    );

    const Button = props => (
      <div className="pluginWrapper buttonWrapper">
        <a className="button" href={props.href} target={props.target}>
          {props.children}
        </a>
      </div>
    );

    return (
      <SplashContainer>
        <Logo img_src={`${baseUrl}img/logo.png`} />
        <div className="inner">
          <ProjectTitle siteConfig={siteConfig} />
          <PromoSection>
            <Button href="/docs/getting-started">Getting Started</Button>
            <Button href="/docs/advantages">Advantages</Button>
            <Button href="/docs/upgrading-to-3">Upgrading to 3.x</Button>
          </PromoSection>
        </div>
      </SplashContainer>
    );
  }
}

class Index extends React.Component {
  render() {
    const {config: siteConfig, language = ''} = this.props;
    const {baseUrl} = siteConfig;

    const Demo = () => {
      const content = readFile("demo.md")

      return (
        <Container background="light" className="demoContainer">
          <MarkdownBlock>{content}</MarkdownBlock>
        </Container>
      )
    };

    const Sponsors = () => {
      const sponsors = JSON.parse(readFile("sponsors.json"))
      const heartEmoji = "https://github.githubassets.com/images/icons/emoji/unicode/1f496.png"

      return (
        <Container className="sponsorsContainer">
          <h2>Sponsors <img src={heartEmoji} height="20" className="heartEmoji" /> </h2>
          <div className="sponsors">
            {sponsors.map(sponsor => (
              <a className="link" href={sponsor.link} key={sponsor.link} target="_blank">
                <img src={sponsor.avatar} alt={`${sponsor.name} avatar`} title={sponsor.name} />
                <span className="caption">{sponsor.name}</span>
              </a>
            ))}
          </div>
          <p>
            If your company is relying on Shrine or simply want to see Shrine
            evolve faster, please consider backing the project through <strong>
            <a href="https://github.com/sponsors/janko/" target="_blank">GitHub Sponsors</a></strong>.
          </p>
        </Container>
      )
    }

    return (
      <div>
        <HomeSplash siteConfig={siteConfig} language={language} />
        <div className="mainContainer">
          <Demo />
          <Sponsors />
        </div>
      </div>
    );
  }
}

module.exports = Index;
