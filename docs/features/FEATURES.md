# LuhaRide — Complete Features Guide

Uttarakhand ka apna taxi booking platform. Sabhi features role-wise listed hain — chhote se chhote (mini) se le kar bade (macro) tak, taaki poori app A-to-Z samajh aaye.

_Last updated: 2026-06-23 — added Ola Maps & Location, Driver Seat Reserve/Lock, expanded Vehicle Catalog._

**Roles:** 1) Passenger (Yatri) · 2) Independent Driver (Swatantra Chalak) · 3) Union Admin (Union Prabandhan) · 4) Platform Admin (Super Admin) · 5) Common (sabke liye).

---

## 1. PASSENGER (Sawari / Yatri)

### 1.1 Account & Login
| # | Feature | Description |
|---|---------|-------------|
| 1 | Email/Password Signup | Email, password, naam se account banao |
| 2 | Email/Password Login | Email aur password se login karo |
| 3 | Google Sign-In | Ek tap mein Google account se login |
| 4 | OTP Login (Phone) | Phone number par OTP se login |
| 5 | OTP Login (Email) | Email par OTP se login/signup |
| 6 | Forgot Password | Email OTP se password reset karo |
| 7 | Change Password | Profile se naya password set karo |
| 8 | Logout | Session khatam karo, data safe |
| 9 | Account Delete | Account permanently delete karo (password confirm) |

### 1.2 Ride Search & Booking
| # | Feature | Description |
|---|---------|-------------|
| 10 | Search Rides | From, To, Date daalke rides dhundho |
| 11 | Location Suggestions | Type karte hi location suggestions aate hain |
| 12 | Recent Routes | Pehle search ki hui routes quick access mein |
| 13 | Browse Without Login | Bina login ke bhi rides dekh sakte ho landing page pe |
| 14 | Trip Details | Full details — driver info, fare, seats, rating |
| 15 | Seat Layout View | Visual seat map — available/booked/pending dikhta hai |
| 16 | Seat Selection | Multiple seats ek saath select karo |
| 17 | Book Seat | Seat book karo — pending/confirmed status milta hai |
| 18 | Duplicate Booking Protection | Ek hi seat do baar book nahi hogi (idempotency key) |
| 19 | Real-time Seat Updates | Koi aur book kare to turant seat status update hota hai (live) |

### 1.3 My Rides & Bookings
| # | Feature | Description |
|---|---------|-------------|
| 20 | View My Bookings | Saari bookings dekho — upcoming aur past |
| 21 | Booking Status | Pending, Confirmed, Completed, Cancelled status |
| 22 | Cancel Pending Booking | Pending booking kabhi bhi cancel karo |
| 23 | Cancel Confirmed Booking | Confirmed booking departure se pehle kabhi bhi cancel (baar-baar cancel pe temporary block) |
| 24 | Cancellation Reason | Cancel karte waqt optional reason de sakte ho |

### 1.4 Reviews & Ratings
| # | Feature | Description |
|---|---------|-------------|
| 25 | Rate Driver | Trip complete hone ke baad 1-5 star rating do |
| 26 | Write Review | Optional comment likho driver ke baare mein |
| 27 | View Driver Ratings | Kisi bhi driver ka rating aur reviews dekho |
| 28 | View My Ratings | Apne received ratings dekho |

### 1.5 Profile
| # | Feature | Description |
|---|---------|-------------|
| 29 | Edit Name | Apna naam update karo |
| 30 | Edit Phone | Phone number update karo |
| 31 | Edit Email | Email update karo |
| 32 | Profile Photo | Gallery se photo lagao ya change karo |
| 33 | WhatsApp Number | Alag WhatsApp number add karo |
| 34 | Bio | Chhota sa description likho apne baare mein |

### 1.6 Notifications
| # | Feature | Description |
|---|---------|-------------|
| 35 | Push Notifications (FCM) | Booking confirm, trip update, union rides — sab notification aata hai |
| 36 | In-App Notifications | App ke andar saari notifications list mein |
| 37 | Mark as Read | Ek ya saari notifications read mark karo |
| 38 | Unread Badge | Nav bar mein red badge dikhata hai kitni unread hain |

