<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $inviter ? $inviter->first_name . ' invited you to Reacti' : 'You’re invited to Reacti' }}</title>
    <style>
        :root { color-scheme: light dark; }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: #0f1005;
            color: #f4f6ea;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .card {
            width: 100%;
            max-width: 420px;
            background: #171a0b;
            border: 1px solid #2b3115;
            border-radius: 20px;
            padding: 32px 24px;
            text-align: center;
        }
        .badge {
            display: inline-block;
            font-size: 12px;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            color: #c7f24a;
            margin-bottom: 16px;
        }
        h1 { font-size: 24px; margin: 0 0 8px; }
        p { color: #b9bfa6; line-height: 1.5; margin: 8px 0; }
        .code {
            display: inline-block;
            margin: 20px 0 8px;
            padding: 12px 18px;
            font-size: 20px;
            font-weight: 700;
            letter-spacing: 2px;
            color: #0f1005;
            background: #c7f24a;
            border-radius: 12px;
            user-select: all;
        }
        ol { text-align: left; color: #b9bfa6; line-height: 1.6; padding-left: 20px; }
        ol b { color: #f4f6ea; }
        .foot { font-size: 12px; color: #7c8168; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">Reacti</div>
        <h1>{{ $inviter ? $inviter->first_name . ' invited you to Reacti' : 'You’re invited to Reacti' }}</h1>
        <p>Send photos and videos and see each other’s genuine first reactions.</p>

        <div class="code">{{ $code }}</div>
        <p style="margin-top:0;font-size:13px;">your invite code</p>

        <ol>
            <li>Open the <b>Reacti</b> app.</li>
            <li>Go to <b>Profile → Connect with an inviter</b>.</li>
            <li>Enter the code above (or paste this link) and tap <b>Connect</b>.</li>
        </ol>

        <p class="foot">Don’t have Reacti yet? It’s currently in invite-only testing.</p>
    </div>
</body>
</html>
