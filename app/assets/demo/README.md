# Demo Reacti asset

`friend_moment.jpg` is the canned "friend's moment" the practice demo opens
(Feature 2).

**Current asset:** a real **CC0** kitten photo — "A focused kitten (Pixabay)"
by Ty Swartz, via Wikimedia Commons
(<https://commons.wikimedia.org/wiki/File:A_focused_kitten_(Pixabay).jpg>).
CC0 = public-domain dedication, so it's cleared for commercial App Store use
with no attribution required (credited here only for provenance).

**To change it:** drop a new short (~3–6s) portrait, small (<~2 MB) image or
video here and point `DemoReactiScreen.friendMediaAsset` at it. Keep any
replacement CC0/royalty-free (Pexels, Pixabay, Wikimedia PD) since this ships
in the App Store build. For a **video**, also swap `Image.asset` for a
`video_player` in `demo_reacti_screen.dart` (the still image is enough for v1).