### 1.7 Other
| # | Feature | Description |
|---|---------|-------------|
| 39 | Language Selection | Hindi ya English — apni pasand ki language |
| 40 | Share Trip | Trip link share karo WhatsApp/social media pe |
| 41 | Copy Trip Link | Trip link clipboard mein copy karo |
| 42 | Call Driver | Seedha driver ko call karo trip details se |
| 43 | WhatsApp Driver | Driver ko WhatsApp message bhejo |
| 44 | Terms & Conditions | App ki terms of service padhho |
| 45 | Help / FAQ | Madad chahiye to help section dekho |

### 1.8 Maps & Location — Ola Maps (New)
| # | Feature | Description |
|---|---------|-------------|
| 211 | Nearest-First Suggestions | Location allow karne pe paas wali jagah pehle dikhti hain (Ola autocomplete) |
| 212 | Region-Bias (Uttarakhand) | "Clock Tower" jaisa naam local resolve hota hai — galti se Bangalore wala nahi |
| 213 | Use My Current Location | GPS se pickup auto-fill (reverse geocode — coordinates → jagah ka naam) |
| 214 | Permission Handled Gracefully | GPS off / permission deny ho to friendly message, app crash nahi — typing chalu rehta |
| 215 | Proximity + Rating Search | Map se From/To choose karo to results doori + rating ke hisaab se rank hote hain (short trip = tight radius, long = capped) |
| 216 | Fair Fare Ceiling | Map coordinates se road-distance nikal ke max fare enforce hota hai (over-charge se bachao) |

---

## 2. INDEPENDENT DRIVER (Swatantra Chalak)

### 2.1 Account & Login
| # | Feature | Description |
|---|---------|-------------|
| 46 | Signup/Login | Same as passenger — email, Google, OTP sab supported |
| 47 | Role Selection | Signup ke time "Driver" role choose karo |

### 2.2 KYC / Driver Verification
| # | Feature | Description |
|---|---------|-------------|
| 48 | Submit Aadhaar Card | Aadhaar front + back photo upload karo |
| 49 | Submit Driving License | License front + back photo upload karo |
| 50 | Select Vehicle | Dropdown se vehicle choose karo ya custom likho |
| 51 | Vehicle Seat Count | Custom vehicle mein total seats set karo |
| 52 | Vehicle Registration Number | Gaadi ka number daalo (approve hone ke baad lock ho jaata hai) |
| 53 | Verification Status | Dekho status — None, Pending, Approved, Rejected |
| 54 | Rejection Reason | Reject hua to reason dikhta hai |
| 55 | Re-verify After Rejection | Reject hone ke baad fir se documents submit karo |
| 56 | View Submitted Documents | Pehle submit kiye documents dekho |
| 57 | Document Watermark | Server automatically watermark lagata hai misuse prevention ke liye |
| 58 | Union Exclusivity Check | Agar union mein ho to independent driver nahi ban sakte |

### 2.3 Trip Creation & Management
| # | Feature | Description |
|---|---------|-------------|
| 59 | Create Trip | From, To, Date, Time, Fare, Seats — sab set karke trip banao |
| 60 | Location Autocomplete | From/To mein type karo, suggestions aate hain |
| 61 | Set Fare Per Seat | Har seat ka fare set karo |
| 62 | Set Total Seats | Total seats verified vehicle se (default 7, max 32; seat 1 = driver) |
| 63 | Add Stops/Waypoints | Beech ke stops add karo (optional) |
| 64 | Luggage Allowance | Luggage info set karo per passenger |
| 65 | Booking Approval Mode | Auto-approve ya manual approve choose karo |
| 66 | View My Trips | Saari trips dekho — Scheduled, Active, Completed, Cancelled |
| 67 | Start Trip | Scheduled trip ko "In Progress" karo |
| 68 | Complete Trip | Trip complete mark karo |
| 69 | Cancel Trip | Trip cancel karo (2 ghante pehle limit agar confirmed passengers hain) |
| 70 | Delete Trip | Trip delete karo (sirf jab koi booking nahi hai) |

