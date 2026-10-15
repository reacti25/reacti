{{--
    Account deletion page required by Google Play (Data safety: "a link that
    users can use to request that their account and associated data is
    deleted"). Google requires it to name the app or developer, show the steps
    plainly, and say what is deleted, what is kept and for how long.

    The promises here (media files deleted with the account) are true once the
    media-deletion fix (PR #475) is live; ship both in the same release.
--}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Delete your Reacti account</title>
    <style>
        body { margin: 0; background: #f7f8fa; color: #222; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; }
        main { max-width: 720px; margin: 32px auto; padding: 28px 32px; background: #fff; border-radius: 12px; box-shadow: 0 3px 12px rgba(0, 0, 0, .08); }
        h1 { font-size: 26px; margin: 0 0 4px; }
        h2 { font-size: 19px; margin: 28px 0 8px; }
        .muted { color: #666; margin: 0 0 20px; }
        ol, ul { padding-left: 22px; }
        li { margin: 4px 0; }
        a { color: #4a6200; }
        @media (max-width: 600px) { main { margin: 0; border-radius: 0; padding: 22px 18px; } }
    </style>
</head>
<body>
<main>
    <h1>Delete your Reacti account</h1>
    <p class="muted">Reacti, by Achia Rosin</p>

    <h2>Delete it in the app (fastest)</h2>
    <ol>
        <li>Open Reacti and sign in.</li>
        <li>Tap <strong>Profile</strong>, then <strong>Settings</strong>.</li>
        <li>Tap <strong>Delete Account</strong> and confirm.</li>
    </ol>
    <p>Your account is deleted immediately.</p>

    <h2>Or ask us by email</h2>
    <p>
        If you can't use the app, email
        <a href="mailto:reacti.ai25@gmail.com?subject=Delete%20my%20account">reacti.ai25@gmail.com</a>
        from the email address on your account, with the subject
        <strong>"Delete my account"</strong>. We will confirm and complete the
        deletion within 30 days.
    </p>

    <h2>What is deleted</h2>
    <ul>
        <li>Your account and profile: name, username, email, phone number, date of birth, profile and cover photos.</li>
        <li>Your messages, sent and received, including the photos, videos and reaction videos in them.</li>
        <li>Groups you created, with their messages and media.</li>
        <li>Your friend connections, friend requests and blocks.</li>
    </ul>

    <h2>What is kept, and for how long</h2>
    <ul>
        <li>Copies in our server backups are removed within 30 days, as backups are replaced.</li>
        <li>Usage and crash statistics are linked only to a pseudonymous identifier, not your name or email, and age out under our analytics providers' retention periods.</li>
    </ul>

    <p class="muted">More details: <a href="/privacy-policy">Privacy policy</a></p>
</main>
</body>
</html>
