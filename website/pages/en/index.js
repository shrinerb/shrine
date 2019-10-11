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

    const Features = () => (
      <div className="features">
        <Container>
          <MarkdownBlock>{`
* **Modular design** – the [plugin system] allows you to load only the functionality you need
* **Memory friendly** – streaming uploads and [downloads][Retrieving Uploads] make it work great with large files
* **Cloud storage** – store files on [disk][FileSystem], [AWS S3][S3], [Google Cloud][GCS], [Cloudinary] and others
* **Persistence integrations** – works with [Sequel], [ActiveRecord], [ROM], [Hanami] and [Mongoid] and others
* **Flexible processing** – generate thumbnails [up front] or [on-the-fly] using [ImageMagick] or [libvips]
* **Metadata validation** – [validate files][validation] based on [extracted metadata][metadata]
* **Direct uploads** – upload asynchronously [to your app][simple upload] or [to the cloud][presigned upload] using [Uppy]
* **Resumable uploads** – make large file uploads [resumable][resumable upload] on [S3][uppy-s3_multipart] or [tus][tus-ruby-server]
* **Background jobs** – built-in support for [background processing][backgrounding] that supports [any backgrounding library][Backgrounding Libraries]

[plugin system]: /docs/getting-started#plugin-system
[Retrieving Uploads]: /docs/retrieving-uploads
[FileSystem]: /docs/storage/file-system
[S3]: /docs/storage/s3
[GCS]: https://github.com/renchap/shrine-google_cloud_storage
[Cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[Sequel]: /docs/plugins/sequel
[ActiveRecord]: /docs/plugins/activerecord
[ROM]: https://github.com/shrinerb/shrine-rom
[Hanami]: https://github.com/katafrakt/hanami-shrine
[Mongoid]: https://github.com/shrinerb/shrine-mongoid
[up front]: /docs/getting-started#processing-up-front
[on-the-fly]: /docs/getting-started#processing-on-the-fly
[ImageMagick]: https://github.com/janko/image_processing/blob/master/doc/minimagick.md#readme
[libvips]: https://github.com/janko/image_processing/blob/master/doc/vips.md#readme
[validation]: /docs/validation
[metadata]: /docs/metadata
[simple upload]: /docs/getting-started#simple-direct-upload
[presigned upload]: /docs/getting-started#presigned-direct-upload
[resumable upload]: /docs/getting-started#resumable-direct-upload
[Uppy]: https://uppy.io/
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[tus-ruby-server]: https://github.com/janko/tus-ruby-server
[backgrounding]: /docs/plugins/backgrounding
[Backgrounding Libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
          `}</MarkdownBlock>
        </Container>
      </div>
    );

    return (
      <div>
        <HomeSplash siteConfig={siteConfig} language={language} />
        <div className="mainContainer">
          <Features />
        </div>
      </div>
    );
  }
}

module.exports = Index;