### 2.4 Booking Management
| # | Feature | Description |
|---|---------|-------------|
| 71 | View Bookings | Trip ki saari bookings dekho |
| 72 | Accept Booking | Pending booking accept karo |
| 73 | Reject Booking | Pending booking reject karo |
| 74 | Passenger Details | Booking karne wale ka naam, rating dekho |
| 75 | Rate Passenger | Trip ke baad passenger ko rate karo |

### 2.5 Seat Reserve / Lock (New)
| # | Feature | Description |
|---|---------|-------------|
| 217 | Reserve Own Seat | Apni ride ki koi bhi khali seat tap karke reserve (lock) karo — jaise kisi relative ke liye |
| 218 | Add Note | Reserve karte waqt optional note (e.g. "bhai ke liye") |
| 219 | Passenger Blocked | Reserved seat koi passenger book nahi kar sakta — usse grey/booked dikhta hai |
| 220 | Release Seat | Reserved seat tap karke wapas free karo — passengers fir book kar sakte hain |
| 221 | Safe Rules | Seat 1 (driver) reserve nahi hoti; already-booked seat reserve nahi hoti; sirf khud ki ride; departure ke baad nahi — koi conflict/crash nahi |

### 2.6 Sharing
| # | Feature | Description |
|---|---------|-------------|
| 76 | Share Trip | Trip link share karo social media pe |
| 77 | Copy Link | Clipboard mein link copy karo |

### 2.7 Profile & Notifications
| # | Feature | Description |
|---|---------|-------------|
| 78 | Same as Passenger | Profile edit, notifications, language, help — sab same |

---

## 3. UNION ADMIN (Taxi Union Prabandhan)

### 3.1 Account & Login
| # | Feature | Description |
|---|---------|-------------|
| 79 | Signup/Login | Email, Google, OTP — same as others |

### 3.2 Union Registration
| # | Feature | Description |
|---|---------|-------------|
| 80 | Register Union | Union ka naam, location, phone, email, owner naam fill karo |
| 81 | Upload Owner Aadhaar | Owner ka Aadhaar (front + back) upload karo |
| 82 | Upload Office Photo | Union office ki photo upload karo |
| 83 | Upload Union Photo | Union ki group photo (optional) |
| 84 | Upload Driver List Photo | Drivers ki list ka photo (optional) |
| 85 | Upload Leader DL | Leader ki driving license (optional) |
| 86 | Upload Vehicle RC | Vehicle RC front + back (optional) |
| 87 | Union Share Notes | Extra notes likho admin ke liye |
| 88 | Status Tracking | None → Pending → Approved/Rejected |
| 89 | Check Status | Manual button se status refresh karo |
| 90 | Auto PDF Merge | Server aadhaar front+back ko ek PDF mein merge karta hai |

### 3.3 Union Dashboard
| # | Feature | Description |
|---|---------|-------------|
| 91 | Dashboard Stats | Total trips, bookings, drivers, schedules — sab ek jagah |
| 92 | Pending KYC Badge | Kitne KYC requests pending hain badge dikhata hai |
| 93 | Contact Analytics | Kitne passengers ne call/WhatsApp kiya — driver wise, date wise |

### 3.4 Driver Management
| # | Feature | Description |
|---|---------|-------------|
| 94 | Add Driver | Naam, vehicle number, phone, WhatsApp se driver add karo |
| 95 | View All Drivers | Union ke saare drivers ki list |
| 96 | Remove Driver | Driver ko union se hataao |
| 97 | Driver Search | Drivers mein search karo |

### 3.5 Route Management
| # | Feature | Description |
|---|---------|-------------|
| 98 | Add Preset Route | From-To pair save karo reuse ke liye |
| 99 | View Routes | Saari saved routes dekho |
| 100 | Delete Route | Route hataao |

