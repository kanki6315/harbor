# Bundled resources

- `InterVariable.ttf`: official Inter font, https://github.com/rsms/inter/blob/master/docs/font-files/InterVariable.ttf, retrieved 2026-10-07. Distributed under the SIL Open Font License in `Inter-LICENSE.txt`. Used only for Harbor brand lettering; system fonts remain in controls.
- `media-fixture.mp4`: original synthetic test asset generated locally using FFmpeg: eight seconds of navy H.264 video and a 440 Hz AAC tone. No third-party footage or recordings.
- `browser-fixture.html`: authored local debug fixture. Never loaded during normal browsing.
- `tracker-rules.json`: authored conservative WebKit content rules; not copied from an externally maintained filter list.
- App icon: original user-supplied `assets/HarborIcon/Harbor.icon`, referenced directly by the project.
- Start-page art: original, static Canvas artwork in `HarborTheme.swift`, implementing the selected Horizon direction. The Harbor mark uses the supplied SVG path coordinates.

## Domain suffix snapshot

`tlds-alpha-by-domain.txt` is the IANA root-zone TLD list, retrieved October 7, 2026 from https://data.iana.org/TLD/tlds-alpha-by-domain.txt. It is used locally to distinguish unschemed domain names from search terms. Refresh this snapshot when updating domain recognition; explicit HTTP(S) URLs continue to work for new or private suffixes.
