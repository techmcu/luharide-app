# 003 — Search me galat same-naam wali jagah upar aa rahi thi (proximity ranking)

> **Ek line me:** Koi chhota gaon/town search karo (jaise "Chandeli" near Purola, ya
> "Roorkee" near Dehradun) aur usi naam ka ek **bada/door wala** sheher pehle aa jata
> tha — user galti se usi pe click kar deta. Fix: suggestions ab **user ke paas wali
> jagah pehle** dikhati hain — **pure India me, kahin bhi** (sirf Uttarakhand nahi).

- **Date:** 2026-06-24
- **Severity:** Medium (user galat jagah pick kar leta tha → galat ride)
- **Area:** Backend `trip/tripSearchController.js` → `rankPlaces()` (location autocomplete)
- **Mobile:** Pehle se `near_lat/near_lng` bhejta tha + district/state label dikhata tha — **APK rebuild ki zaroorat nahi.**

---

## 1. Real-life story 📖

Tum **Dehradun** me ho aur ride search me **"Roo"** type karte ho. India me bahut
"Roo…" jagah ho sakti hain. Pehle text-match ke hisaab se koi door wali jagah upar
aa jati thi, aur **Roorkee (Dehradun se ~70 km)** niche. User confuse — galat jagah
select. Ya "Chandeli" (Purola ke paas ek gaon) search karo to Delhi/door wali
"Chandeli" pehle.

---

## 2. Root cause 🤔

Location suggestions ka **final sort sirf text-match** pe tha (exact → starts-with →
contains → chhota naam). **Distance (tum kahan ho) ka istemaal nahi** ho raha tha
ranking me — isliye door wali same-naam jagah upar aa sakti thi.

```
Type "Roo"  →  [text-match sort]  →  koi bhi "Roo…" upar (door wala bhi)
                                      Roorkee (paas) niche reh jata
```

---

## 3. Fix — Proximity Ranking (Ola/Uber/Rapido jaisa) ✅

Ek **pure, testable** helper `rankPlaces()` jo is order me rank karta hai:

1. **Text relevance** — exact → starts-with → word-starts → contains
2. **NEAREST to user first** — tumhare reference point se **haversine distance** (chhota = upar). *Koi "km" number nahi dikhता* — sirf order theek hota hai; **district/state label** se user visibly pehchanta hai ("Roorkee · Haridwar, Uttarakhand").
3. **Simplest/chhota naam** — tiebreak

```
Type "Roo" (Dehradun me)  →  Roorkee (70 km) UPAR  →  door wale niche
Type "Andheri" (Mumbai me) →  Mumbai wali Andheri UPAR  →  door wali niche
```

### Reference point kahan se aata hai (fallback chain)
GPS off ho to bhi kaam kare — isliye:
```
Live GPS  →  (off?) user ka pehle-pick kiya "from"  →  (woh bhi nahi?) neutral text-rank
```
App pehle se "from" coords ko picker bias ke roop me bhejta hai, toh GPS off pe bhi
nearest jagah jeet jati hai.

### ⭐ REGION-AGNOSTIC — pure India (sirf Uttarakhand nahi)
Pehla draft me galti se **Uttarakhand center hardcode** ho gaya tha (300 km service-area).
Iska matlab Mumbai/Chennai/Kolkata wale user (GPS off) ke **apne local places demote**
ho jate — bilkul galat. **Fix:** koi hardcoded center/region penalty nahi. Sirf **user
ke apne reference se distance**. Mumbai user → Mumbai ke paas; Dehradun user → Dehradun
ke paas. Reference na ho to **kisi region ko penalty nahi** (neutral text-rank).

> App ka primary-market (Uttarakhand) nudge **soft** rehta hai — woh upstream Ola
> autocomplete config me hai, ranking me nahi (jahan ek region ko over-bias kar deta).

---

## 4. System design concepts

| Concept | Simple matlab |
|---------|---------------|
| **Location bias** | User ke paas wale result pehle (ranking ke liye) |
| **Proximity ranking** (haversine) | Seedhi-rekha distance se sort — region-agnostic |
| **Disambiguation** | District + State label se same-naam jagah alag dikhe |
| **Reference fallback chain** | GPS → "from" → neutral (GPS off pe bhi kaam) |
| **No hardcoding** | Koi gaon/city/region code me likha nahi — har jagah same algorithm |

---

## 5. Lesson 🎯

1. Same-naam jagah disambiguate karne ka best tarika = **proximity (distance) + area label**, "km number" dropdown me nahi (Ola/Uber bhi number nahi dikhate).
2. **Kabhi ek region/city hardcode mat karo** — solution generic ho, pure India me chale.
3. Distance ke liye **GPS akela source nahi** — fallback chain (from-field, etc.) rakho.
4. Ye change **backend-only** tha — mobile pehle se data bhej raha tha; isliye naya APK nahi laga.