### 3.6 Ride/Schedule Creation
| # | Feature | Description |
|---|---------|-------------|
| 101 | Bulk Create Rides | Ek saath multiple drivers ke liye rides banao |
| 102 | Select Multiple Drivers | Checkbox se drivers choose karo |
| 103 | Set From/To/Time | Route aur departure time set karo |
| 104 | Daily Limit | Ek din mein maximum 3 baar rides bana sakte ho |
| 105 | View Current Schedules | Aaj ki saari scheduled rides dekho |
| 106 | View Recent Schedules | Puraani rides bhi dekh sakte ho |
| 107 | Cancel Schedule | Koi ek ride cancel karo |

### 3.7 FCM Notifications (Auto)
| # | Feature | Description |
|---|---------|-------------|
| 108 | Auto Notification on First Ride | Din ki pehli ride banate hi saare passengers ko notification jaata hai |
| 109 | Rotating Messages | Har din alag funny Hindi message jaata hai (7 messages, weekly rotate) |
| 110 | Union Name in Message | Notification mein union ka naam aata hai |
| 111 | Per-Union FCM Control | Admin se FCM ON/OFF hota hai per union |
| 112 | Global FCM Control | Admin ek button se saare unions ka FCM ON/OFF kar sakta hai |

### 3.8 Poster & Branding
| # | Feature | Description |
|---|---------|-------------|
| 113 | Set Poster Header | Poster pe union ka header text set karo |
| 114 | Custom Text | Extra text add karo poster pe (left/right position) |
| 115 | Layout Type | Classic ya Compact layout choose karo |
| 116 | Theme Selection | Saffron, Sky, Mint, Rose — 4 theme options |
| 117 | Download Single Poster | Ek ride ka poster PDF download karo |
| 118 | Download Combined Poster | Multiple rides ka ek combined poster download karo |
| 119 | Share Poster | Poster share karo WhatsApp/social media pe |

### 3.9 Document Re-upload
| # | Feature | Description |
|---|---------|-------------|
| 120 | Update Documents | Admin permission milne pe documents dubara upload karo |
| 121 | Document Status | Approved, Pending, Rejected — track karo |
| 122 | Reupload Deadline | Admin deadline set karta hai, usse pehle upload karna hoga |

### 3.10 KYC Admin Access
| # | Feature | Description |
|---|---------|-------------|
| 123 | Approve/Reject Drivers | Independent drivers ki KYC approve/reject karo |
| 124 | Approve/Reject Unions | New union registrations approve/reject karo |
| 125 | View Driver Directory | Saare verified independent drivers ki list |
| 126 | View Union Directory | Saari registered unions ki list |
| 127 | Stream KYC Documents | Submitted documents dekho review ke liye |
| 128 | Grant Re-verify | Rejected driver/union ko dubara submit karne ki permission do |

---

## 4. PLATFORM ADMIN (Super Admin)

### 4.1 Dashboard
| # | Feature | Description |
|---|---------|-------------|
| 129 | Overview Stats | Total users, drivers, passengers, union admins — ek nazar mein |
| 130 | Trip Statistics | Total, Scheduled, Active, Completed, Cancelled trips |
| 131 | Today's Trips | Aaj kitni trips hain |
| 132 | New Users This Week | Is hafte kitne naye users aaye |
| 133 | Active Drivers | Last 30 din mein kitne drivers active |
| 134 | Pending KYC Count | Kitne KYC requests pending hain |

### 4.2 User Management
| # | Feature | Description |
|---|---------|-------------|
| 135 | View All Users | Saare users ki list with pagination |
| 136 | Search Users | Naam ya email se search karo |
| 137 | Filter by Role | Passenger, Driver, Union Admin filter |
| 138 | User Details | Kisi bhi user ki full detail dekho |
| 139 | Enable/Disable User | User account active/inactive karo |

