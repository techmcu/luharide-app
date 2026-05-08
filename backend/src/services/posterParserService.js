const DEFAULT_CONTACT = '7060618851';

const KNOWN_LOCATIONS = [
  'dehradun', 'mussoorie', 'haridwar', 'rishikesh', 'nainital', 'almora',
  'ranikhet', 'haldwani', 'rudrapur', 'roorkee', 'kashipur', 'kotdwar',
  'pauri', 'chamoli', 'joshimath', 'badrinath', 'kedarnath', 'gangotri',
  'yamunotri', 'purola', 'uttarkashi', 'tehri', 'srinagar', 'pithoragarh',
  'champawat', 'bageshwar', 'lansdowne', 'auli', 'chopta', 'tungnath',
  'dhanaulti', 'chakrata', 'new tehri', 'vikasnagar', 'doiwala',
  'pondha', 'selaqui', 'premnagar', 'raipur', 'herbertpur', 'saharanpur',
  'delhi', 'new delhi', 'noida', 'gurgaon', 'gurugram', 'meerut',
  'chandigarh', 'ambala', 'karnal', 'panipat', 'lucknow', 'agra',
  'mathura', 'moradabad', 'bareilly', 'rampur', 'bijnor', 'muzaffarnagar',
  'shamli', 'najibabad', 'nagina', 'dhampur', 'laksar', 'jwalapur',
  'ramnagar', 'kathgodam', 'bhowali', 'bhimtal', 'kausani', 'mukteshwar',
  'binsar', 'chamba', 'dalhousie', 'shimla', 'manali', 'dharamshala',
];

const VEHICLE_KEYWORDS = [
  'innova', 'crysta', 'fortuner', 'ertiga', 'bolero', 'sumo', 'thar',
  'swift', 'dzire', 'etios', 'indigo', 'wagonr', 'wagon r', 'alto',
  'scorpio', 'xuv', 'brezza', 'nexon', 'creta', 'seltos', 'hector',
  'tempo traveller', 'tempo', 'traveller', 'mini bus',
  'taxi', 'cab', 'jeep', 'suv', 'sedan', 'hatchback', 'bus',
];

function extractPhoneNumbers(text) {
  const re = /(?:\+91[\s.-]?|91[\s.-]?|0)?([6-9]\d{9})\b/g;
  const found = new Set();
  let m;
  while ((m = re.exec(text)) !== null) found.add(m[1]);
  return [...found];
}

function isValidPhone(num) {
  return /^[6-9]\d{9}$/.test(num);
}

function extractLocations(text) {
  const lower = text.toLowerCase().replace(/\n/g, ' ');

  const patternsExplicit = [
    /from\s+([a-z\s]{2,30})\s+to\s+([a-z\s]{2,30})/i,
    /([a-z\s]{2,30})\s+se\s+([a-z\s]{2,30})\s+(?:tak|ko|jane)/i,
    /([a-z\s]{2,30})\s*(?:→|➡|⟶|->)\s*([a-z\s]{2,30})/i,
    /([a-z\s]{2,30})\s+to\s+([a-z\s]{2,30})/i,
  ];

  for (const pat of patternsExplicit) {
    const match = lower.match(pat);
    if (match) {
      const from = capitalize(match[1].trim());
      const to = capitalize(match[2].trim());
      if (from.length >= 2 && to.length >= 2) return { from, to };
    }
  }

  const found = [];
  for (const loc of KNOWN_LOCATIONS) {
    const idx = lower.indexOf(loc);
    if (idx !== -1) found.push({ name: capitalize(loc), idx });
  }
  found.sort((a, b) => a.idx - b.idx);
  const unique = [];
  const seen = new Set();
  for (const f of found) {
    if (!seen.has(f.name.toLowerCase())) {
      seen.add(f.name.toLowerCase());
      unique.push(f);
    }
  }
  if (unique.length >= 2) return { from: unique[0].name, to: unique[1].name };
  if (unique.length === 1) return { from: unique[0].name, to: null };
  return { from: null, to: null };
}

