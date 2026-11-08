import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languagePreferenceKey = 'app_language';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

Future<void> loadSavedAppLanguage() async {
  final preferences = await SharedPreferences.getInstance();
  final languageCode = preferences.getString(_languagePreferenceKey);
  if (languageCode == 'tl') {
    appLocale.value = const Locale('tl');
  }
}

Future<void> setAppLanguage(Locale locale) async {
  if (locale.languageCode != 'en' && locale.languageCode != 'tl') return;
  appLocale.value = locale;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_languagePreferenceKey, locale.languageCode);
}

String translate(BuildContext context, String text) {
  return translateText(
    text,
    languageCode: Localizations.localeOf(context).languageCode,
  );
}

String translateText(String text, {String? languageCode}) {
  if ((languageCode ?? appLocale.value.languageCode) == 'tl') {
    return _tagalogTranslations[text] ?? text;
  }
  return _englishTranslations[text] ?? text;
}

const _tagalogTranslations = <String, String>{
  'Language': 'Wika',
  'English': 'Ingles',
  'Tagalog': 'Tagalog',
  'Home': 'Tahanan',
  'Requests': 'Mga Request',
  'Profile': 'Profile',
  'Alerts': 'Mga Abiso',
  'Notifications': 'Mga Abiso',
  'Dispatch': 'Dispatch',
  'PCR': 'PCR',
  'RESCUE 35': 'RESCUE 35',
  'Emergency Medical Response': 'Pagtugon sa Medical Emergency',
  'Request emergency medical transport anytime, anywhere.':
      'Humiling ng emergency medical transport anumang oras at saanman.',
  'OCR Patient Care Reporting':
      'Pag-uulat ng Pangangalaga sa Pasyente gamit ang OCR',
  'Convert paper reports into digital records instantly using OCR.':
      'Gawing digital record agad ang mga papel na ulat gamit ang OCR.',
  'Real-Time Notifications': 'Mga Abiso sa Real-Time',
  'Smart Emergency Management': 'Matalinong Pamamahala ng Emergency',
  'Manage ambulances, schedules, and patient records efficiently.':
      'Mahusay na pamahalaan ang mga ambulansya, iskedyul, at tala ng pasyente.',
  'Live': 'Live',
  'Smart': 'Matalino',
  'Official Emergency Medical Transport Platform':
      'Opisyal na Plataporma para sa Medical Transport sa Emergency',
  'Sign in to continue': 'Mag-sign in upang magpatuloy',
  'Create your account': 'Gumawa ng iyong account',
  'Complete the steps below for MDRRMO verification.':
      'Kumpletuhin ang mga hakbang sa ibaba para sa beripikasyon ng MDRRMO.',
  'Create Account': 'Gumawa ng Account',
  'Citizen Registration': 'Pagpaparehistro ng Mamamayan',
  "Don't have an account? ": 'Wala ka pang account? ',
  'Too many failed attempts. Try again after the cooldown.':
      'Masyadong maraming bigong pagtatangka. Subukan muli pagkatapos ng ilang sandali.',
  'Reset link sent. Check your inbox or spam/junk folder.':
      'Naipadala na ang link. Tingnan ang iyong inbox o spam/junk folder.',
  'Tip: the reset email often lands in Spam/Junk — check there if it doesn\'t appear in your inbox.':
      'Tip: maaaring mapunta sa Spam/Junk ang email para i-reset ang password. Tingnan ito kung wala sa inbox.',
  'Faster Response. Better Care. Smarter Emergency Management.':
      'Mas Mabilis na Pagtugon. Mas Maayos na Pangangalaga. Mas Matalinong Pamamahala sa Emergency.',
  'Get Started': 'Magsimula',
  'Next': 'Susunod',
  'Skip': 'Laktawan',
  'Back': 'Bumalik',
  'Continue': 'Magpatuloy',
  'Welcome to RESCUE 35': 'Maligayang pagdating sa RESCUE 35',
  'Stay updated with transport status and responder notifications.':
      'Subaybayan ang status ng transportasyon at mga abiso ng responder.',
  'Login': 'Mag-login',
  'Log In': 'Mag-login',
  'Register': 'Magparehistro',
  'Sign In': 'Mag-sign in',
  'Sign Up': 'Gumawa ng account',
  'Email': 'Email',
  'Email or mobile number': 'Email o numero ng cellphone',
  'Mobile number': 'Numero ng cellphone',
  'Password': 'Password',
  'Confirm Password': 'Kumpirmahin ang password',
  'Forgot Password': 'Nakalimutan ang password',
  'Remember me': 'Tandaan ako',
  'Cancel': 'Kanselahin',
  'Send Link': 'Ipadala ang link',
  'Name': 'Pangalan',
  'Full Name': 'Buong pangalan',
  'Contact Number': 'Numero ng contact',
  'Barangay': 'Barangay',
  'Address': 'Address',
  'Submit': 'Ipasa',
  'Save': 'I-save',
  'Done': 'Tapos na',
  'Close': 'Isara',
  'Search': 'Maghanap',
  'No requests yet': 'Wala pang request',
  'Your transport requests will show up here once you\nsubmit one.':
      'Lalabas dito ang iyong mga request para sa transportasyon kapag nakapagsumite ka na.',
  'Track the status of your transport requests':
      'Subaybayan ang status ng iyong mga request para sa transportasyon',
  'You’re all caught up': 'Wala ka nang bagong abiso',
  "You're all caught up": 'Wala ka nang bagong abiso',
  'Updates about requests will appear here.':
      'Lalabas dito ang mga update tungkol sa iyong mga request.',
  'Updates about your requests will appear here.':
      'Lalabas dito ang mga update tungkol sa iyong mga request.',
  'New transport request': 'Bagong request sa transportasyon',
  'A new request needs attention.':
      'May bagong request na nangangailangan ng aksyon.',
  'Request submitted': 'Naipasa ang request',
  'Your transport request was added to the Alerts list.':
      'Naidagdag na sa listahan ng mga abiso ang iyong request.',
  'Transport request update': 'Update sa request sa transportasyon',
  'Unable to load request alerts': 'Hindi ma-load ang mga abiso sa request',
  'Unable to load your account': 'Hindi ma-load ang iyong account',
  'Please check your connection and try again.':
      'Pakisuri ang iyong koneksyon at subukan muli.',
  'Notification history is unavailable. Showing current request alerts instead.':
      'Hindi available ang kasaysayan ng mga abiso. Ipinapakita muna ang kasalukuyang mga request.',
  'Something went wrong': 'Nagkaroon ng problema',
  'Unable to load requests right now.':
      'Hindi ma-load ang mga request sa ngayon.',
  'My Requests': 'Aking mga Request',
  'Request Medical Transport': 'Humiling ng Medical Transport',
  'Request Submitted': 'Naipasa ang Request',
  'Tracking Number': 'Numero ng Pagsubaybay',
  'Pickup Location': 'Lugar ng Pagsundo',
  'Select Pickup Location': 'Piliin ang Lugar ng Pagsundo',
  'Tap to Select Pickup Location':
      'Pindutin upang Piliin ang Lugar ng Pagsundo',
  'Select Pickup Time': 'Piliin ang Oras ng Pagsundo',
  'Edit Schedule': 'I-edit ang Iskedyul',
  'Select new pickup date': 'Piliin ang bagong petsa ng pagsundo',
  'Select new pickup time': 'Piliin ang bagong oras ng pagsundo',
  'This request is no longer available for schedule editing.':
      'Hindi na maaaring i-edit ang iskedyul ng request na ito.',
  'Schedule updated. Your request is pending review.':
      'Na-update ang iskedyul. Naghihintay na muling masuri ang iyong request.',
  'Destination Hospital': 'Ospital na Pupuntahan',
  'Patient Information': 'Impormasyon ng Pasyente',
  'Patient Name': 'Pangalan ng Pasyente',
  'Age': 'Edad',
  'Sex': 'Kasarian',
  'Description': 'Paglalarawan',
  'Additional Notes': 'Karagdagang Tala',
  'Start Emergency PCR': 'Simulan ang Emergency PCR',
  'Patient Care Report': 'Ulat sa Pangangalaga ng Pasyente',
  'Start an emergency PCR or select from dispatch':
      'Magsimula ng emergency PCR o pumili mula sa dispatch',
  'Your account is pending MDRRMO verification.':
      'Naghihintay pa ng beripikasyon ng MDRRMO ang iyong account.',
  'Call RESCUE 35 Hotline?': 'Tawagan ang RESCUE 35 Hotline?',
  'No hotline number has been configured by the admin yet.':
      'Wala pang itinakdang hotline number ang admin.',
  'Call': 'Tumawag',
  'Yes': 'Oo',
  'No': 'Hindi',
  'Profile updated successfully.': 'Matagumpay na na-update ang profile.',
  'Logout': 'Mag-logout',
  'Log Out': 'Mag-logout',
  'Log out?': 'Mag-logout?',
  'Are you sure you want to log out?':
      'Sigurado ka bang gusto mong mag-logout?',
  'Sign out': 'Mag-sign out',
  'Emergency Medical Transport Platform':
      'Plataporma para sa Medical Transport sa Emergency',
  'Terms & Privacy': 'Mga Tuntunin at Privacy',
  'Required for first launch': 'Kailangan sa unang paggamit',
  'I agree to the Terms and Conditions':
      'Sumasang-ayon ako sa Mga Tuntunin at Kundisyon',
  'I agree to the Privacy Policy': 'Sumasang-ayon ako sa Patakaran sa Privacy',
  'Accept and Continue': 'Tanggapin at Magpatuloy',
  'Data Privacy Act of 2012 and user consent':
      'Data Privacy Act of 2012 at pahintulot ng user',
  'OCR consent for patient care report processing':
      'Pahintulot sa pagproseso ng ulat ng pasyente gamit ang OCR',
  'Emergency medical transport policy and LGU review':
      'Patakaran sa emergency medical transport at pagsusuri ng LGU',
  'False request penalties and misuse reporting':
      'Parusa sa maling request at pag-uulat ng maling paggamit',
  'Account verification before citizen transport requests':
      'Pagberipika ng account bago humiling ng transportasyon',
  'Dashboard': 'Dashboard',
  'Recent Requests': 'Mga Kamakailang Request',
  'Request Transport': 'Humiling ng Transportasyon',
  'Call RESCUE 35 Hotline': 'Tawagan ang RESCUE 35 Hotline',
  'See all': 'Tingnan lahat',
  'Pending': 'Nakabinbin',
  'Approved': 'Aprubado',
  'Completed': 'Nakumpleto',
  'Rejected': 'Tinanggihan',
  'En Route': 'Papunta na',
  'Contact': 'Contact',
  'Pickup Address': 'Address ng Pagsundo',
  'Assigned Dispatch': 'Itinalagang Dispatch',
  'Emergency PCR': 'Emergency PCR',
  'Scan PCR': 'I-scan ang PCR',
  'En Route — Dispatch accepted.': 'Papunta na — tinanggap ang dispatch.',
  'No active requests': 'Walang aktibong request',
  'Personal Information': 'Personal na Impormasyon',
  'Location Details': 'Mga Detalye ng Lokasyon',
  'Account Status': 'Status ng Account',
  'Email Address': 'Email Address',
  'Mobile Number': 'Numero ng Cellphone',
  'Account Role': 'Uri ng Account',
  'Municipality / City': 'Munisipalidad / Lungsod',
  'Province': 'Probinsya',
  'Current Status': 'Kasalukuyang Status',
  'Account verified': 'Beripikado ang account',
  'Verification in progress': 'Kasalukuyang bineberipika',
  '✅ Your account is verified and fully active.':
      '✅ Beripikado at aktibo na ang iyong account.',
  '⏳ Your account is still under review.': '⏳ Sinusuri pa ang iyong account.',
  'Save Changes': 'I-save ang mga Pagbabago',
  'Choose from Gallery': 'Pumili mula sa Gallery',
  'Take a Photo': 'Kumuha ng Larawan',
  'Take Photo': 'Kumuha ng Larawan',
  'Choose File': 'Pumili ng File',
  'Unable to save:': 'Hindi ma-save:',
  'No user is currently signed in.': 'Walang naka-sign in na user.',
  'Responder Information': 'Impormasyon ng Responder',
  'Responder Name': 'Pangalan ng Responder',
  'Patient & Ambulance': 'Pasyente at Ambulansya',
  'PCR Report Form': 'Form ng Ulat ng PCR',
  'Emergency PCR Report': 'Ulat ng Emergency PCR',
  'Use This Location': 'Gamitin ang Lokasyong Ito',
  'Tap to select on map': 'Pindutin upang pumili sa mapa',
  'Last name': 'Apelyido',
  'First name': 'Pangalan',
  'Pickup Date': 'Petsa ng Pagsundo',
  'Pickup Time': 'Oras ng Pagsundo',
  'Select Date': 'Pumili ng Petsa',
  'Hospital': 'Ospital',
  'Medical Concern': 'Medikal na Alalahanin',
  'Patient Details': 'Mga Detalye ng Pasyente',
  'Request Details': 'Mga Detalye ng Request',
  'Review your information': 'Suriin ang iyong impormasyon',
  'Personal Details': 'Personal na Detalye',
  'Residency Verification': 'Pagberipika ng Paninirahan',
  'Review & Submit': 'Suriin at Ipassa',
  'Verification Submitted': 'Naipasa ang Beripikasyon',
  'Your account is still under review.': 'Sinusuri pa ang iyong account.',
  'Account created successfully.': 'Matagumpay na nagawa ang account.',
  'Good morning,': 'Magandang umaga,',
  'Good afternoon,': 'Magandang hapon,',
  'Good evening,': 'Magandang gabi,',
  'Need Medical\nTransport?': 'Kailangan ng Medical\nTransport?',
  'Send a request and our team responds fast.':
      'Magpadala ng request at mabilis na tutugon ang aming team.',
  'Kulang ang profile mo sa account. Punan muna ito sa Profile settings bago mag-request.':
      'Your account profile is incomplete. Please complete it in Profile settings before making a request.',
  'Kulang ang profile mo. Pakikumpleto muna ito sa Profile settings.':
      'Your profile is incomplete. Please complete it in Profile settings first.',
  'Ito ang naka-save sa iyong account. I-edit sa Profile settings kung mali.':
      'This information is saved to your account. Edit it in Profile settings if it is incorrect.',
  'Select an available future date.':
      'Pumili ng available na petsa sa hinaharap.',
  'Select an available time slot.': 'Pumili ng available na oras.',
  'Your Profile Information': 'Impormasyon ng Iyong Profile',
  'Select Schedule Date': 'Pumili ng Petsa ng Iskedyul',
  'Past dates are not available for transport requests.':
      'Hindi maaaring pumili ng nakaraang petsa para sa request sa transportasyon.',
  'Tap to select a time': 'Pindutin upang pumili ng oras',
  'All pickup times are available.': 'Available ang lahat ng oras ng pagsundo.',
  'Submit Request': 'Ipasa ang Request',
  'Date': 'Petsa',
  'Time': 'Oras',
  'Patient': 'Pasyente',
  'Transport': 'Transportasyon',
  'Confirm': 'Kumpirmahin',
  'Phone Number': 'Numero ng Telepono',
  'Need Help?': 'Kailangan ng Tulong?',
  'Emergency': 'Emergency',
  'Caller': 'Tumatawag',
  'Dispatch accepted.': 'Tinanggap ang dispatch.',
  'Destination': 'Destinasyon',
  'Schedule': 'Iskedyul',
  'View All': 'Tingnan Lahat',
  'No active dispatches': 'Walang aktibong dispatch',
  'View details': 'Tingnan ang mga detalye',
  'Open Map': 'Buksan ang Mapa',
  'Medical Transport': 'Medical Transport',
  'This information is required.': 'Kinakailangan ang impormasyong ito.',
  'Select an option': 'Pumili ng opsyon',
  'Select Barangay': 'Pumili ng Barangay',
  'Upload Proof of Residency': 'Mag-upload ng Katibayan ng Paninirahan',
  'Proof of Residency': 'Katibayan ng Paninirahan',
  'Upload a clear photo of your proof of residency.':
      'Mag-upload ng malinaw na larawan ng iyong katibayan ng paninirahan.',
  'Last Name': 'Apelyido',
  'First Name': 'Pangalan',
  'Middle Initial': 'Gitnang Inisyal',
  'Password must be at least 6 characters.':
      'Dapat hindi bababa sa 6 na character ang password.',
  'Passwords do not match.': 'Hindi magkapareho ang mga password.',
  'Your requests': 'Iyong mga request',
  'Optional': 'Opsyonal',
  'Email is required': 'Kinakailangan ang email',
  'Enter a valid email address': 'Maglagay ng wastong email address',
  'Mobile number is required': 'Kinakailangan ang numero ng cellphone',
  'Use 09XXXXXXXXX format': 'Gamitin ang format na 09XXXXXXXXX',
  'Name is required': 'Kinakailangan ang pangalan',
  'Name must be at least 2 characters':
      'Dapat hindi bababa sa 2 character ang pangalan',
  'Name must not exceed 100 characters':
      'Hindi dapat lumampas sa 100 character ang pangalan',
  'Name can only contain letters, spaces, dots, and hyphens':
      'Mga letra, espasyo, tuldok, at gitling lamang ang maaaring gamitin sa pangalan',
  'Age is required': 'Kinakailangan ang edad',
  'Age must be a valid number': 'Maglagay ng wastong numero para sa edad',
  'Age must be between 0 and 150': 'Dapat nasa 0 hanggang 150 ang edad',
  'Phone number is required': 'Kinakailangan ang numero ng telepono',
  'Phone number too short': 'Masyadong maikli ang numero ng telepono',
  'Address is required': 'Kinakailangan ang address',
  'Address must be at least 5 characters':
      'Dapat hindi bababa sa 5 character ang address',
  'Address must not exceed 200 characters':
      'Hindi dapat lumampas sa 200 character ang address',
  'This field is required': 'Kinakailangan ang field na ito',
  'Enter a valid mobile number (e.g. 09123456789)':
      'Maglagay ng wastong numero ng cellphone (hal. 09123456789)',
  'Password is required': 'Kinakailangan ang password',
  'Please select a pickup location on the map.':
      'Pumili ng lugar ng pagsundo sa mapa.',
  'Request': 'Request',
  'Your transport request': 'Ang iyong request sa transportasyon',
  'is': 'ay',
  'is waiting for a responder.': 'ay naghihintay ng responder.',
};

final _englishTranslations = <String, String>{
  for (final entry in _tagalogTranslations.entries) entry.value: entry.key,
  'Kulang ang profile mo sa account. Punan muna ito sa Profile settings bago mag-request.':
      'Your account profile is incomplete. Please complete it in Profile settings before making a request.',
  'Kulang ang profile mo. Pakikumpleto muna ito sa Profile settings.':
      'Your profile is incomplete. Please complete it in Profile settings first.',
  'Ito ang naka-save sa iyong account. I-edit sa Profile settings kung mali.':
      'This information is saved to your account. Edit it in Profile settings if it is incorrect.',
};

class AppLanguageSwitcher extends StatelessWidget {
  const AppLanguageSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: translate(context, 'Language'),
      onSelected: (languageCode) {
        setAppLanguage(Locale(languageCode));
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'en',
          child: Text(selectedLanguage == 'tl' ? 'Ingles' : 'English'),
        ),
        const PopupMenuItem(value: 'tl', child: Text('Tagalog')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 20),
            if (!compact) const SizedBox(width: 5),
            Text(
              selectedLanguage == 'tl' ? 'TL' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
