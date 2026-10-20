@include('emails.partials.code', [
    'title' => 'Your Reacti code',
    'greeting' => 'Hi ' . $userName . ',',
    'intro' => 'Here is your code to finish signing up to Reacti:',
    'code' => $otp,
    'minutes' => $expiryMinutes,
    'ignore' => 'Didn\'t try to sign up? You can ignore this email.',
])
