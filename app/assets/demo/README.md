# Demo Reacti asset

`friend_moment.mp4` is the looping "friend's moment" the practice demo opens
(Feature 2). It plays muted behind the capture + reveal.

**Current clip:** a short public-domain kitten video, trimmed + transcoded from
"A male cat grooms a female kitten" on Wikimedia Commons
(<https://commons.wikimedia.org/wiki/File:A_male_cat_grooms_a_female_kitten_2021-08-25_August_25.webm>),
which is released into the **public domain** — cleared for commercial App Store
use, no attribution required (credited here only for provenance).

**To change it:** just drop a new video at this exact path
(`assets/demo/friend_moment.mp4`) — **no code change**. Requirements:
- **H.264 MP4** (iOS won't play webm/ogv). Transcode if needed, e.g.
  `ffmpeg -i in.mov -c:v libx264 -profile:v baseline -pix_fmt yuv420p -movflags +faststart -an out.mp4`
- Short (~4–6s), small (keep it well under ~2 MB — it ships inside the app).
- Keep it CC0/royalty-free (Pexels, Pixabay, Wikimedia PD).
