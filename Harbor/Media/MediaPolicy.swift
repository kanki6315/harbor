// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import WebKit

enum MediaPolicy {
    static func configure(_ configuration: WKWebViewConfiguration) {
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        // GIF-style videos need to autoplay; WebKit still gates audible playback on a gesture.
        configuration.mediaTypesRequiringUserActionForPlayback = .audio
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addUserScript(WKUserScript(
            source: redditRecoveryScript, injectionTime: .atDocumentStart,
            forMainFrameOnly: true, in: recoveryWorld))
    }
    static let recoveryWorld = WKContentWorld.world(name: "HarborMediaRecovery")

    // Reddit nests GIF-style videos in open shadow roots. Keep playback bookkeeping
    // isolated from site JavaScript and repair individual players, never the whole page.
    static let redditRecoveryScript = #"""
    (() => {
        if (location.hostname !== 'reddit.com' && !location.hostname.endsWith('.reddit.com')) return;
        let suspended = false;
        let generation = 0;
        let playing = new Set();
        const videos = (root = document) => {
            const result = Array.from(root.querySelectorAll('video'));
            for (const element of root.querySelectorAll('*')) {
                if (element.shadowRoot) result.push(...videos(element.shadowRoot));
            }
            return result;
        };
        const eligible = v => v.isConnected && v.muted && v.loop &&
            !v.ended && !v.webkitDisplayingFullscreen &&
            v.webkitPresentationMode !== 'picture-in-picture' && !v.srcObject;
        const visible = v => {
            const rect = v.getBoundingClientRect();
            return rect.width > 0 && rect.height > 0 && rect.bottom > 0 &&
                rect.right > 0 && rect.top < innerHeight && rect.left < innerWidth;
        };
        const play = v => { const result = v.play(); if (result) result.catch(() => {}); };
        globalThis.harborSuspendMedia = () => {
            if (suspended) return;
            suspended = true;
            ++generation;
            playing = new Set(videos().filter(v => eligible(v) && !v.paused));
        };
        globalThis.harborResumeMedia = () => {
            if (!suspended) return;
            suspended = false;
            const currentGeneration = ++generation;
            const previous = playing;
            playing = new Set();
            for (const v of videos()) {
                if (!eligible(v) || !visible(v) || (v.paused && !previous.has(v))) continue;
                const source = v.currentSrc;
                const time = v.currentTime;
                // Restart the rendering pipeline even when WebKit reports "playing".
                v.pause();
                play(v);
                setTimeout(() => {
                    if (generation !== currentGeneration || suspended || document.hidden ||
                        !eligible(v) || !visible(v) || v.paused || v.currentSrc !== source ||
                        v.currentTime !== time) return;
                    // A stalled direct-file player can safely reacquire its resource.
                    // Reloading MediaSource/blob players would discard the site's stream.
                    if (!/^https?:/i.test(source)) return;
                    v.load();
                    play(v);
                }, 1500);
            }
        };
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) globalThis.harborSuspendMedia();
        });
    })();
    """#
}
