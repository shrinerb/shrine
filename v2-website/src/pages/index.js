import React from 'react';
import Layout from '@theme/Layout';
import Sponsors from './_sponsors';

export default () => {
  return (
    <Layout title="Home">
      <div className="hero" style={{ textAlign: "center", color: "var(--ifm-color-danger)" }}>
        <div className="container">
          <img src="img/logo.png" height="100" style={{ marginBottom: '2rem' }} />
          <h1 className="hero__title ">Shrine</h1>
          <p className="hero__subtitle">File attachment toolkit for Ruby applications</p>
          <div>
            <a href="/docs/getting-started" className="button button--danger button--outline button--lg margin-right--sm">
              Get Started
            </a>
            <a href="/docs/advantages" className="button button--danger button--outline button--lg">
              Advantages
            </a>
          </div>
        </div>
      </div>

      <Sponsors />
    </Layout>
  );
};
