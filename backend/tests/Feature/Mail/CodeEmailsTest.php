<?php

namespace Tests\Feature\Mail;

use App\Mail\EmailVerifyMail;
use App\Mail\OtpMail;
use App\Models\User;
use Tests\TestCase;

class CodeEmailsTest extends TestCase
{
    public function test_sign_up_code_email_is_reacti_branded(): void
    {
        $mail = new EmailVerifyMail(4821, 'Dana', 'Your Reacti sign-up code');

        $mail->assertHasSubject('Your Reacti sign-up code');
        $mail->assertSeeInHtml('4821');
        $mail->assertSeeInHtml('Hi Dana,');
        $mail->assertSeeInHtml('email/reacti-icon.png');
        $mail->assertDontSeeInHtml('AchireExpert');
    }

    public function test_password_reset_email_is_reacti_branded(): void
    {
        $mail = new OtpMail(7356, new User(['name' => 'Dana']));

        $mail->assertHasSubject('Your Reacti password reset code');
        $mail->assertSeeInHtml('7356');
        $mail->assertSeeInHtml('reset your Reacti password');
        $mail->assertDontSeeInHtml('Ownhustle');
    }
}
