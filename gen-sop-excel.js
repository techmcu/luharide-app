const ExcelJS = require('exceljs');
const fs = require('fs');

const raw = fs.readFileSync('LuhaRide_Testing_SOP.csv', 'utf8');

function parseCSVLine(line) {
  const cells = [];
  let current = '', inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') { inQuotes = !inQuotes; continue; }
    if (ch === ',' && !inQuotes) { cells.push(current.trim()); current = ''; continue; }
    current += ch;
  }
  cells.push(current.trim());
  return cells;
}

const lines = raw.split('\n').map(l => l.replace(/\r$/, ''));

const wb = new ExcelJS.Workbook();
wb.creator = 'LuhaRide QA';

const colors = {
  headerBg: '1B2A4A',
  headerFont: 'FFFFFF',
  partBg: '2C3E6B',
  partFont: 'FFFFFF',
  catBg: 'E8EDF5',
  catFont: '1B2A4A',
  border: 'BDBDBD',
  high: 'C62828',
  medium: 'E65100',
  low: '2E7D32',
  auto: '1B5E20',
  manual: 'BF360C',
};

const partColors = {
  'P': 'E8F5E9',
  'D': 'FFF3E0',
  'U': 'E3F2FD',
  'A': 'FCE4EC',
  'C': 'F3E5F5',
  'BL': 'FFFDE7',
  'SEC': 'EFEBE9',
};

function getPartColor(id) {
  if (!id) return 'FFFFFF';
  if (id.startsWith('P-')) return partColors['P'];
  if (id.startsWith('D-')) return partColors['D'];
  if (id.startsWith('U-')) return partColors['U'];
  if (id.startsWith('A-')) return partColors['A'];
  if (id.startsWith('C-')) return partColors['C'];
  if (id.startsWith('BL-')) return partColors['BL'];
  if (id.startsWith('SEC-')) return partColors['SEC'];
  return 'FFFFFF';
}

const thinBorder = {
  top: { style: 'thin', color: { argb: colors.border } },
  bottom: { style: 'thin', color: { argb: colors.border } },
  left: { style: 'thin', color: { argb: colors.border } },
  right: { style: 'thin', color: { argb: colors.border } },
};

const ws = wb.addWorksheet('Testing SOP', {
  views: [{ state: 'frozen', ySplit: 5, xSplit: 0 }],
});

ws.columns = [
  { key: 'id', width: 10 },
  { key: 'module', width: 14 },
  { key: 'category', width: 16 },
  { key: 'feature', width: 26 },
  { key: 'scenario', width: 38 },
  { key: 'steps', width: 58 },
  { key: 'expected', width: 52 },
  { key: 'priority', width: 10 },
  { key: 'status', width: 10 },
  { key: 'automation', width: 16 },
  { key: 'notes', width: 20 },
];

function mergeTitleRow(rowNum, text, fontSize, height) {
  ws.mergeCells(rowNum, 1, rowNum, 11);
  const r = ws.getRow(rowNum);
  r.getCell(1).value = text;
  r.getCell(1).font = { bold: true, size: fontSize, color: { argb: colors.headerBg } };
  r.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };
  r.height = height;
}

mergeTitleRow(1, 'LuhaRide - Complete Testing SOP', 18, 36);
mergeTitleRow(2, 'Version 3.3 | Updated: 2026-06-23 | 346 Test Cases | Prepared by: LuhaRide QA Team', 11, 22);
ws.addRow([]);

const headerValues = ['Test ID', 'Module', 'Category', 'Feature', 'Test Scenario', 'Steps to Execute', 'Expected Result', 'Priority', 'Status', 'Automation', 'Tester Notes'];
const headerRow = ws.addRow(headerValues);
headerRow.height = 28;
headerRow.eachCell({ includeEmpty: true }, (cell) => {
  cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.headerBg } };
  cell.font = { bold: true, size: 11, color: { argb: colors.headerFont } };
  cell.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
  cell.border = thinBorder;
});

ws.addRow([]);

let totalTests = 0;

