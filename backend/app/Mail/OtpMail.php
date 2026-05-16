<?php

namespace App\Mail;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Attachment;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * Mailable that delivers a password-reset OTP to a user.
 *
 * Sent during the forgot-password flow. Renders the
 * `emails.passResetOtp` view; the `$otp` and `$user` public properties
 * are exposed directly to that view.
 */
class OtpMail extends Mailable
{
    use Queueable, SerializesModels;

    /** @var int The one-time password-reset code. */
    public int $otp;

    /** @var User The user requesting the password reset. */
    public User $user;

    /**
     * Create a new message instance.
     *
     * @param  int   $otp   The reset code to send.
     * @param  User  $user  The user the OTP belongs to.
     */
    public function __construct(int $otp, User $user)
    {
        $this->otp = $otp;
        $this->user = $user;
    }

    /**
     * Get the message envelope.
     *
     * @return Envelope
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Password Reset OTP',
        );
    }

    /**
     * Get the message content definition.
     *
     * The OTP and user are passed implicitly via the mailable's public
     * properties rather than an explicit `with` array.
     *
     * @return Content
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.passResetOtp',
        );
    }

    /**
     * Get the attachments for the message.
     *
     * No attachments are sent with the reset email.
     *
     * @return array<int, \Illuminate\Mail\Mailables\Attachment>
     */
    public function attachments(): array
    {
        return [];
    }
}
