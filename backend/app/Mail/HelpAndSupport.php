<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * Mailable for "Help & Support" requests submitted by users.
 *
 * Sent to the support inbox when a user submits a help/support request.
 * Renders the `emails.helpandsupport` view with the submitted details.
 *
 * Note: an {@see Envelope()} method is defined but the queued send path
 * ultimately goes through {@see build()}, which sets its own subject.
 */
class HelpAndSupport extends Mailable
{
    use Queueable, SerializesModels;

    /** @var array Submitted help/support request fields. */
    public $helpandSupportData;

    /**
     * Create a new message instance.
     *
     * @param  array  $helpandSupportData  Submitted help/support fields.
     */
    public function __construct($helpandSupportData)
    {
        $this->helpandSupportData = $helpandSupportData;
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Help And Support',
        );
    }

    /**
     * Build the message.
     *
     * Sets the subject and renders the `emails.helpandsupport` view with
     * the submitted request data.
     *
     * @return $this
     */
    public function build()
    {
        return $this->subject('New Contact Message')
            ->view('emails.helpandsupport')
            ->with('helpandSupportData', $this->helpandSupportData);
    }
}
