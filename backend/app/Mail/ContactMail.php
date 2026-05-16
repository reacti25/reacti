<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

/**
 * Mailable for "Contact Us" form submissions.
 *
 * Sent to the site/support inbox whenever a visitor submits the public
 * contact form. Renders the `emails.contact` view with the raw submitted
 * fields so the team can read and respond to the enquiry.
 */
class ContactMail extends Mailable
{
    use SerializesModels;

    /** @var array Submitted contact-form fields (name, email, message, etc.). */
    public $contactData;

    /**
     * Create a new message instance.
     *
     * @param  array  $contactData  Submitted contact-form fields.
     * @return void
     */
    public function __construct($contactData)
    {
        $this->contactData = $contactData;
    }

    /**
     * Build the message.
     *
     * Sets the subject and renders the `emails.contact` view with the
     * submitted form data.
     *
     * @return $this
     */
    public function build()
    {
        return $this->subject('New Contact Message')
            ->view('emails.contact')
            ->with('contactData', $this->contactData);
    }
}
