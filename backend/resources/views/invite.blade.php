<!DOCTYPE html>
<html lang="en">
{{-- The invite web demo served at /i/{code} — what someone WITHOUT the app
     sees. This is variant B of the 2026-07 A/B test (reveal = the media with
     the viewer's reaction below it), which Achia picked as the winner; the
     reaction-only variant and its /ib route were deleted 2026-08-04. --}}
<head>
    {{-- CSRF token for the funnel beacon below. The step endpoint is a normal
         web route, so it keeps Laravel's CSRF protection rather than being
         excluded from it. --}}
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>{{ $inviter ? $inviter->first_name . ' invited you to Reacti' : 'You’re invited to Reacti' }}</title>
    <style>
        :root {
            /* Dark form controls, and a dark overscroll/rubber-band area. */
            color-scheme: dark;
            --lime: #c7f24a;
            --lime-soft: #d9f97a;
            --ink: #0f1005;
            --bg0: #12140a;
            --bg1: #1b2010;
            --text: #f4f6ea;
            --muted: #b9bfa6;
        }
        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
        html, body { margin: 0; height: 100%; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            color: var(--text);
            /* The colour matters as much as the gradient: a gradient paints only
               inside body's box, and iOS Safari's visible area is taller than
               height:100% once the toolbars collapse. Without a solid colour
               underneath, that strip fell through to the browser's white. */
            background: var(--bg0)
                radial-gradient(120% 80% at 50% -10%, #24300f 0%, var(--bg1) 45%, var(--bg0) 100%);
            overflow: hidden;
        }
        .stage { position: fixed; inset: 0; }

        /* Full-screen pages */
        .page {
            position: absolute; inset: 0;
            display: none;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            text-align: center;
            padding: max(28px, env(safe-area-inset-top)) 26px max(28px, env(safe-area-inset-bottom));
            gap: 14px;
            animation: pop .5s cubic-bezier(.2,.9,.25,1.2);
        }
        .page.active { display: flex; }
        @keyframes pop { from { opacity: 0; transform: translateY(14px) scale(.98); } to { opacity: 1; transform: none; } }

        .badge {
            font-size: 12px; letter-spacing: 2px; text-transform: uppercase;
            color: var(--lime); font-weight: 800;
        }
        .emoji { font-size: 56px; line-height: 1; animation: float 3s ease-in-out infinite; }
        @keyframes float { 0%,100% { transform: translateY(0) rotate(-3deg); } 50% { transform: translateY(-10px) rotate(3deg); } }
        h1 { font-size: 30px; line-height: 1.15; margin: 4px 0; letter-spacing: -.5px; }
        h1 .hl { color: var(--lime); }
        p { color: var(--muted); line-height: 1.5; margin: 0; font-size: 16px; max-width: 30ch; }

        .btn {
            appearance: none; border: 0; cursor: pointer;
            font-size: 18px; font-weight: 800; color: var(--ink);
            background: var(--lime);
            padding: 16px 30px; border-radius: 999px;
            box-shadow: 0 10px 30px rgba(199,242,74,.28);
            transition: transform .12s ease, box-shadow .12s ease;
            margin-top: 8px;
        }
        .btn:active { transform: scale(.95); box-shadow: 0 6px 18px rgba(199,242,74,.24); }
        .btn.ghost { background: transparent; color: var(--muted); box-shadow: none; font-weight: 600; font-size: 15px; padding: 10px; }
        .btn.store { display: inline-flex; align-items: center; gap: 9px; text-decoration: none; }
        .store-note { margin-top: 2px; font-size: 13px; color: var(--muted); }
        /* "Maybe later" sat right under the primary button and read as part of
           it — give it air so the eye lands on "Let's go" first. */
        .btn.ghost.spaced { margin-top: 26px; }

        /* Skip (×) */
        .skip {
            position: absolute; top: max(14px, env(safe-area-inset-top)); right: 16px;
            z-index: 5;
            appearance: none; border: 0; cursor: pointer;
            background: rgba(255,255,255,.08); color: var(--text);
            width: 40px; height: 40px; border-radius: 999px; font-size: 20px; line-height: 1;
        }

        /* Sealed media tile */
        .tile {
            position: relative; width: min(84vw, 360px); aspect-ratio: 3/4;
            max-height: 56vh;
            border-radius: 22px; overflow: hidden;
            background: #000; border: 1px solid #2b3115;
            box-shadow: 0 20px 50px rgba(0,0,0,.5);
            margin: 4px auto;
        }
        /* contain = show the whole clip, never crop the sides; the tile snaps to
           the clip's real aspect ratio on load (JS), so there are no bars either. */
        .tile video { width: 100%; height: 100%; object-fit: contain; display: block; }
        .seal {
            position: absolute; inset: 0; display: flex; flex-direction: column;
            align-items: center; justify-content: center; gap: 10px;
            background: rgba(12,14,8,.34);
            backdrop-filter: blur(18px) saturate(1.1); -webkit-backdrop-filter: blur(18px) saturate(1.1);
            cursor: pointer; transition: opacity .4s ease;
            font-weight: 800; font-size: 18px;
        }
        /* The nudge used to live on a pointing-finger emoji. The emoji is gone
           (the eyes in the heading are the only one on this screen now), so the
           motion moves onto the tap line itself: a tap target that never moves
           reads as a label rather than a button. */
        .seal .tap { animation: nudge 1.4s ease-in-out infinite; }
        /* The front camera starts on the tap and there is no self-preview, so
           this has to be read BEFORE it: afterwards the framing is already
           fixed and the first, most genuine second is a ceiling shot. It lives
           inside the seal rather than under the tile so it is the last thing
           the eye passes on its way to tapping, and so it costs no page
           height on short viewports. */
        .seal .hold {
            font-size: 14px; font-weight: 600; line-height: 1.35;
            color: var(--lime-soft); max-width: 84%;
        }
        @keyframes nudge { 0%,100% { transform: translateY(0); } 50% { transform: translateY(8px); } }
        .tile.open .seal { opacity: 0; pointer-events: none; }

        /* Tiny countdown ring — the only hint that the capture is running.
           Deliberately small + dim: first-timers were tapping the screen again
           because nothing moved, but a big timer would pull the eye off the
           clip (that's what we're recording a reaction to). */
        .timer {
            position: absolute; bottom: 10px; right: 10px;
            width: 22px; height: 22px; transform: rotate(-90deg);
            opacity: 0; transition: opacity .35s ease;
        }
        .tile.open .timer { opacity: .5; }
        .timer circle { fill: none; stroke-width: 3; }
        .timer .track { stroke: rgba(255,255,255,.22); }
        .timer .run { stroke: var(--lime); stroke-dasharray: 94.3; stroke-dashoffset: 0; }
        /* Starts only once the tile opens, so it can't run out before the tap.
           Duration is overridden from JS to stay in step with RECORD_MS. */
        .tile.open .timer .run { animation: countdown 4500ms linear forwards; }
        @keyframes countdown { to { stroke-dashoffset: 94.3; } }

        /* Reveal — VARIANT B: media on top, the viewer's reaction below it. */
        .pair { display: flex; flex-direction: column; gap: 10px; align-items: center; width: 100%; }
        .pair-cap { font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); }
        .pair-vid {
            width: min(60vw, 240px); aspect-ratio: 3/4; max-height: 26vh;
            border-radius: 18px; object-fit: cover; background: #000;
            border: 1px solid #2b3115; box-shadow: 0 12px 28px rgba(0,0,0,.5);
        }
        .pair-vid.mine { border: 2px solid var(--lime); transform: scaleX(-1); }
        /* The reveal is the tallest page (two clips + CTA). Tighter gaps keep
           the store button above the fold on short viewports; body is
           overflow:hidden, so anything past the fold is unreachable. */
        #p-reveal { gap: 10px; }

        .code {
            margin-top: 6px; font-size: 13px; color: var(--muted);
        }
        .code b { color: var(--lime); letter-spacing: 2px; user-select: all; }

        /* Skip confirm modal */
        .modal-wrap {
            position: fixed; inset: 0; z-index: 20; display: none;
            align-items: center; justify-content: center; padding: 26px;
            background: rgba(0,0,0,.55);
        }
        .modal-wrap.show { display: flex; animation: pop .25s ease; }
        .modal {
            width: 100%; max-width: 340px; background: #1b2010;
            border: 1px solid #2b3115; border-radius: 22px; padding: 26px 22px; text-align: center;
        }
        .modal .emoji { font-size: 44px; animation: none; }
        .modal h2 { margin: 8px 0 4px; font-size: 21px; }
        .modal .row { display: flex; flex-direction: column; gap: 8px; margin-top: 16px; }
    </style>
</head>
<body>
    <div class="stage">
        {{-- Page 1 — the idea + ready? --}}
        <section class="page active" id="p-intro">
            <button class="skip" data-skip aria-label="Skip">×</button>
            <div class="emoji">✉️</div>
            <div class="badge">{{ $inviter ? $inviter->first_name . ' invited you' : 'You’re invited' }}</div>
            <h1>See a friend’s <span class="hl">real</span> reaction the moment they open your photo.</h1>
            <button class="btn" id="go-perm">Let’s go ▶</button>
            <button class="btn ghost spaced" data-skip>Maybe later</button>
        </section>

        {{-- Page 2 — one-time permission --}}
        <section class="page" id="p-perm">
            <button class="skip" data-skip aria-label="Skip">×</button>
            <div class="emoji">✨</div>
            <div class="badge">One-time setup</div>
            <h1>We ask for camera &amp; mic <span class="hl">just once</span>. 🔒</h1>
            <button class="btn" id="grant">Allow camera &amp; mic</button>
            <button class="btn ghost" data-skip>Skip the demo</button>
        </section>

        {{-- Page 3 — the sealed Reacti. --}}
        <section class="page" id="p-demo">
            <button class="skip" data-skip aria-label="Skip">×</button>
            <div class="badge">{{ $inviter ? 'From ' . $inviter->first_name : 'A Reacti for you' }}</div>
            <h1>Here’s a Reacti 👀</h1>
            <p>Someone sent you a Reacti. Open it to see what they shared.</p>
            <div class="tile" id="tile">
                <video id="kitty" playsinline muted preload="auto" src="/demo/friend_moment.mp4"></video>
                {{-- Framing first, action second: you read how to hold the
                     phone, then the thing you are about to tap. --}}
                <div class="seal" id="seal">
                    <div class="hold">Keep your phone at face level, like a video call.</div>
                    <div class="tap">Tap to open</div>
                </div>
                <svg class="timer" id="timer" viewBox="0 0 36 36" aria-hidden="true">
                    <circle class="track" cx="18" cy="18" r="15"></circle>
                    <circle class="run" cx="18" cy="18" r="15"></circle>
                </svg>
            </div>
        </section>

        {{-- Page 4 — reveal: VARIANT B shows the media AND the reaction below it. --}}
        <section class="page" id="p-reveal">
            <div class="badge">That was you</div>
            <h1>Your <span class="hl">real</span> reaction.<br>That’s Reacti.</h1>
            <div class="pair">
                <div class="pair-cap">the Reacti</div>
                <video class="pair-vid" id="revealMedia" playsinline autoplay loop muted src="/demo/friend_moment.mp4"></video>
                <div class="pair-cap">your reaction</div>
                <video class="pair-vid mine" id="playback" playsinline autoplay loop muted></video>
            </div>
            {{-- Apple mark only: there is no Android build yet, so a Play badge
                 would link nowhere. Add it here when Android ships. --}}
            <a class="btn store" id="store-cta" href="https://apps.apple.com/app/id6755814897">
                <svg viewBox="0 0 384 512" width="19" height="19" aria-hidden="true"><path fill="currentColor" d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z"/></svg>
                Get the Reacti app
            </a>
            <div class="store-note">Free on the App Store</div>
        </section>
    </div>

    {{-- Skip confirm --}}
    <div class="modal-wrap" id="skip-modal">
        <div class="modal">
            <div class="emoji">🥺</div>
            <h2>Wait — sure you want to skip?</h2>
            <p style="margin:0 auto;">Reacti is way more fun than it sounds. It’s cool, promise!</p>
            <div class="row">
                <button class="btn" id="keep">Okay, show me ▶</button>
                <button class="btn ghost" id="really-skip">Skip anyway</button>
            </div>
        </div>
    </div>

    <script>
        (function () {
            // Reports a step of the invite loop to our own backend. No
            // third-party script, no cookie, no consent banner: this page is
            // public and anonymous, and the people seeing it have not installed
            // anything yet.
            //
            // keepalive so the store tap still reports as the browser leaves.
            var code = @json($code);
            var token = document.querySelector('meta[name="csrf-token"]');
            function reportStep(step) {
                try {
                    fetch('/i/' + encodeURIComponent(code) + '/step/' + step, {
                        method: 'POST',
                        keepalive: true,
                        headers: token
                            ? { 'X-CSRF-TOKEN': token.getAttribute('content') }
                            : {},
                    }).catch(function () { /* Never block the demo. */ });
                } catch (e) { /* Never block the demo. */ }
            }

            // If this page is rendering at all, the link was NOT swallowed by
            // the installed app, so stamp the URL as web-handled. The AASA
            // excludes `/i/*?web=1`, which stops a reload from handing the link
            // back to iOS. An in-app browser (WhatsApp's above all) reloads on
            // every return, and without this the app opened, closed and
            // reopened until the phone was unusable.
            //
            // replaceState, not assign: no second request, no history entry, so
            // Back still leaves the way it came.
            try {
                if (window.history && history.replaceState
                    && window.location.search.indexOf('web=1') === -1) {
                    var sep = window.location.search ? '&' : '?';
                    history.replaceState(null, '',
                        window.location.pathname + window.location.search + sep + 'web=1');
                }
            } catch (e) { /* Cosmetic guard only — never block the demo. */ }

            var pages = { intro: 'p-intro', perm: 'p-perm', demo: 'p-demo', reveal: 'p-reveal' };
            var stream = null, recorder = null, chunks = [], recorded = null;
            var RECORD_MS = 4500;

            // Reported once, from show(): the reveal is reached by four
            // different paths (finished, skipped, no camera, camera refused)
            // and instrumenting each would miss one and double-count another.
            var reportedReveal = false;
            function show(key) {
                if (key === 'reveal' && !reportedReveal) {
                    reportedReveal = true;
                    reportStep('demo_completed');
                }
                document.querySelectorAll('.page').forEach(function (p) { p.classList.remove('active'); });
                document.getElementById(pages[key]).classList.add('active');
            }
            function stopStream() {
                if (stream) { stream.getTracks().forEach(function (t) { t.stop(); }); stream = null; }
            }

            // --- Skip flow (available on every step) ---
            var modal = document.getElementById('skip-modal');
            function openSkip() { modal.classList.add('show'); }
            document.querySelectorAll('[data-skip]').forEach(function (b) {
                b.addEventListener('click', openSkip);
            });
            document.getElementById('keep').addEventListener('click', function () { modal.classList.remove('show'); });
            // The last thing measurable before Apple takes over. The install
            // itself only becomes visible again if the account connects.
            var storeCta = document.getElementById('store-cta');
            if (storeCta) {
                storeCta.addEventListener('click', function () {
                    reportStep('store_clicked');
                });
            }

            document.getElementById('really-skip').addEventListener('click', function () {
                modal.classList.remove('show');
                stopStream();
                show('reveal');
            });

            // --- Page 1 → permission ---
            document.getElementById('go-perm').addEventListener('click', function () { show('perm'); });

            // --- Page 2: grant camera + mic, then the demo ---
            document.getElementById('grant').addEventListener('click', async function () {
                if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                    show('reveal');
                    return;
                }
                try {
                    stream = await navigator.mediaDevices.getUserMedia({
                        video: { facingMode: 'user' }, audio: true
                    });
                    show('demo');
                } catch (e) {
                    show('reveal');
                }
            });

            // --- Page 3: open the sealed Reacti → play kitty + record you ---
            var tile = document.getElementById('tile');
            var seal = document.getElementById('seal');
            var kitty = document.getElementById('kitty');
            var opened = false;

            function fitAspect(video, el) {
                if (video.videoWidth && video.videoHeight) {
                    el.style.aspectRatio = video.videoWidth + ' / ' + video.videoHeight;
                }
            }
            kitty.addEventListener('loadedmetadata', function () { fitAspect(kitty, tile); });
            if (kitty.readyState >= 1) fitAspect(kitty, tile);

            seal.addEventListener('click', function () {
                if (opened) return;
                opened = true;
                // Keep the ring honest: it empties exactly when recording stops.
                var ring = document.querySelector('#timer .run');
                if (ring) ring.style.animationDuration = RECORD_MS + 'ms';
                tile.classList.add('open');
                try { kitty.play(); } catch (e) {}
                startRecording();
            });

            function pickMime() {
                var opts = ['video/mp4', 'video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm'];
                for (var i = 0; i < opts.length; i++) {
                    if (window.MediaRecorder && MediaRecorder.isTypeSupported(opts[i])) return opts[i];
                }
                return '';
            }

            function startRecording() {
                if (!stream || !window.MediaRecorder) { setTimeout(finishDemo, RECORD_MS); return; }
                chunks = [];
                try {
                    var mime = pickMime();
                    recorder = mime ? new MediaRecorder(stream, { mimeType: mime }) : new MediaRecorder(stream);
                } catch (e) { setTimeout(finishDemo, RECORD_MS); return; }

                recorder.ondataavailable = function (ev) { if (ev.data && ev.data.size) chunks.push(ev.data); };
                recorder.onstop = function () {
                    if (chunks.length) recorded = new Blob(chunks, { type: chunks[0].type || 'video/mp4' });
                    finishDemo();
                };
                recorder.start();
                setTimeout(function () { if (recorder && recorder.state !== 'inactive') recorder.stop(); }, RECORD_MS);
            }

            function finishDemo() {
                // VARIANT B: play the media alongside the reaction on the reveal.
                var media = document.getElementById('revealMedia');
                media.addEventListener('loadedmetadata', function () { fitAspect(media, media); });
                if (media.readyState >= 1) fitAspect(media, media);
                try { media.play(); } catch (e) {}

                var pb = document.getElementById('playback');
                pb.addEventListener('loadedmetadata', function () { fitAspect(pb, pb); });
                if (recorded) {
                    pb.srcObject = null;
                    pb.src = URL.createObjectURL(recorded);
                    pb.muted = true;
                } else if (stream) {
                    pb.srcObject = stream;
                }
                show('reveal');
                stopKittyLater();
            }
            function stopKittyLater() {
                if (recorded) stopStream();
            }
        })();
    </script>
</body>
</html>
