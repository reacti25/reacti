@include('emails.partials.code', [
    'title' => 'Reset your Reacti password',
    'greeting' => 'Hi ' . ($user->name ?? 'there') . ',',
    'intro' => 'Here is your code to reset your Reacti password:',
    'code' => $otp,
    'minutes' => 5,
    'ignore' => 'Didn\'t ask to reset your password? You can ignore this email, and your password stays the same.',
])
