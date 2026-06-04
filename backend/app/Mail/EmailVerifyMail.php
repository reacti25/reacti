<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Attachment;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * Mailable that delivers an email-verification OTP to a user.
 *
 * Sent during sign-up / email-verification flows. Renders the
 * `emails.otpmail` view with the one-time code and a fixed 5-minute
 * expiry notice. Tagged and given metadata for deliverability tracking
 * and anti-spam classification.
 */
class EmailVerifyMail extends Mailable
{
    use Queueable, SerializesModels;

    /** @var int The one-time verification code. */
    public int $otp;

    /** @var string Display name of the recipient, used in the email body. */
    public string $userName;

    /** @var string Subject line / header message for the email. */
    public string $headerMessage;

    /**
     * Create a new message instance.
     *
     * @param  int  $otp  The verification code to send.
     * @param  string  $userName  Recipient display name.
     * @param  string  $message  Subject/header text for the email.
     */
    public function __construct(int $otp, string $userName, string $message)
    {
        $this->otp = $otp;
        $this->userName = $userName;
        $this->headerMessage = $message;

        // Queue configuration
        // $this->onQueue('emails'); // Separate queue for emails
        // $this->afterCommit(); // Send after database transaction commits
    }

    /**
     * Get the message envelope.
     *
     * Adds `tags` and `metadata` to help mail providers classify the
     * message and to support deliverability analytics.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            // from: new Address(config('mail.from.address'), config('mail.from.name')),
            subject: $this->headerMessage,
            // Anti-spam headers
            tags: ['verification', 'otp'],
            metadata: [
                'type' => 'email_verification',
            ],
        );
    }

    /**
     * Get the message content definition.
     *
     * Binds the OTP, user name, a fixed 5-minute expiry and the app name
     * into the `emails.otpmail` Blade view.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.otpmail',
            // text: 'emails.otpmail-text', // Plain text version for better deliverability
            with: [
                'otp' => $this->otp,
                'userName' => $this->userName,
                'expiryMinutes' => 5,
                'appName' => config('app.name'),
            ],
        );
    }

    /**
     * Get the attachments for the message.
     *
     * No attachments are sent with the verification email.
     *
     * @return array<int, Attachment>
     */
    public function attachments(): array
    {
        return [];
    }
}
