<!DOCTYPE html>
<html lang="en">
{{-- VARIANT B of the invite web demo (A/B test). Identical to invite.blade.php
     EXCEPT the reveal shows the media on top with the viewer's reaction below
     it (variant A shows the reaction alone). Served at /ib/{code}. Keep the two
     files in sync for everything except the reveal section + its .pair styles. --}}
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>{{ $inviter ? $inviter->first_name . ' invited you to Reacti' : 'You’re invited to Reacti' }}</title>
    <style>
        :root {
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
            background:
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
        .btn.store { display: inline-flex; align-items: center; gap: 8px; text-decoration: none; }

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
        .seal .tap { font-size: 40px; animation: nudge 1.4s ease-in-out infinite; }
        @keyframes nudge { 0%,100% { transform: translateY(0); } 50% { transform: translateY(8px); } }
        .tile.open .seal { opacity: 0; pointer-events: none; }

        /* Reveal — VARIANT B: media on top, the viewer's reaction below it. */
        .pair { display: flex; flex-direction: column; gap: 10px; align-items: center; width: 100%; }
        .pair-cap { font-size: 11px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--muted); }
        .pair-vid {
            width: min(60vw, 240px); aspect-ratio: 3/4; max-height: 30vh;
            border-radius: 18px; object-fit: cover; background: #000;
            border: 1px solid #2b3115; box-shadow: 0 12px 28px rgba(0,0,0,.5);
        }
        .pair-vid.mine { border: 2px solid var(--lime); transform: scaleX(-1); }

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
            <button class="btn ghost" data-skip>Maybe later</button>
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
            <div class="tile" id="tile">
                <video id="kitty" playsinline muted preload="auto" src="/demo/friend_moment.mp4"></video>
                <div class="seal" id="seal">
                    <div class="tap">👆</div>
                    <div>Tap to open</div>
                </div>
            </div>
        </section>

        {{-- Page 4 — reveal: VARIANT B shows the media AND the reaction below it. --}}
        <section class="page" id="p-reveal">
            <div class="badge">That was you</div>
            <h1>Your <span class="hl">real</span> reaction — that’s Reacti.</h1>
            <div class="pair">
                <div class="pair-cap">the Reacti</div>
                <video class="pair-vid" id="revealMedia" playsinline autoplay loop muted src="/demo/friend_moment.mp4"></video>
                <div class="pair-cap">your reaction</div>
                <video class="pair-vid mine" id="playback" playsinline autoplay loop muted></video>
            </div>
            <a class="btn store" href="https://apps.apple.com/app/id6755814897">⬇ Get Reacti</a>
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
            var pages = { intro: 'p-intro', perm: 'p-perm', demo: 'p-demo', reveal: 'p-reveal' };
            var stream = null, recorder = null, chunks = [], recorded = null;
            var RECORD_MS = 4500;

            function show(key) {
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