for (let i = 5; i < lines.length; i++) {
  const line = lines[i];
  if (!line.trim()) continue;

  const cells = parseCSVLine(line);
  const id = (cells[0] || '').trim();
  const col5 = (cells[4] || '').trim();
  const col4 = (cells[3] || '').trim();

  if (!id && col5.startsWith('PART ')) {
    ws.addRow([]);
    const r = ws.addRow([col5]);
    ws.mergeCells(r.number, 1, r.number, 11);
    r.height = 30;
    r.getCell(1).font = { bold: true, size: 14, color: { argb: colors.partFont } };
    r.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.partBg } };
    r.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };
    r.getCell(1).border = thinBorder;
    ws.addRow([]);
    continue;
  }

  if (!id && col4 && (/^[A-Z]\d+\./.test(col4) || col4.startsWith('EXTRA'))) {
    const r = ws.addRow([col4]);
    ws.mergeCells(r.number, 1, r.number, 11);
    r.height = 24;
    r.getCell(1).font = { bold: true, size: 11, color: { argb: colors.catFont } };
    r.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.catBg } };
    r.getCell(1).alignment = { vertical: 'middle' };
    r.getCell(1).border = thinBorder;
    continue;
  }

  if (!id && (col5.startsWith('END OF') || col5.startsWith('Total:') || col5.startsWith('Automated'))) {
    ws.addRow([]);
    const r = ws.addRow([col5]);
    ws.mergeCells(r.number, 1, r.number, 11);
    r.height = 22;
    r.getCell(1).font = { bold: true, size: 11, italic: true, color: { argb: '424242' } };
    r.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };
    continue;
  }

  if (/^[A-Z]+-\d+/.test(id)) {
    totalTests++;
    const bgColor = getPartColor(id);

    let automation = (cells[9] || '').trim();
    if (/[✅]/.test(automation) || automation.includes('CI')) {
      const match = automation.match(/\(([^)]+)\)/);
      automation = match ? 'Automated (' + match[1] + ')' : 'Automated';
    } else if (/[❌]/.test(automation) || automation.includes('Manual')) {
      const match = automation.match(/\(([^)]+)\)/);
      automation = match ? 'Manual (' + match[1] + ')' : 'Manual';
    }

    const steps = (cells[5] || '').replace(/\s+(\d+)\.\s/g, '\n$1. ').trim();

    const rowData = [
      id,
      cells[1] || '',
      cells[2] || '',
      cells[3] || '',
      cells[4] || '',
      steps,
      cells[6] || '',
      cells[7] || '',
      cells[8] || '',
      automation,
      cells[10] || '',
    ];

    const r = ws.addRow(rowData);
    r.height = 48;

    r.eachCell({ includeEmpty: true }, (cell, colNum) => {
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: bgColor } };
      cell.font = { size: 10, color: { argb: '212121' } };
      cell.alignment = { wrapText: true, vertical: 'middle' };
      cell.border = thinBorder;

      if (colNum === 1) cell.font = { bold: true, size: 10, color: { argb: '212121' } };

      if (colNum === 8) {
        const p = (cells[7] || '').trim();
        if (p === 'High') cell.font = { bold: true, size: 10, color: { argb: colors.high } };
        else if (p === 'Medium') cell.font = { bold: true, size: 10, color: { argb: colors.medium } };
        else cell.font = { bold: true, size: 10, color: { argb: colors.low } };
      }

      if (colNum === 10) {
        if (automation.startsWith('Automated')) cell.font = { bold: true, size: 9, color: { argb: colors.auto } };
        else cell.font = { size: 9, color: { argb: colors.manual } };
      }
    });
    continue;
  }
}

// Legend sheet
const ls = wb.addWorksheet('Legend', {});
ls.columns = [{ width: 30 }, { width: 50 }];

ls.addRow(['LuhaRide Testing SOP - Legend']);
ls.mergeCells(1, 1, 1, 2);
ls.getRow(1).getCell(1).font = { bold: true, size: 14 };
ls.getRow(1).height = 30;

ls.addRow([]);
ls.addRow(['COLOR CODE', 'MEANING']);
ls.getRow(3).eachCell(c => {
  c.font = { bold: true, size: 11, color: { argb: 'FFFFFF' } };
  c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.headerBg } };
  c.border = thinBorder;
});

const legendItems = [
  ['Green rows', 'Passenger test cases (Part A)', partColors['P']],
  ['Orange rows', 'Driver test cases (Part B)', partColors['D']],
  ['Blue rows', 'Union Admin test cases (Part C)', partColors['U']],
  ['Pink rows', 'Platform Admin test cases (Part D)', partColors['A']],
  ['Purple rows', 'Common/System test cases (Part E)', partColors['C']],
  ['Yellow rows', 'Business Logic test cases (Part F)', partColors['BL']],
  ['Brown rows', 'Security/Middleware test cases (Extra)', partColors['SEC']],
];

legendItems.forEach(([label, desc, bg]) => {
  const r = ls.addRow([label, desc]);
  r.eachCell(c => {
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: bg } };
    c.border = thinBorder;
    c.font = { size: 10 };
  });
  r.getCell(1).font = { bold: true, size: 10 };
});

ls.addRow([]);
ls.addRow(['PRIORITY', 'MEANING']);
ls.getRow(ls.rowCount).eachCell(c => {
  c.font = { bold: true, size: 11, color: { argb: 'FFFFFF' } };
  c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.headerBg } };
  c.border = thinBorder;
});

[
  ['High', 'Must test before release - blocking issues', colors.high],
  ['Medium', 'Should test - important but not blocking', colors.medium],
  ['Low', 'Nice to test - edge cases and polish', colors.low],
].forEach(([label, desc, fontColor]) => {
  const r = ls.addRow([label, desc]);
  r.getCell(1).font = { bold: true, size: 10, color: { argb: fontColor } };
  r.getCell(2).font = { size: 10 };
  r.eachCell(c => { c.border = thinBorder; });
});

ls.addRow([]);
ls.addRow(['AUTOMATION', 'MEANING']);
ls.getRow(ls.rowCount).eachCell(c => {
  c.font = { bold: true, size: 11, color: { argb: 'FFFFFF' } };
  c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.headerBg } };
  c.border = thinBorder;
});
const ar = ls.addRow(['Automated (file.test.js)', 'Covered by CI test suite - runs on every push']);
ar.getCell(1).font = { bold: true, size: 10, color: { argb: colors.auto } };
ar.getCell(2).font = { size: 10 };
ar.eachCell(c => { c.border = thinBorder; });
const mr = ls.addRow(['Manual (reason)', 'Requires human testing - UI/device/timing dependent']);
mr.getCell(1).font = { bold: true, size: 10, color: { argb: colors.manual } };
mr.getCell(2).font = { size: 10 };
mr.eachCell(c => { c.border = thinBorder; });

(async () => {
  await wb.xlsx.writeFile('LuhaRide_Testing_SOP.xlsx');
  console.log('Excel generated: LuhaRide_Testing_SOP.xlsx');
  console.log('Total test cases: ' + totalTests);
})();
