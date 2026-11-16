// Site config shared by index.html and privacy.html: the ONLY place contact details,
// store links and the facts the privacy page needs live. Empty contact/store values hide
// their buttons or show "coming soon"; empty policy values keep the privacy page's
// draft banner on. Tests inject window.SITE_OVERRIDE before this runs.
window.SITE = Object.assign({
  zaloUrl: '',     // e.g. https://zalo.me/09xxxxxxxx
  phone: '',       // e.g. 09xxxxxxxx
  email: '',       // e.g. hello@nanopos.vn
  androidUrl: '',  // Google Play listing of the counter app
  iosUrl: '',      // App Store listing of the counter app
  termsUrl: '',
  privacyUrl: 'privacy.html',
  webAppUrl: '',   // Nano Admin sign-in page

  // Privacy page facts. Fill all four (and have the text reviewed) before launch.
  controllerName: '',      // who is responsible for the data, e.g. the registered household business
  policyEmail: '',         // where data requests go
  hostingRegion: '',       // where the servers that hold shop data are located
  policyEffectiveDate: ''  // dd/mm/yyyy
}, window.SITE_OVERRIDE || {});
