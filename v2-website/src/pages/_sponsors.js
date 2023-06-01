import React from 'react';

export default () => {
  const heartEmoji = "https://github.githubassets.com/images/icons/emoji/unicode/1f496.png"

  const sponsors = [
    {
      "name": "Ventrata",
      "avatar": "https://avatars0.githubusercontent.com/u/23163375?s=460&v=4",
      "link": "https://ventrata.com/"
    },
    {
      "name": "Scout APM",
      "avatar": "https://avatars2.githubusercontent.com/u/458509?s=460&v=4",
      "link": "https://scoutapm.com/"
    },
    {
      "name": "Fingerprint",
      "avatar": "https://avatars1.githubusercontent.com/u/827952?s=460&v=4",
      "link": "https://github.com/fingerprint"
    },
    {
      "name": "Mislav Marohnić",
      "avatar": "https://avatars1.githubusercontent.com/u/887?s=460&v=4",
      "link": "https://github.com/mislav"
    },
    {
      "name": "Stanko Krtalić",
      "avatar": "https://avatars1.githubusercontent.com/u/1655218?s=400&v=4",
      "link": "https://github.com/monorkin"
    },
    {
      "name": "Maxence",
      "avatar": "https://avatars2.githubusercontent.com/u/6090320?s=460&v=4",
      "link": "https://github.com/maxence33"
    },
    {
      "name": "Bryan O'Neal",
      "avatar": "https://avatars2.githubusercontent.com/u/13574856?s=460&u=796bc2484b66416c7a6c5c361f66a17e263abc60&v=4",
      "link": "https://github.com/1AL"
    },
    {
      "name": "Benjamin Klotz",
      "avatar": "https://avatars3.githubusercontent.com/u/675705?s=460&u=e561fcc1ba934317e6bd8742789211bf4d7cae73&v=4",
      "link": "https://github.com/tak1n"
    },
    {
      "name": "Igor S. Morozov",
      "avatar": "https://avatars3.githubusercontent.com/u/887264?s=460&u=2b573c7479a75cb46b23d3613f0302ae85b3aef3&v=4",
      "link": "https://github.com/Morozzzko"
    },
    {
      "name": "Wout",
      "avatar": "https://avatars1.githubusercontent.com/u/107324?s=460&u=5ab2e18bf785c061df13c53067cd671e2b74e10a&v=4",
      "link": "https://github.com/wout"
    },
  ]

  return (
    <div style={{ backgroundColor: "#fef2f2", paddingTop: "2rem", paddingBottom: "2rem" }}>
      <div className="container" style={{ maxWidth: "900px", marginLeft: "auto", marginRight: "auto" }}>
        <h2 style={{ marginBottom: "2rem" }}>Sponsors <img src={heartEmoji} height="20" className="heartEmoji" /></h2>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(5, minmax(0, 1fr))", gap: "3rem" }}>
          {sponsors.map(sponsor => (
            <a className="link" href={sponsor.link} key={sponsor.link} target="_blank">
              <div className="avatar avatar--vertical">
                <img className="avatar__photo avatar__photo--xl" src={sponsor.avatar} alt={`${sponsor.name} avatar`} title={sponsor.name} style={{ height: "auto" }} />
                <div className="avatar__intro" style={{ marginTop: "1rem" }}>
                  <div className="avatar__name" style={{ color: "var(--ifm-color-primary-lighter)" }}>{sponsor.name}</div>
                </div>
              </div>
            </a>
          ))}
        </div>
      </div>
    </div>
  )
}