function extractDate(text) {
  const re = /(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/;
  const match = text.match(re);
  if (match) {
    let [, day, month, year] = match;
    if (year.length === 2) year = '20' + year;
    const d = new Date(`${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}T00:00:00`);
    if (isNaN(d.getTime())) return null;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return { date: d.toISOString().split('T')[0], isPast: d < today };
  }
  return null;
}

function extractTime(text) {
  const re12 = /(\d{1,2})\s*:\s*(\d{2})\s*(am|pm)/i;
  const m12 = text.match(re12);
  if (m12) {
    let h = parseInt(m12[1], 10);
    const min = m12[2];
    const ampm = m12[3].toLowerCase();
    if (ampm === 'pm' && h < 12) h += 12;
    if (ampm === 'am' && h === 12) h = 0;
    return `${String(h).padStart(2, '0')}:${min}`;
  }
  const re24 = /(\d{1,2})\s*:\s*(\d{2})\s*(?:hrs?|hours?|baje)?/i;
  const m24 = text.match(re24);
  if (m24) {
    const h = parseInt(m24[1], 10);
    if (h >= 0 && h <= 23) return `${String(h).padStart(2, '0')}:${m24[2]}`;
  }
  const reBaje = /(\d{1,2})\s*baje/i;
  const mb = text.match(reBaje);
  if (mb) {
    const h = parseInt(mb[1], 10);
    if (h >= 1 && h <= 12) return `${String(h).padStart(2, '0')}:00`;
  }
  return null;
}

function extractFare(text) {
  const re1 = /(?:₹|Rs\.?\s*|INR\s*)(\d+(?:\.\d{1,2})?)/i;
  const m1 = text.match(re1);
  if (m1) return parseFloat(m1[1]);
  const re2 = /(?:fare|price|rate|charge|cost|kiraya|kiray[ae])\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?(\d+)/i;
  const m2 = text.match(re2);
  if (m2) return parseFloat(m2[1]);
  return null;
}

function extractVehicleType(text) {
  const lower = text.toLowerCase();
  for (const v of VEHICLE_KEYWORDS) {
    if (lower.includes(v)) return capitalize(v);
  }
  return null;
}

function extractDriverName(text) {
  const patterns = [
    /(?:driver|naam|name|contact\s*person|chalak)\s*[:\-–]\s*([A-Za-z][A-Za-z\s]{1,29})/i,
  ];
  for (const p of patterns) {
    const m = text.match(p);
    if (m) {
      const name = m[1].trim();
      if (name.length >= 2 && !/^\d/.test(name)) return capitalize(name);
    }
  }
  return null;
}

function capitalize(s) {
  return s.replace(/\b\w/g, (c) => c.toUpperCase());
}

function parsePosterText(rawText, riderSeq = 1) {
  const warnings = [];
  const phones = extractPhoneNumbers(rawText);
  let contact = phones.length > 0 ? phones[0] : null;

  if (contact && !isValidPhone(contact)) {
    warnings.push(`Extracted number "${contact}" appears invalid, using default`);
    contact = DEFAULT_CONTACT;
  }
  if (!contact) {
    contact = DEFAULT_CONTACT;
    warnings.push('No contact number found, using default');
  }

  const locations = extractLocations(rawText);
  if (!locations.from) warnings.push('Could not detect origin location');
  if (!locations.to) warnings.push('Could not detect destination location');

  const dateInfo = extractDate(rawText);
  if (dateInfo && dateInfo.isPast) {
    warnings.push('Date appears to be in the past — ride may not be valid');
  }

  let driverName = extractDriverName(rawText);
  if (!driverName) {
    driverName = `Rider ${riderSeq}`;
    warnings.push('Driver name not found, using default');
  }

  const fare = extractFare(rawText);
  const vehicleType = extractVehicleType(rawText);
  const time = extractTime(rawText);

  const usedTokens = new Set();
  [locations.from, locations.to, driverName, contact, vehicleType].forEach((v) => {
    if (v) usedTokens.add(v.toLowerCase());
  });
  const lines = rawText.split(/\n/).map((l) => l.trim()).filter(Boolean);
  const extra = lines.filter((l) => {
    const lower = l.toLowerCase();
    return !([...usedTokens].some((t) => lower.includes(t)));
  }).slice(0, 5);

  return {
    from_location: locations.from,
    to_location: locations.to,
    driver_name: driverName,
    contact_number: contact,
    vehicle_type: vehicleType,
    departure_date: dateInfo ? dateInfo.date : null,
    departure_time: time,
    fare_per_seat: fare,
    date_is_past: dateInfo ? dateInfo.isPast : false,
    raw_text: rawText,
    extra_details: extra,
    warnings,
  };
}

module.exports = { parsePosterText, DEFAULT_CONTACT };
