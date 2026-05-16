<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * Mailable that delivers an OTP during user registration.
 *
 * Sent right after sign-up to verify the new account's email address.
 * Renders the `mail.verifyEmail` view with the OTP and the user's full
 * name. The `$otpExpiresAt` property is declared but currently unused.
 */
class RegisterOtpMail extends Mailable
{
    use Queueable, SerializesModels;

    /** @var mixed The one-time verification code, the recipient's full name, and an (unused) expiry timestamp. */
    public $otp , $fullName, $otpExpiresAt;

    /**
     * Create a new message instance.
     *
     * @param  mixed  $otp       The verification code to send.
     * @param  mixed  $fullName  Recipient's full name, used in the email body.
     */
    public function __construct($otp , $fullName)
    {
       $this->otp = $otp;
       $this->fullName = $fullName;
    }

    /**
     * Build the message.
     *
     * Sets the subject and renders the `mail.verifyEmail` view with the
     * OTP and full name.
     *
     * @return $this
     */
    public function build()
    {
        return $this->subject('Your OTP for Email Verification')
                    ->view('mail.verifyEmail')
                    ->with(['otp' => $this->otp , 'fullName' => $this->fullName]);
    }
}