### 4.3 Trip Management
| # | Feature | Description |
|---|---------|-------------|
| 140 | View All Trips | Platform ki saari trips dekho |
| 141 | Search Trips | Trip ID ya details se search karo |
| 142 | Filter by Status | Scheduled, Active, Completed, Cancelled filter |
| 143 | Trip Details | Full trip info — passengers, bookings, driver |
| 144 | Cancel Any Trip | Emergency mein koi bhi trip cancel karo |

### 4.4 Revenue & Stats
| # | Feature | Description |
|---|---------|-------------|
| 145 | Revenue Overview | Daily, Weekly, Monthly revenue dekho |
| 146 | Booking Stats | Confirmed, Pending, Cancelled bookings count |
| 147 | Daily Statistics | Din ke hisaab se detailed stats (90/180 days) |
| 148 | Export CSV | Stats download karo CSV mein (share bhi kar sakte ho) |
| 149 | User Growth Trends | Naye users ka trend dekho |
| 150 | Trip Volume Trends | Trips ka volume trend |

### 4.5 Notifications & Broadcasting
| # | Feature | Description |
|---|---------|-------------|
| 151 | Send Bulk Notification | Saare users ko ya specific role ko notification bhejo |
| 152 | Segment Selection | All Users, Passengers, Drivers, Union Admins — choose karo |
| 153 | Compose Title & Body | Notification ka title aur body likho |
| 154 | Broadcast History | Pehle bheji notifications ki list dekho |

### 4.6 Union FCM Control
| # | Feature | Description |
|---|---------|-------------|
| 155 | Global FCM ON/OFF | Ek button se saare unions ka FCM ON/OFF |
| 156 | Per-Union FCM Toggle | Har union ka individually ON/OFF karo |
| 157 | Union Count & Status | Kitni unions hain, kitni ON hain — sab dikhta hai |
| 158 | Global Sync | Global toggle se saare union buttons ek saath sync hote hain |

### 4.7 Complaint Management
| # | Feature | Description |
|---|---------|-------------|
| 159 | View All Complaints | Saari complaints dekho |
| 160 | Search Complaints | Complaints mein search karo |
| 161 | Filter by Status | Open ya Resolved filter |
| 162 | Complaint Details | Full complaint with context dekho |
| 163 | Resolve Complaint | Resolution note likh ke resolve karo |
| 164 | Submit Complaint | Koi bhi user complaint submit kar sakta hai |
| 165 | My Complaints | Apni submit ki hui complaints dekho |

### 4.8 App Configuration
| # | Feature | Description |
|---|---------|-------------|
| 166 | View App Config | Platform settings dekho |
| 167 | Update App Config | Settings update karo (feature flags, limits) |

### 4.9 KYC Admin (Same as Union Admin)
| # | Feature | Description |
|---|---------|-------------|
| 168 | Full KYC Access | Driver/Union approve, reject, re-verify — sab admin kar sakta hai |

---

## 5. COMMON FEATURES (Sabke Liye)

### 5.1 Real-Time Updates
| # | Feature | Description |
|---|---------|-------------|
| 169 | Live Seat Updates | Koi seat book kare to turant dikhta hai bina refresh ke |
| 170 | Trip Status Live | Trip start/complete/cancel hone pe real-time update |
| 171 | Socket.IO Connection | WebSocket se instant updates milte hain |

### 5.2 Security
| # | Feature | Description |
|---|---------|-------------|
| 172 | JWT Token Auth | Secure access + refresh token system |
| 173 | Auto Token Refresh | Token expire hone pe silently refresh hota hai |
| 174 | Session Expired Handling | Refresh fail ho to automatic login screen pe |
| 175 | Rate Limiting | Har endpoint pe request limit — spam protection |
| 176 | KYC Watermarking | Uploaded documents pe watermark — misuse prevention |
| 177 | Input Validation | Saare inputs validate hote hain — XSS/injection prevention |

### 5.3 Performance
| # | Feature | Description |
|---|---------|-------------|
| 178 | Redis Caching | Trip search results 30 sec cached |
| 179 | Location Cache | Location suggestions 5 min cached |
| 180 | Review Cache | Ratings 15 min memory cache + disk cache |
| 181 | Offline Review Access | Reviews cached locally for offline viewing |
| 182 | 502/503 Auto Retry | Server temporarily down? Ek baar retry hota hai automatically |

