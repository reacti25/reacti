import 'package:reacti_app/constants/text_font_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// Screen that displays the app's Terms & Conditions.
///
/// Renders the terms HTML inside a scrollable [HtmlWidget]. Unlike the privacy
/// screen, the content here is currently static.
class TermsScreen extends StatefulWidget {
  /// Creates the Terms & Conditions screen.
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

/// State for [TermsScreen]; holds the terms HTML and builds the view.
class _TermsScreenState extends State<TermsScreen> {
  /// The Terms & Conditions body as a static HTML string.
  var text =
      "<h3><strong>1. Information We Collect</strong></h3><p>We collect the following types of information:</p><ul><li><strong>Personal Information:</strong> Name, email address, phone number, Singpass/Apple ID/Google/Facebook login details, and payment information.</li><li><strong>Usage Data:</strong> Information about how you use the Platform, including IP address, device type, and browsing behavior.</li><li>&nbsp;</li></ul><h3><strong>1.1 How We Use Your Information</strong></h3><p>We use your information to:</p><ul><li>Provide, maintain, and improve the Platform.</li><li>Process transactions and send transaction notifications.</li><li>Verify user identity and prevent fraud.</li><li>Communicate with you about updates, promotions, and customer support.</li><li>&nbsp;</li></ul><h3><strong>1.2 &nbsp;Sharing Your Information</strong></h3><p>We do not sell your personal information. We may share your information with:</p><ul><li><strong>Service Providers:</strong> Third-party vendors who assist us in operating the Platform (e.g., Stripe for payment processing).</li><li><strong>Legal Authorities:</strong> When required by law or to protect our rights and safety.</li><li>&nbsp;</li></ul><h3><strong>1.3 &nbsp;Data Security</strong></h3><p>We implement industry-standard security measures to protect your information. However, no method of transmission over the internet or electronic storage is 100% secure.</p><h3><strong>1.4 Your Rights</strong></h3><p>You have the right to:</p><ul><li>Access, update, or delete your personal information.</li><li>Opt-out of marketing communications.</li><li>Withdraw consent for data processing (where applicable).</li></ul><h3>&nbsp;</h3><h3><strong>1.5 Cookies and Tracking</strong></h3><p>We use cookies and similar technologies to enhance your experience on the Platform. You can disable cookies in your browser settings, but this may affect Platform functionality.</p><h3><strong>1.6 Children’s Privacy</strong></h3><p>The Platform is not intended for users under the age of 18. We do not knowingly collect personal information from children.</p><p>&nbsp;</p><h2><strong>2. Contact Us</strong></h2><p>If you have any questions about these Terms or our Privacy Policy, please contact us at:</p><p>Support@culturecloset.site</p><p>&nbsp;</p>";

  /// Builds the scaffold: an app bar and the scrollable rendered terms HTML.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Terms & Conditions",
          style: TextFontStyle.headline16w500CF7F7F7Poppins,
        ),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: HtmlWidget(
          // response.data?[0].pageContent ?? 'No description',
          text,
          textStyle: TextFontStyle.headline16w400CFFFFFFPoppins.copyWith(
            fontSize: 14.sp,
          ),
          customStylesBuilder: (element) {
            if (element.classes.contains('highlight')) {
              return {'color': 'blue'};
            }
            return null;
          },
          customWidgetBuilder: (element) {
            if (element.attributes['foo'] == 'bar') {
              // Render a custom widget if needed
            }
            return null;
          },
          renderMode: RenderMode.column,
        ),
      ),
    );
  }
}
