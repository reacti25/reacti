{{-- Shared layout for the code emails (sign-up and password reset). Tables and inline
     styles only, because email clients ignore most CSS. Colours are Reacti's: ink #16190F, lime #DCFC53. --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="color-scheme" content="light only">
    <title>{{ $title }}</title>
</head>
<body style="margin:0;padding:0;background:#F4F6EE;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#16190F;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6EE;">
    <tr><td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#FFFFFF;border-radius:20px;overflow:hidden;">
            <tr><td align="center" style="background:#16190F;padding:28px 24px;">
                <img src="{{ asset('email/reacti-icon.png') }}" width="64" height="64" alt="Reacti" style="display:block;border-radius:16px;">
                <div style="margin-top:12px;font-size:22px;font-weight:700;color:#FFFFFF;letter-spacing:.3px;">Reacti</div>
            </td></tr>
            <tr><td style="padding:32px 28px 8px;">
                <p style="margin:0 0 12px;font-size:17px;font-weight:600;">{{ $greeting }}</p>
                <p style="margin:0 0 24px;font-size:15px;line-height:1.5;color:#3D4233;">{{ $intro }}</p>
                <div style="background:#DCFC53;border-radius:16px;padding:22px 12px;text-align:center;">
                    <div style="font-size:38px;font-weight:800;letter-spacing:10px;color:#16190F;font-family:'SF Mono',Menlo,Consolas,monospace;">{{ $code }}</div>
                    <div style="margin-top:6px;font-size:13px;color:#3D4233;">Expires in {{ $minutes }} minutes</div>
                </div>
                <p style="margin:24px 0 8px;font-size:14px;line-height:1.5;color:#3D4233;">Never share this code with anyone. Reacti will never ask you for it.</p>
                <p style="margin:0 0 24px;font-size:14px;line-height:1.5;color:#6B7060;">{{ $ignore }}</p>
            </td></tr>
            <tr><td align="center" style="padding:18px 24px 26px;border-top:1px solid #ECEDE8;font-size:12px;line-height:1.6;color:#8A8F7E;">
                Sent by Reacti &middot; <a href="https://reacti.io" style="color:#8A8F7E;">reacti.io</a><br>
                This is an automated email, please don't reply.
            </td></tr>
        </table>
    </td></tr>
</table>
</body>
</html>