### 5.4 Localization
| # | Feature | Description |
|---|---------|-------------|
| 183 | Hindi Language | Puri app Hindi mein available |
| 184 | English Language | English bhi fully supported |
| 185 | Persistent Language | Language preference save rehta hai |
| 186 | Localized Errors | Error messages bhi selected language mein |

### 5.5 Auto Background Jobs
| # | Feature | Description |
|---|---------|-------------|
| 187 | Rate Reminder Notification | Trip complete hone ke baad auto "Rate your ride" notification jaata hai driver + passenger dono ko |
| 188 | Ride Cleanup Job | Purani trips, expired tokens, old OTPs — raat ko automatic saaf hote hain |
| 189 | Union Schedule Cleanup | Puraane union schedules auto delete hote hain retention policy ke hisaab se |
| 190 | Stale FCM Token Cleanup | Invalid push notification tokens auto remove hote hain |

### 5.6 Landing Page (No Login Required)
| # | Feature | Description |
|---|---------|-------------|
| 191 | Public Ride Search | Bina login ke rides search karo landing page pe |
| 192 | View Independent Driver Rides | Independent drivers ki trips dikhti hain search results mein |
| 193 | View Union Rides | Union ki rides bhi dikhti hain alag section mein |
| 194 | Driver Contact from Landing | Landing page se seedha driver ko call/WhatsApp karo |
| 195 | Login/Signup Prompt | Book karne ke liye login karna padta hai — prompt dikhta hai |
| 196 | Date Picker | Search mein date select karo — aaj ya future dates |

### 5.7 App UX Features
| # | Feature | Description |
|---|---------|-------------|
| 197 | In-App Update | Play Store se naya update available ho to app mein prompt aata hai |
| 198 | Double Back to Exit | Galti se app band na ho — do baar back press karna padta hai |
| 199 | Role-Based Home Screen | Login ke baad role ke hisaab se sahi home screen dikhta hai |
| 200 | Shimmer Loading | Data load hote waqt smooth shimmer animation dikhta hai |
| 201 | Pull to Refresh | Neeche kheench ke data refresh karo (dashboard, rides, etc.) |
| 202 | Vehicle Catalog | 14 brands ki gaadiyon ki list — Maruti, Tata, Mahindra, Toyota, Hyundai, Kia, Honda, Renault, Nissan, Chevrolet, MG, Skoda, VW, Force — hill taxis (Tavera, Qualis, Sumo, Bolero, Innova) sahit, sahi seat layout ke saath. "Other Vehicle" custom option bhi |
| 203 | Visual Seat Layout | Gaadi ke andar seats ka real top-view map (front/middle/rear/bench) — RHD, driver right side |
| 204 | Self-Book Prevention | Driver apni hi trip book nahi kar sakta |
| 205 | Secure Token Storage | Auth tokens encrypted storage mein safe rehte hain |
| 206 | Telegram Alerts (Backend) | Server issues (Redis down, job failures) pe admin ko Telegram pe alert jaata hai |
| 207 | Demo Account Creation | First time setup ke liye demo accounts bana sakte ho (passenger, driver, admin) |

### 5.8 Platform Support
| # | Feature | Description |
|---|---------|-------------|
| 208 | Android App (APK) | Mobile app Android ke liye |
| 209 | Web App | Browser mein bhi chalti hai app |
| 210 | Responsive Design | Mobile aur desktop dono pe sahi dikhti hai |

---

## Quick Numbers

| Category | Count |
|----------|-------|
| Total Features | 221+ |
| Passenger Features | 51 (incl. 6 Maps & Location) |
| Independent Driver Features | 38 (incl. 5 Seat Reserve/Lock) |
| Union Admin Features | 49 |
| Platform Admin Features | 40 |
| Common/Shared Features | 43 |
| API Endpoints | 72+ |
| User Roles | 4 (Passenger, Driver, Union Admin, Platform Admin) |
