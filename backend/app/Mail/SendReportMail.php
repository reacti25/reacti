<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Queue\SerializesModels;

/**
 * Mailable that delivers a user report to the moderation/support inbox.
 *
 * Sent when a user reports another user or piece of content. Renders the
 * `report.index` view with the report details so moderators can review
 * and act on it.
 */
class SendReportMail extends Mailable
{
    use Queueable, SerializesModels;

    /** @var mixed The report data being delivered to moderators. */
    public $report;

    /**
     * Create a new message instance.
     *
     * @param  mixed  $report  The report details to email.
     */
    public function __construct($report)
    {
        $this->report = $report;
    }

    /**
     * Build the message.
     *
     * Sets the subject and renders the `report.index` view with the
     * report data.
     *
     * @return $this
     */
    public function build()
    {
        return $this->subject('New report Message')
            ->view('report.index')
            ->with('report', $this->report);
    }
}
